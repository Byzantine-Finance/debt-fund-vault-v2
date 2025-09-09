// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 [Byzantine Finance]
// The implementation of this contract was inspired by Morpho Vault V2, developed by the Morpho Association in 2025.
pragma solidity ^0.8.0;

import "./CompoundV3IntegrationTest.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract CompoundV3IntegrationSkimTest is CompoundV3IntegrationTest {
    address internal recipient = makeAddr("recipient");

    function testSkimCompoundV3(uint256 assets) public {
        assets = _boundAssets(assets);

        ERC20Mock token = new ERC20Mock(18);

        vm.prank(owner);
        compoundAdapter.setSkimRecipient(recipient);

        deal(address(token), address(compoundAdapter), assets);
        assertEq(token.balanceOf(address(compoundAdapter)), assets, "Adapter did not receive tokens");

        vm.expectEmit();
        emit ICompoundV3Adapter.Skim(address(token), assets);
        vm.prank(recipient);
        compoundAdapter.skim(address(token));

        // Verify successful skim
        assertEq(token.balanceOf(address(compoundAdapter)), 0, "Tokens not skimmed from adapter");
        assertEq(token.balanceOf(recipient), assets, "Recipient did not receive tokens");

        // Verify reverts
        vm.expectRevert(ICompoundV3Adapter.NotAuthorized.selector);
        compoundAdapter.skim(address(token));

        vm.expectRevert(ICompoundV3Adapter.NotAuthorized.selector);
        compoundAdapter.setSkimRecipient(recipient);

        vm.expectRevert(ICompoundV3Adapter.CannotSkimCompoundToken.selector);
        vm.prank(recipient);
        compoundAdapter.skim(address(comet));
    }

    function _boundAssets(uint256 assets) internal pure returns (uint256) {
        return bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
    }
}
