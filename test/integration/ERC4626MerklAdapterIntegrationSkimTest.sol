// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 [Byzantine Finance]
// The implementation of this contract was inspired by Morpho Vault V2, developed by the Morpho Association in 2025.
pragma solidity ^0.8.0;

import "./ERC4626MerklAdapterIntegrationTest.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract ERC4626MerklAdapterIntegrationSkimTest is ERC4626MerklAdapterIntegrationTest {
    address internal recipient = makeAddr("recipient");

    function testSkimERC4626Merkl(uint256 assets) public {
        assets = _boundAssets(assets);

        ERC20Mock token = new ERC20Mock(18);

        vm.expectEmit();
        emit IERC4626MerklAdapter.SetSkimRecipient(recipient);
        vm.prank(owner);
        erc4626MerklAdapter.setSkimRecipient(recipient);

        deal(address(token), address(erc4626MerklAdapter), assets);
        assertEq(token.balanceOf(address(erc4626MerklAdapter)), assets, "Adapter did not receive tokens");

        vm.expectEmit();
        emit IERC4626MerklAdapter.Skim(address(token), assets);
        vm.prank(recipient);
        erc4626MerklAdapter.skim(address(token));

        // Verify successful skim
        assertEq(token.balanceOf(address(erc4626MerklAdapter)), 0, "Tokens not skimmed from adapter");
        assertEq(token.balanceOf(recipient), assets, "Recipient did not receive tokens");

        // Verify reverts
        vm.expectRevert(IERC4626MerklAdapter.NotAuthorized.selector);
        erc4626MerklAdapter.skim(address(token));

        vm.expectRevert(IERC4626MerklAdapter.NotAuthorized.selector);
        erc4626MerklAdapter.setSkimRecipient(recipient);

        vm.expectRevert(IERC4626MerklAdapter.CannotSkimERC4626Shares.selector);
        vm.prank(recipient);
        erc4626MerklAdapter.skim(address(stataUSDC));
    }

    function _boundAssets(uint256 assets) internal pure returns (uint256) {
        return bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
    }
}
