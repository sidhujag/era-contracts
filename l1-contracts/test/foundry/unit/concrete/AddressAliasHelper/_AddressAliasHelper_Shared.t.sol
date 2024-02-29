// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {AddressAliasHelperTest} from "solpp/dev-contracts/test/AddressAliasHelperTest.sol";

contract AddressAliasHelperSharedTest is Test {
    AddressAliasHelperTest addressAliasHelper;

    function setUp() public {
        addressAliasHelper = new AddressAliasHelperTest();
    }
}
