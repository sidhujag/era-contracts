function SYSTEM_CONTRACTS_OFFSET() -> offset {
    offset := 0x8000
}

function ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT() -> addr {
    addr := 0x0000000000000000000000000000000000008002
}

function NONCE_HOLDER_SYSTEM_CONTRACT() -> addr {
    addr := 0x0000000000000000000000000000000000008003
}

function DEPLOYER_SYSTEM_CONTRACT() -> addr {
    addr :=  0x0000000000000000000000000000000000008006
}

function CODE_ADDRESS_CALL_ADDRESS() -> addr {
    addr := 0x000000000000000000000000000000000000FFFE
}

function CODE_ORACLE_SYSTEM_CONTRACT() -> addr {
    addr := 0x0000000000000000000000000000000000008012
}

function EVM_GAS_MANAGER_CONTRACT() -> addr {   
    addr :=  0x0000000000000000000000000000000000008013
}

function DEBUG_SLOT_OFFSET() -> offset {
    offset := mul(32, 32)
}

function LAST_RETURNDATA_SIZE_OFFSET() -> offset {
    offset := add(DEBUG_SLOT_OFFSET(), mul(5, 32))
}

function STACK_OFFSET() -> offset {
    offset := add(LAST_RETURNDATA_SIZE_OFFSET(), 32)
}

function BYTECODE_OFFSET() -> offset {
    offset := add(STACK_OFFSET(), mul(1024, 32))
}

function INF_PASS_GAS() -> inf {
    inf := 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
}

function MAX_POSSIBLE_BYTECODE() -> max {
    max := 32000
}

function MEM_OFFSET() -> offset {
    offset := add(BYTECODE_OFFSET(), MAX_POSSIBLE_BYTECODE())
}

function MEM_OFFSET_INNER() -> offset {
    offset := add(MEM_OFFSET(), 32)
}

function MAX_POSSIBLE_MEM() -> max {
    max := 0x100000 // 1MB
}

function MAX_MEMORY_FRAME() -> max {
    max := add(MEM_OFFSET_INNER(), MAX_POSSIBLE_MEM())
}

// It is the responsibility of the caller to ensure that ip >= BYTECODE_OFFSET + 32
function readIP(ip) -> opcode {
    // TODO: Why not do this at the beginning once instead of every time?
    let bytecodeLen := mload(BYTECODE_OFFSET())

    let maxAcceptablePos := add(add(BYTECODE_OFFSET(), bytecodeLen), 31)
    if gt(ip, maxAcceptablePos) {
        revert(0, 0)
    }

    opcode := and(mload(sub(ip, 31)), 0xff)
}

function readBytes(start, length) -> value {
    let max := add(start, length)
    for {} lt(start, max) { start := add(start, 1) } {
        let next_byte := readIP(start)

        value := or(shl(8, value), next_byte)
    }
}

function dupStackItem(sp, evmGas, position) -> newSp, evmGasLeft {
    evmGasLeft := chargeGas(evmGas, 3)
    let tempSp := sub(sp, mul(0x20, sub(position, 1)))

    if or(gt(tempSp, BYTECODE_OFFSET()), eq(tempSp, BYTECODE_OFFSET())) {
        revert(0, 0)
    }

    if lt(tempSp, STACK_OFFSET()) {
        revert(0, 0)
    }

    let dup := mload(tempSp)                    

    newSp := add(sp, 0x20)
    mstore(newSp, dup)
}

function swapStackItem(sp, evmGas, position) ->  evmGasLeft {
    evmGasLeft := chargeGas(evmGas, 3)
    let tempSp := sub(sp, mul(0x20, position))

    if or(gt(tempSp, BYTECODE_OFFSET()), eq(tempSp, BYTECODE_OFFSET())) {
        revert(0, 0)
    }

    if lt(tempSp, STACK_OFFSET()) {
        revert(0, 0)
    }


    let s2 := mload(sp)
    let s1 := mload(tempSp)                    

    mstore(sp, s1)
    mstore(tempSp, s2)
}

function popStackItem(sp) -> a, newSp {
    // We can not return any error here, because it would break compatibility
    if lt(sp, STACK_OFFSET()) {
        revert(0, 0)
    }

    a := mload(sp)
    newSp := sub(sp, 0x20)
}

function pushStackItem(sp, item) -> newSp {
    if or(gt(sp, BYTECODE_OFFSET()), eq(sp, BYTECODE_OFFSET())) {
        revert(0, 0)
    }

    newSp := add(sp, 0x20)
    mstore(newSp, item)
}

function getCodeAddress() -> addr {
    addr := verbatim_0i_1o("code_source")
}

function loadReturndataIntoActivePtr() {
    verbatim_0i_0o("return_data_ptr_to_active")
}

function loadCalldataIntoActivePtr() {
    verbatim_0i_0o("calldata_ptr_to_active")
}

function getActivePtrDataSize() -> size {
    size := verbatim_0i_1o("active_ptr_data_size")
}

function copyActivePtrData(_dest, _source, _size) {
    verbatim_3i_0o("active_ptr_data_copy", _dest, _source, _size)
}

function ptrAddIntoActive(_dest) {
    verbatim_1i_0o("active_ptr_add_assign", _dest)
}

function ptrShrinkIntoActive(_dest) {
    verbatim_1i_0o("active_ptr_shrink_assign", _dest)
}

function _getRawCodeHash(account) -> hash {
    // TODO: Unhardcode this selector
    mstore8(0, 0x4d)
    mstore8(1, 0xe2)
    mstore8(2, 0xe4)
    mstore8(3, 0x68)
    mstore(4, account)

    let success := staticcall(gas(), ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT(), 0, 36, 0, 32)

    if iszero(success) {
        // This error should never happen
        revert(0, 0)
    }

    hash := mload(0)
}

function _getCodeHash(account) -> hash {
    // function getCodeHash(uint256 _input) external view override returns (bytes32)
    // 0xe03fe177
    // TODO: Unhardcode this selector
    mstore8(0, 0xe0)
    mstore8(1, 0x3f)
    mstore8(2, 0xe1)
    mstore8(3, 0x77)
    mstore(4, account)

    let success := staticcall(gas(), ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT(), 0, 36, 0, 32)

    if iszero(success) {
        // This error should never happen
        revert(0, 0)
    }

    hash := mload(0)
}

// Basically performs an extcodecopy, while returning the length of the bytecode.
function _fetchDeployedCode(addr, _offset, _len) -> codeLen {
    let codeHash := _getRawCodeHash(addr)

    mstore(0, codeHash)

    let success := staticcall(gas(), CODE_ORACLE_SYSTEM_CONTRACT(), 0, 32, 0, 0)

    if iszero(success) {
        // This error should never happen
        revert(0, 0)
    }

    // The first word is the true length of the bytecode
    returndatacopy(0, 0, 32)
    codeLen := mload(0)

    if gt(_len, codeLen) {
        _len := codeLen
    }

    returndatacopy(_offset, 32, _len)
}

// Returns the length of the bytecode.
function _fetchDeployedCodeLen(addr) -> codeLen {
    let codeHash := _getRawCodeHash(addr)

    mstore(0, codeHash)

    let success := staticcall(gas(), CODE_ORACLE_SYSTEM_CONTRACT(), 0, 32, 0, 0)

    if iszero(success) {
        // This error should never happen
        revert(0, 0)
    }

    // The first word is the true length of the bytecode
    returndatacopy(0, 0, 32)
    codeLen := mload(0)
}

function getDeployedBytecode() {
    let codeLen := _fetchDeployedCode(
        getCodeAddress(),
        add(BYTECODE_OFFSET(), 32),
        MAX_POSSIBLE_BYTECODE()
    )

    mstore(BYTECODE_OFFSET(), codeLen)
}

function consumeEvmFrame() -> passGas, isStatic, callerEVM {
    // function consumeEvmFrame() external returns (uint256 passGas, bool isStatic)
    // TODO: Unhardcode selector
    mstore8(0, 0x04)
    mstore8(1, 0xc1)
    mstore8(2, 0x4e)
    mstore8(3, 0x9e)

    let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 4, 0, 64)

    if iszero(success) {
        // Should never happen
        revert(0, 0)
    }

    passGas := mload(0)
    isStatic := mload(32)

    if iszero(eq(passGas, INF_PASS_GAS())) {
        callerEVM := true
    }
}

function chargeGas(prevGas, toCharge) -> gasRemaining {
    if lt(prevGas, toCharge) {
        revert(0, 0)
    }

    gasRemaining := sub(prevGas, toCharge)
}

function checkMemOverflow(location) {
    if gt(location, MAX_MEMORY_FRAME()) {
        revert(0, 0)
    }
}

// Note, that this function can overflow. It's up to the caller to ensure that it does not.
function memCost(memSizeWords) -> gasCost {
    // The first term of the sum is the quadratic cost, the second one the linear one.
    gasCost := add(div(mul(memSizeWords, memSizeWords), 512), mul(3, memSizeWords))
}

// This function can overflow, it is the job of the caller to ensure that it does not.
// The argument to this function is the offset into the memory region IN BYTES.
function expandMemory(newSize) -> gasCost {
    let oldSizeInWords := mload(MEM_OFFSET())

    // The add 31 here before dividing is there to account for misaligned
    // memory expansions, where someone calls this with a newSize that is not
    // a multiple of 32. For instance, if someone calls it with an offset of 33,
    // the new size in words should be 2, not 1, but dividing by 32 will give 1.
    // Adding 31 solves it.
    let newSizeInWords := div(add(newSize, 31), 32)

    if gt(newSizeInWords, oldSizeInWords) {
        // TODO: Check this, it feels like there might be a more optimized way
        // of doing this cost calculation.
        let oldCost := memCost(oldSizeInWords)
        let newCost := memCost(newSizeInWords)

        gasCost := sub(newCost, oldCost)
        mstore(MEM_OFFSET(), newSizeInWords)
    }
}

// Essentially a NOP that will not get optimized away by the compiler
function $llvm_NoInline_llvm$_unoptimized() {
    pop(1)
}

function printHex(value) {
    mstore(add(DEBUG_SLOT_OFFSET(), 0x20), 0x00debdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebde)
    mstore(add(DEBUG_SLOT_OFFSET(), 0x40), value)
    mstore(DEBUG_SLOT_OFFSET(), 0x4A15830341869CAA1E99840C97043A1EA15D2444DA366EFFF5C43B4BEF299681)
    $llvm_NoInline_llvm$_unoptimized()
}

function printString(value) {
    mstore(add(DEBUG_SLOT_OFFSET(), 0x20), 0x00debdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdf)
    mstore(add(DEBUG_SLOT_OFFSET(), 0x40), value)
    mstore(DEBUG_SLOT_OFFSET(), 0x4A15830341869CAA1E99840C97043A1EA15D2444DA366EFFF5C43B4BEF299681)
    $llvm_NoInline_llvm$_unoptimized()
}

function isSlotWarm(key) -> isWarm {
    // TODO: Unhardcode this selector 0x482d2e74
    mstore8(0, 0x48)
    mstore8(1, 0x2d)
    mstore8(2, 0x2e)
    mstore8(3, 0x74)
    mstore(4, key)

    let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 36, 0, 32)

    if iszero(success) {
        // This error should never happen
        revert(0, 0)
    }

    isWarm := mload(0)
}

function warmSlot(key,currentValue) -> isWarm, originalValue {
    // TODO: Unhardcode this selector 0xbdf78160
    mstore8(0, 0xbd)
    mstore8(1, 0xf7)
    mstore8(2, 0x81)
    mstore8(3, 0x60)
    mstore(4, key)
    mstore(36,currentValue)

    let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 68, 0, 64)

    if iszero(success) {
        // This error should never happen
        revert(0, 0)
    }

    isWarm := mload(0)
    originalValue := mload(32)
}

function getNewAddress(addr) -> newAddr {
    let digest, nonce, addressEncoded, nonceEncoded, nonceEncodedLength, listLength, listLengthEconded

    nonce := getNonce(addr)

    addressEncoded := and(
        add(addr, shl(160, 0x94)),
        0xffffffffffffffffffffffffffffffffffffffffff
    )

    nonceEncoded := nonce
    nonceEncodedLength := 1
    if iszero(nonce) {
        nonceEncoded := 128
    }
    // The nonce has 4 bytes
    if gt(nonce, 0xFFFFFF) {
        nonceEncoded := shl(32, 0x84)
        nonceEncoded := add(nonceEncoded, nonce)
        nonceEncodedLength := 5
    }
    // The nonce has 3 bytes
    if and(gt(nonce, 0xFFFF), lt(nonce, 0x1000000)) {
        nonceEncoded := shl(24, 0x83)
        nonceEncoded := add(nonceEncoded, nonce)
        nonceEncodedLength := 4
    }
    // The nonce has 2 bytes
    if and(gt(nonce, 0xFF), lt(nonce, 0x10000)) {
        nonceEncoded := shl(16, 0x82)
        nonceEncoded := add(nonceEncoded, nonce)
        nonceEncodedLength := 3
    }
    // The nonce has 1 byte and it's in [0x80, 0xFF]
    if and(gt(nonce, 0x7F), lt(nonce, 0x100)) {
        nonceEncoded := shl(8, 0x81)
        nonceEncoded := add(nonceEncoded, nonce)
        nonceEncodedLength := 2
    }

    listLength := add(21, nonceEncodedLength)
    listLengthEconded := add(listLength, 0xC0)

    let arrayLength := add(168, mul(8, nonceEncodedLength))

    digest := add(
        shl(arrayLength, listLengthEconded),
        add(
            shl(
                mul(8, nonceEncodedLength),
                addressEncoded
            ),
            nonceEncoded
        )
    )

    mstore(0, shl(sub(248, arrayLength), digest))

    newAddr := and(
        keccak256(0, add(div(arrayLength, 8), 1)),
        0xffffffffffffffffffffffffffffffffffffffff
    )
}

function incrementNonce(addr) {
    mstore8(0, 0x30)
    mstore8(1, 0x63)
    mstore8(2, 0x95)
    mstore8(3, 0xc6)
    mstore(4, addr)

    let result := call(gas(), NONCE_HOLDER_SYSTEM_CONTRACT(), 0, 0, 36, 0, 0)

    if iszero(result) {
        revert(0, 0)
    }
}

function ensureAcceptableMemLocation(location) {
    if gt(location,MAX_POSSIBLE_MEM()) {
        revert(0,0) // Check if this is whats needed
    }
}

function addGasIfEvmRevert(isCallerEVM,offset,size,evmGasLeft) -> newOffset,newSize {
    newOffset := offset
    newSize := size
    if eq(isCallerEVM,1) {
        // include gas
        let previousValue := mload(sub(offset,32))
        mstore(sub(offset,32),evmGasLeft)
        //mstore(sub(offset,32),previousValue) // Im not sure why this is needed, it was like this in the solidity code,
        // but it appears to rewrite were we want to store the gas

        newOffset := sub(offset, 32)
        newSize := add(size, 32)
    }
}

function warmAddress(addr) -> isWarm {
    // TODO: Unhardcode this selector 0x8db2ba78
    mstore8(0, 0x8d)
    mstore8(1, 0xb2)
    mstore8(2, 0xba)
    mstore8(3, 0x78)
    mstore(4, addr)

    let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 36, 0, 32)

    if iszero(success) {
        // This error should never happen
        revert(0, 0)
    }

    isWarm := mload(0)
}

function getNonce(addr) -> nonce {
    mstore8(0, 0xfb)
    mstore8(1, 0x1a)
    mstore8(2, 0x9a)
    mstore8(3, 0x57)
    mstore(4, addr)

    let result := staticcall(gas(), NONCE_HOLDER_SYSTEM_CONTRACT(), 0, 36, 0, 32)

    if iszero(result) {
        revert(0, 0)
    }

    nonce := mload(0)
}

function _isEVM(_addr) -> isEVM {
    // bytes4 selector = ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT.isAccountEVM.selector;
    // function isAccountEVM(address _addr) external view returns (bool);
    let selector := 0x8c040477
    // IAccountCodeStorage constant ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT = IAccountCodeStorage(
    //      address(SYSTEM_CONTRACTS_OFFSET + 0x02)
    // );

    mstore8(0, 0x8c)
    mstore8(1, 0x04)
    mstore8(2, 0x04)
    mstore8(3, 0x77)
    mstore(4, _addr)

    let success := staticcall(gas(), ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT(), 0, 36, 0, 32)

    if iszero(success) {
        // This error should never happen
        revert(0, 0)
    }

    isEVM := mload(0)
}

function _pushEVMFrame(_passGas, _isStatic) {
    // function pushEVMFrame(uint256 _passGas, bool _isStatic) external
    let selector := 0xead77156

    mstore8(0, 0xea)
    mstore8(1, 0xd7)
    mstore8(2, 0x71)
    mstore8(3, 0x56)
    mstore(4, _passGas)
    mstore(36, _isStatic)

    let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 68, 0, 0)
    if iszero(success) {
        // This error should never happen
        revert(0, 0)
    }
}

function _popEVMFrame() {
    // function popEVMFrame() external
    // 0xe467d2f0
    let selector := 0xe467d2f0

    mstore8(0, 0xe4)
    mstore8(1, 0x67)
    mstore8(2, 0xd2)
    mstore8(3, 0xf0)

    let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 4, 0, 0)
    if iszero(success) {
        // This error should never happen
        revert(0, 0)
    }
}

// Each evm gas is 5 zkEVM one
// FIXME: change this variable to reflect real ergs : gas ratio
function GAS_DIVISOR() -> gas_div { gas_div := 5 }
function EVM_GAS_STIPEND() -> gas_stipend { gas_stipend := shl(30, 1) } // 1 << 30
function OVERHEAD() -> overhead { overhead := 2000 }

function GAS_CONSTANTS() -> divisor, stipend, overhead {
    divisor := GAS_DIVISOR()
    stipend := EVM_GAS_STIPEND()
    overhead := OVERHEAD()
}

function _calcEVMGas(_zkevmGas) -> calczkevmGas {
    calczkevmGas := div(_zkevmGas, GAS_DIVISOR())
}

function getEVMGas() -> evmGas {
    let _gas := gas()
    let requiredGas := add(EVM_GAS_STIPEND(), OVERHEAD())

    if or(gt(_gas, requiredGas), eq(requiredGas, _gas)) {
        evmGas := div(sub(_gas, requiredGas), GAS_DIVISOR())
    }
}

function _getZkEVMGas(_evmGas) -> zkevmGas {
    /*
        TODO: refine the formula, especially with regard to decommitment costs
    */
    zkevmGas := mul(_evmGas, GAS_DIVISOR())
}

function _saveReturndataAfterEVMCall(_outputOffset, _outputLen) -> _gasLeft{
    let lastRtSzOffset := LAST_RETURNDATA_SIZE_OFFSET()
    let rtsz := returndatasize()

    loadReturndataIntoActivePtr()

    // if (rtsz > 31)
    switch gt(rtsz, 31)
        case 0 {
            // Unexpected return data.
            _gasLeft := 0
            _eraseReturndataPointer()
        }
        default {
            returndatacopy(0, 0, 32)
            _gasLeft := mload(0)
            returndatacopy(_outputOffset, 32, _outputLen)
            mstore(lastRtSzOffset, sub(rtsz, 32))

            // Skip the returnData
            ptrAddIntoActive(32)
        }
}

function _eraseReturndataPointer() {
    let lastRtSzOffset := LAST_RETURNDATA_SIZE_OFFSET()

    let activePtrSize := getActivePtrDataSize()
    ptrShrinkIntoActive(and(activePtrSize, 0xFFFFFFFF))// uint32(activePtrSize)
    mstore(lastRtSzOffset, 0)
}

function _saveReturndataAfterZkEVMCall() {
    let lastRtSzOffset := LAST_RETURNDATA_SIZE_OFFSET()

    mstore(lastRtSzOffset, returndatasize())
}

function performCall(oldSp, evmGasLeft, isStatic) -> dynamicGas,sp {
    let gasSend,addr,value,argsOffset,argsSize,retOffset,retSize

    gasSend, sp := popStackItem(oldSp)
    addr, sp := popStackItem(sp)
    value, sp := popStackItem(sp)
    argsOffset, sp := popStackItem(sp)
    argsSize, sp := popStackItem(sp)
    retOffset, sp := popStackItem(sp)
    retSize, sp := popStackItem(sp)


    // code_execution_cost is the cost of the called code execution (limited by the gas parameter).
    // If address is warm, then address_access_cost is 100, otherwise it is 2600. See section access sets.
    // If value is not 0, then positive_value_cost is 9000. In this case there is also a call stipend that is given to make sure that a basic fallback function can be called. 2300 is thus removed from the cost, and also added to the gas input.
    // If value is not 0 and the address given points to an empty account, then value_to_empty_account_cost is 25000. An account is empty if its balance is 0, its nonce is 0 and it has no code.
    dynamicGas := expandMemory(add(retOffset,retSize))
    switch warmAddress(addr)
        case 0 { dynamicGas := add(dynamicGas,2600) }
        default { dynamicGas := add(dynamicGas,100) }

    if not(iszero(value)) {
        dynamicGas := add(dynamicGas,6700)
        gasSend := add(gasSend,2300)

        if isAddrEmpty(addr) {
            dynamicGas := add(dynamicGas,25000)
        }
    }

    if gt(gasSend,div(mul(evmGasLeft,63),64)) {
        gasSend := div(mul(evmGasLeft,63),64)
    }
    argsOffset := add(argsOffset,MEM_OFFSET_INNER())
    retOffset := add(retOffset,MEM_OFFSET_INNER())
    // TODO: More Checks are needed
    // Check gas
    let success

    if isStatic {
        if not(iszero(value)) {
            revert(0, 0)
        }
        success, evmGasLeft := _performStaticCall(
            _isEVM(addr),
            gasSend,
            addr,
            argsOffset,
            argsSize,
            retOffset,
            retSize
        )
    }

    if _isEVM(addr) {
        _pushEVMFrame(gasSend, isStatic)
        success := call(gasSend, addr, value, argsOffset, argsSize, 0, 0)
        evmGasLeft := _saveReturndataAfterEVMCall(retOffset, retSize)
        _popEVMFrame()
    }

    // zkEVM native
    if and(iszero(_isEVM(addr)), iszero(isStatic)) {
        gasSend := _getZkEVMGas(gasSend)
        let zkevmGasBefore := gas()
        success := call(gasSend, addr, value, argsOffset, argsSize, retOffset, retSize)
        _saveReturndataAfterZkEVMCall()
        let gasUsed := _calcEVMGas(sub(zkevmGasBefore, gas()))

        evmGasLeft := 0
        if gt(gasSend, gasUsed) {
            evmGasLeft := sub(gasSend, gasUsed)
        }
    }

    sp := pushStackItem(sp,success)

    // TODO: dynamicGas := add(dynamicGas,codeExecutionCost) how to do this?
    // Check if the following is ok
    dynamicGas := add(dynamicGas,gasSend)
}

function _performStaticCall(
    _calleeIsEVM,
    _calleeGas,
    _callee,
    _inputOffset,
    _inputLen,
    _outputOffset,
    _outputLen
) ->  success, _gasLeft {
    if _calleeIsEVM {
        _pushEVMFrame(_calleeGas, true)
        // TODO Check the following comment from zkSync .sol.
        // We can not just pass all gas here to prevert overflow of zkEVM gas counter
        success := staticcall(_calleeGas, _callee, _inputOffset, _inputLen, 0, 0)

        _gasLeft := _saveReturndataAfterEVMCall(_outputOffset, _outputLen)
        _popEVMFrame()
    }

    // zkEVM native
    if iszero(_calleeIsEVM) {
        _calleeGas := _getZkEVMGas(_calleeGas)
        let zkevmGasBefore := gas()
        success := staticcall(_calleeGas, _callee, _inputOffset, _inputLen, _outputOffset, _outputLen)

        _saveReturndataAfterZkEVMCall()

        let gasUsed := _calcEVMGas(sub(zkevmGasBefore, gas()))

        _gasLeft := 0
        if gt(_calleeGas, gasUsed) {
            _gasLeft := sub(_calleeGas, gasUsed)
        }
    }
}

function isAddrEmpty(addr) -> isEmpty {
    isEmpty := 0
    if  and( and( 
            iszero(balance(addr)), 
            iszero(extcodesize(addr)) ),
            iszero(getNonce(addr))
        ) {
        isEmpty := 1
    }
}

function genericCreate(addr, offset, size, sp) -> result {
    pop(warmAddress(addr))

    _eraseReturndataPointer()

    let nonceNewAddr := getNonce(addr)
    let bytecodeNewAddr := extcodesize(addr)
    if or(gt(nonceNewAddr, 0), gt(bytecodeNewAddr, 0)) {
        incrementNonce(address())
        revert(0, 0)
    }

    offset := add(MEM_OFFSET_INNER(), offset)

    sp := pushStackItem(sp, mload(sub(offset, 0x80)))
    sp := pushStackItem(sp, mload(sub(offset, 0x60)))
    sp := pushStackItem(sp, mload(sub(offset, 0x40)))
    sp := pushStackItem(sp, mload(sub(offset, 0x20)))

    // Selector
    mstore(sub(offset, 0x80), 0x5b16a23c)
    // Arg1: address
    mstore(sub(offset, 0x60), addr)
    // Arg2: init code
    // Where the arg starts (third word)
    mstore(sub(offset, 0x40), 0x40)
    // Length of the init code
    mstore(sub(offset, 0x20), size)

    _pushEVMFrame(gas(), false)

    result := call(gas(), DEPLOYER_SYSTEM_CONTRACT(), 0, sub(offset, 0x64), add(size, 0x64), 0, 0)

    _popEVMFrame()

    incrementNonce(address())

    let back

    back, sp := popStackItem(sp)
    mstore(sub(offset, 0x20), back)
    back, sp := popStackItem(sp)
    mstore(sub(offset, 0x40), back)
    back, sp := popStackItem(sp)
    mstore(sub(offset, 0x60), back)
    back, sp := popStackItem(sp)
    mstore(sub(offset, 0x80), back)
}
