// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 [Byzantine Finance]
// The implementation of this contract was inspired by Morpho Vault V2, developed by the Morpho Association in 2025.
pragma solidity ^0.8.0;

import "./ERC4626MerklAdapterIntegrationTest.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract ERC4626MerklAdapterIntegrationRevertTest is ERC4626MerklAdapterIntegrationTest {
    function testAllocateNotAuthorizedReverts(uint256 assets) public {
        assets = bound(assets, 0, MAX_TEST_ASSETS);
        vm.expectRevert(IERC4626MerklAdapter.NotAuthorized.selector);
        erc4626MerklAdapter.allocate(hex"", assets, bytes4(0), address(0));
    }

    function testDeallocateNotAuthorizedReverts(uint256 assets) public {
        assets = bound(assets, 0, MAX_TEST_ASSETS);
        vm.expectRevert(IERC4626MerklAdapter.NotAuthorized.selector);
        erc4626MerklAdapter.deallocate(hex"", assets, bytes4(0), address(0));
    }

    function testInvalidData(bytes memory data) public {
        vm.assume(data.length > 0);

        vm.expectRevert(IERC4626MerklAdapter.InvalidData.selector);
        erc4626MerklAdapter.allocate(data, 0, bytes4(0), address(0));

        vm.expectRevert(IERC4626MerklAdapter.InvalidData.selector);
        erc4626MerklAdapter.deallocate(data, 0, bytes4(0), address(0));
    }

    function testCreateERC4626MerklAdapterAssetMismatchReverts() public {
        // create a new vault with a non USDC asset
        ERC20Mock newToken = new ERC20Mock(18);
        IVaultV2 newTokenVault = IVaultV2(vaultFactory.createVaultV2(owner, address(newToken), bytes32(0)));

        vm.expectRevert(IERC4626MerklAdapter.AssetMismatch.selector);
        IERC4626MerklAdapter(
            erc4626MerklAdapterFactory.createERC4626MerklAdapter(address(newTokenVault), address(stataUSDC))
        );
    }
}
