// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Diamond} from "../../state-transition/libraries/Diamond.sol";
import {ZkSyncHyperchainBase} from "../../state-transition/chain-deps/facets/ZkSyncHyperchainBase.sol";
import {IL1AssetRouter} from "../../bridge/interfaces/IL1AssetRouter.sol";

/// selectors do not overlap with normal facet selectors (getName does not count)
contract DummyAdminFacetNoOverlap is ZkSyncHyperchainBase {
    // add this to be excluded from coverage report
    function test() internal virtual {}

    function getName() external pure returns (string memory) {
        return "DummyAdminFacetNoOverlap";
    }

    function executeUpgradeNoOverlap(Diamond.DiamondCutData calldata _diamondCut) external {
        Diamond.diamondCut(_diamondCut);
        s.baseTokenAssetId = IL1AssetRouter(s.baseTokenBridge).nativeTokenVault().getAssetId(s.baseToken);
    }

    function receiveEther() external payable {}
}
