// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;


/// BitcoinDA validator. It will publish inclusion data that would allow to verify the inclusion.
contract BitcoinL2DAValidator {
    function validatePubdata(
        // The rolling hash of the user L2->L1 logs.
        bytes32,
        // The root hash of the user L2->L1 logs.
        bytes32,
        // The chained hash of the L2->L1 messages
        bytes32 _chainedMessagesHash,
        // The chained hash of uncompressed bytecodes sent to L1
        bytes32 _chainedBytecodesHash,
        // Operator data, that is related to the DA itself
        bytes calldata _totalL2ToL1PubdataAndStateDiffs
    ) external  {
        
     return;
    }
}
