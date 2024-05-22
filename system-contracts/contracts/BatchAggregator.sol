// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IBatchAggregator} from "./interfaces/IBatchAggregator.sol";
import {ISystemContract} from "./interfaces/ISystemContract.sol";
import {L2_L1_LOGS_TREE_DEFAULT_LEAF_HASH, L2_TO_L1_LOG_SERIALIZE_SIZE, STATE_DIFF_COMPRESSION_VERSION_NUMBER} from "./interfaces/IL1Messenger.sol";
import {SystemLogKey, SYSTEM_CONTEXT_CONTRACT, KNOWN_CODE_STORAGE_CONTRACT, COMPRESSOR_CONTRACT, BATCH_AGGREGATOR, STATE_DIFF_ENTRY_SIZE, L2_TO_L1_LOGS_MERKLE_TREE_LEAVES, PUBDATA_CHUNK_PUBLISHER, COMPUTATIONAL_PRICE_FOR_PUBDATA} from "./Constants.sol";
import {UnsafeBytesCalldata} from "./libraries/UnsafeBytesCalldata.sol";
import {ICompressor, OPERATION_BITMASK, LENGTH_BITS_OFFSET, MAX_ENUMERATION_INDEX_SIZE} from "./interfaces/ICompressor.sol";
contract BatchAggregator is IBatchAggregator, ISystemContract {
    using UnsafeBytesCalldata for bytes;
    bytes[] batchStorage;
    bytes[] chainData;
    // log data
    mapping(uint256 => bytes[]) messageStorage;
    mapping(uint256 => bytes[]) logStorage;
    mapping(uint256 => bytes[]) bytecodeStorage;
    // state diff data
    mapping(uint256 => mapping(bytes32 => bytes)) uncompressedWrites;
    mapping(uint256 => mapping(bytes32 => bool)) slotStatus;
    mapping(uint256 => bytes32[]) accesedSlots;
    // chain data
    mapping(uint256 => bool) chainSet;
    uint256[] chainList;
    function addChain(uint256 chainId) internal {
        if (chainSet[chainId] == false) {
            chainList.push(chainId);
            chainSet[chainId] = true;
        }
    }
    // TODO: import or delete
    function _sliceToUint256(bytes calldata _calldataSlice) internal pure returns (uint256 number) {
        number = uint256(bytes32(_calldataSlice));
        number >>= (256 - (_calldataSlice.length * 8));
    }
    function _verifyValueCompression(
        uint256 _initialValue,
        uint256 _finalValue,
        uint256 _operation,
        bytes calldata _compressedValue
    ) internal pure {
        uint256 convertedValue = _sliceToUint256(_compressedValue);

        unchecked {
            if (_operation == 0 || _operation == 3) {
                require(convertedValue == _finalValue, "transform or no compression: compressed and final mismatch");
            } else if (_operation == 1) {
                require(
                    _initialValue + convertedValue == _finalValue,
                    "add: initial plus converted not equal to final"
                );
            } else if (_operation == 2) {
                require(
                    _initialValue - convertedValue == _finalValue,
                    "sub: initial minus converted not equal to final"
                );
            } else {
                revert("unsupported operation");
            }
        }
    }
    

    function addInitialWrite(uint256 chainId, bytes calldata stateDiff) internal{
        bytes32 derivedKey = stateDiff.readBytes32(52);
        uncompressedWrites[chainId][derivedKey] = stateDiff;
        slotStatus[chainId][derivedKey] = true;
        accesedSlots[chainId].push(derivedKey);
    }
    function addRepeatedWrite(uint256 chainId, bytes calldata stateDiff) internal{
        bytes32 derivedKey = stateDiff.readBytes32(52);
        if (slotStatus[chainId][derivedKey]==false){
            uncompressedWrites[chainId][derivedKey] = stateDiff;
            slotStatus[chainId][derivedKey] = true;
            accesedSlots[chainId].push(derivedKey);
        }
        else{
            bytes memory slotData = uncompressedWrites[chainId][derivedKey];
            uint64 enumIndex;
            bytes32 finalValue;
            assembly{
                let offset := slotData
                enumIndex := mload(add(sub(offset,24),84))
                finalValue := mload(add(offset,124))
            }
            assembly {
                let start := add(slotData, 0x20)
                mstore(add(start,84), enumIndex)
                mstore(add(start,124),finalValue)
            }
        }
    }
    function repackStateDiffs(uint256 chainId,
        uint256 _numberOfStateDiffs,
        uint256 _enumerationIndexSize,
        bytes calldata _stateDiffs,
        bytes calldata _compressedStateDiffs
    ) internal{
        // We do not enforce the operator to use the optimal, i.e. the minimally possible _enumerationIndexSize.
        // We do enforce however, that the _enumerationIndexSize is not larger than 8 bytes long, which is the
        // maximal ever possible size for enumeration index.
        require(_enumerationIndexSize <= MAX_ENUMERATION_INDEX_SIZE, "enumeration index size is too large");

        uint256 numberOfInitialWrites = uint256(_compressedStateDiffs.readUint16(0));

        uint256 stateDiffPtr = 2;
        uint256 numInitialWritesProcessed = 0;

        // Process initial writes
        for (uint256 i = 0; i < _numberOfStateDiffs * STATE_DIFF_ENTRY_SIZE; i += STATE_DIFF_ENTRY_SIZE) {
            bytes calldata stateDiff = _stateDiffs[i:i + STATE_DIFF_ENTRY_SIZE];
            uint64 enumIndex = stateDiff.readUint64(84);
            if (enumIndex != 0) {
                // It is a repeated write, so we skip it.
                continue;
            }
            addInitialWrite(chainId, stateDiff);

            numInitialWritesProcessed++;

            bytes32 derivedKey = stateDiff.readBytes32(52);
            uint256 initValue = stateDiff.readUint256(92);
            uint256 finalValue = stateDiff.readUint256(124);
            require(derivedKey == _compressedStateDiffs.readBytes32(stateDiffPtr), "iw: initial key mismatch");
            stateDiffPtr += 32;

            uint8 metadata = uint8(bytes1(_compressedStateDiffs[stateDiffPtr]));
            stateDiffPtr++;
            uint8 operation = metadata & OPERATION_BITMASK;
            uint8 len = operation == 0 ? 32 : metadata >> LENGTH_BITS_OFFSET;
            _verifyValueCompression(
                initValue,
                finalValue,
                operation,
                _compressedStateDiffs[stateDiffPtr:stateDiffPtr + len]
            );
            stateDiffPtr += len;
        }

        require(numInitialWritesProcessed == numberOfInitialWrites, "Incorrect number of initial storage diffs");

        // Process repeated writes
        for (uint256 i = 0; i < _numberOfStateDiffs * STATE_DIFF_ENTRY_SIZE; i += STATE_DIFF_ENTRY_SIZE) {
            bytes calldata stateDiff = _stateDiffs[i:i + STATE_DIFF_ENTRY_SIZE];
            uint64 enumIndex = stateDiff.readUint64(84);
            if (enumIndex == 0) {
                continue;
            }
            addRepeatedWrite(chainId, stateDiff);
            uint256 initValue = stateDiff.readUint256(92);
            uint256 finalValue = stateDiff.readUint256(124);
            uint256 compressedEnumIndex = _sliceToUint256(
                _compressedStateDiffs[stateDiffPtr:stateDiffPtr + _enumerationIndexSize]
            );
            require(enumIndex == compressedEnumIndex, "rw: enum key mismatch");
            stateDiffPtr += _enumerationIndexSize;

            uint8 metadata = uint8(bytes1(_compressedStateDiffs[stateDiffPtr]));
            stateDiffPtr += 1;
            uint8 operation = metadata & OPERATION_BITMASK;
            uint8 len = operation == 0 ? 32 : metadata >> LENGTH_BITS_OFFSET;
            _verifyValueCompression(
                initValue,
                finalValue,
                operation,
                _compressedStateDiffs[stateDiffPtr:stateDiffPtr + len]
            );
            stateDiffPtr += len;
        }

        require(stateDiffPtr == _compressedStateDiffs.length, "Extra data in _compressedStateDiffs");

    }
    function commitBatch(
        bytes calldata _totalL2ToL1PubdataAndStateDiffs,
        uint256 chainId,
        uint256 batchNumber
    ) external {
        addChain(chainId);

        uint256 calldataPtr = 0;

        /// Check logs
        uint32 numberOfL2ToL1Logs = uint32(bytes4(_totalL2ToL1PubdataAndStateDiffs[calldataPtr:calldataPtr + 4]));
        require(numberOfL2ToL1Logs <= L2_TO_L1_LOGS_MERKLE_TREE_LEAVES, "Too many L2->L1 logs");
        logStorage[chainId].push(
            _totalL2ToL1PubdataAndStateDiffs[calldataPtr:calldataPtr +
                4 +
                numberOfL2ToL1Logs *
                L2_TO_L1_LOG_SERIALIZE_SIZE]
        );
        calldataPtr += 4 + L2_TO_L1_LOG_SERIALIZE_SIZE * numberOfL2ToL1Logs;

        /// Check messages
        uint32 numberOfMessages = uint32(bytes4(_totalL2ToL1PubdataAndStateDiffs[calldataPtr:calldataPtr + 4]));
        messageStorage[chainId].push(
            _totalL2ToL1PubdataAndStateDiffs[calldataPtr:calldataPtr + 4 + numberOfMessages * 4]
        );
        calldataPtr += 4 + numberOfMessages * 4;

        /// Check bytecodes
        uint32 numberOfBytecodes = uint32(bytes4(_totalL2ToL1PubdataAndStateDiffs[calldataPtr:calldataPtr + 4]));
        uint256 bytecodeSliceStart = calldataPtr;
        calldataPtr += 4;
        bytes32 reconstructedChainedL1BytecodesRevealDataHash;
        for (uint256 i = 0; i < numberOfBytecodes; ++i) {
            uint32 currentBytecodeLength = uint32(
                bytes4(_totalL2ToL1PubdataAndStateDiffs[calldataPtr:calldataPtr + 4])
            );
            calldataPtr += 4 + currentBytecodeLength;
        }

        bytecodeStorage[chainId].push(_totalL2ToL1PubdataAndStateDiffs[bytecodeSliceStart:calldataPtr]);
        /// Check State Diffs
        /// encoding is as follows:
        /// header (1 byte version, 3 bytes total len of compressed, 1 byte enumeration index size)
        /// body (`compressedStateDiffSize` bytes, 4 bytes number of state diffs, `numberOfStateDiffs` * `STATE_DIFF_ENTRY_SIZE` bytes for the uncompressed state diffs)
        /// encoded state diffs: [20bytes address][32bytes key][32bytes derived key][8bytes enum index][32bytes initial value][32bytes final value]
        require(
            uint256(uint8(bytes1(_totalL2ToL1PubdataAndStateDiffs[calldataPtr]))) ==
                STATE_DIFF_COMPRESSION_VERSION_NUMBER,
            "state diff compression version mismatch"
        );
        uint256 stateDiffSliceStart = calldataPtr;
        calldataPtr++;

        uint24 compressedStateDiffSize = uint24(bytes3(_totalL2ToL1PubdataAndStateDiffs[calldataPtr:calldataPtr + 3]));
        calldataPtr += 3;

        uint8 enumerationIndexSize = uint8(bytes1(_totalL2ToL1PubdataAndStateDiffs[calldataPtr]));
        calldataPtr++;

        bytes calldata compressedStateDiffs = _totalL2ToL1PubdataAndStateDiffs[calldataPtr:calldataPtr +
            compressedStateDiffSize];
        calldataPtr += compressedStateDiffSize;

        bytes calldata totalL2ToL1Pubdata = _totalL2ToL1PubdataAndStateDiffs[:calldataPtr];

        uint32 numberOfStateDiffs = uint32(bytes4(_totalL2ToL1PubdataAndStateDiffs[calldataPtr:calldataPtr + 4]));
        calldataPtr += 4;

        bytes calldata stateDiffs = _totalL2ToL1PubdataAndStateDiffs[calldataPtr:calldataPtr +
            (numberOfStateDiffs * STATE_DIFF_ENTRY_SIZE)];

        calldataPtr += numberOfStateDiffs * STATE_DIFF_ENTRY_SIZE;

        repackStateDiffs(chainId, numberOfStateDiffs, enumerationIndexSize, stateDiffs, compressedStateDiffs);

        

    }
    function returnBatchesAndClearState() external returns (bytes memory batchInfo) {
        for (uint256 i = 0; i < chainList.length; i += 1) {
            uint256 chainId = chainList[i];

            chainData.push(
                abi.encode(
                    chainId,
                    logStorage[chainId],
                    messageStorage[chainId],
                    bytecodeStorage[chainId]
                )
            );

            delete chainSet[chainId];
            delete logStorage[chainId];
            delete messageStorage[chainId];
            delete bytecodeStorage[chainId];
        }
        delete chainList;
        batchInfo = abi.encode(chainData);
        delete chainData;
    }
}
