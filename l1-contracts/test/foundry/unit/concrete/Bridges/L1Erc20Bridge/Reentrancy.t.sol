// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {StdStorage, stdStorage} from "forge-std/Test.sol";
import {L1Erc20BridgeTest} from "./_L1Erc20Bridge_Shared.t.sol";
import {ReenterL1ERC20Bridge} from "solpp/dev-contracts/test/ReenterL1ERC20Bridge.sol";

contract ReentrancyTest is L1Erc20BridgeTest {
    using stdStorage for StdStorage;

    function _depositExpectRevertOnReentrancy() internal {
        uint256 amount = 8;
        vm.prank(alice);
        token.approve(address(bridgeReenterItself), amount);

        vm.prank(alice);
        vm.expectRevert(bytes("r1"));
        bridgeReenterItself.deposit(randomSigner, address(token), amount, 0, 0, address(0));
    }

    function _legacyDepositExpectRevertOnReentrancy() internal {
        uint256 amount = 8;
        vm.prank(alice);
        token.approve(address(bridgeReenterItself), amount);

        vm.prank(alice);
        vm.expectRevert(bytes("r1"));
        bridgeReenterItself.deposit(randomSigner, address(token), amount, 0, 0);
    }

    function _claimFailedDepositExpectRevertOnReentrancy() internal {
        uint256 amount = 16;
        stdstore
            .target(address(bridgeReenterItself))
            .sig("depositAmount(address,address,bytes32)")
            .with_key(alice)
            .with_key(address(token))
            .with_key(dummyL2DepositTxHash)
            .checked_write(amount);

        vm.prank(alice);
        bytes32[] memory merkleProof;
        vm.expectRevert(bytes("r1"));
        bridgeReenterItself.claimFailedDeposit(alice, address(token), dummyL2DepositTxHash, 0, 0, 0, merkleProof);
    }

    function _finalizeWithdrawalExpectRevertOnReentrancy() internal {
        uint256 l2BatchNumber = 3;
        uint256 l2MessageIndex = 4;

        vm.prank(alice);
        vm.expectRevert(bytes("r1"));
        bytes32[] memory merkleProof;
        bridgeReenterItself.finalizeWithdrawal(l2BatchNumber, l2MessageIndex, 0, "", merkleProof);
    }

    function test_depositReenterDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.Deposit);
        _depositExpectRevertOnReentrancy();
    }

    function test_depositReenterLegacyDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.LegacyDeposit);
        _depositExpectRevertOnReentrancy();
    }

    function test_depositReenterFinalizeWithdrawal() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.FinalizeWithdrawal);
        _depositExpectRevertOnReentrancy();
    }

    function test_depositReenterClaimFailedDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.ClaimFailedDeposit);
        _depositExpectRevertOnReentrancy();
    }

    function test_legacyDepositReenterDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.Deposit);
        _legacyDepositExpectRevertOnReentrancy();
    }

    function test_legacyDepositReenterLegacyDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.LegacyDeposit);
        _legacyDepositExpectRevertOnReentrancy();
    }

    function test_legacyDepositReenterFinalizeWithdrawal() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.FinalizeWithdrawal);
        _legacyDepositExpectRevertOnReentrancy();
    }

    function test_legacyDepositReenterClaimFailedDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.ClaimFailedDeposit);
        _legacyDepositExpectRevertOnReentrancy();
    }

    function test_claimFailedDepositReenterDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.Deposit);
        _claimFailedDepositExpectRevertOnReentrancy();
    }

    function test_claimFailedDepositReenterLegacyDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.LegacyDeposit);
        _claimFailedDepositExpectRevertOnReentrancy();
    }

    function test_claimFailedDepositReenterFinalizeWithdrawal() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.FinalizeWithdrawal);
        _claimFailedDepositExpectRevertOnReentrancy();
    }

    function test_claimFailedDepositReenterClaimFailedDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.ClaimFailedDeposit);
        _claimFailedDepositExpectRevertOnReentrancy();
    }

    function test_finalizeWithdrawalReenterDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.Deposit);
        _finalizeWithdrawalExpectRevertOnReentrancy();
    }

    function test_finalizeWithdrawalReenterLegacyDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.LegacyDeposit);
        _finalizeWithdrawalExpectRevertOnReentrancy();
    }

    function test_finalizeWithdrawalReenterFinalizeWithdrawal() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.FinalizeWithdrawal);
        _finalizeWithdrawalExpectRevertOnReentrancy();
    }

    function test_finalizeWithdrawalReenterClaimFailedDeposit() public {
        reenterL1ERC20Bridge.setFunctionToCall(ReenterL1ERC20Bridge.FunctionToCall.ClaimFailedDeposit);
        _finalizeWithdrawalExpectRevertOnReentrancy();
    }
}
