// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 [Byzantine Finance]
// The implementation of this contract was inspired by Morpho Vault V2, developed by the Morpho Association in 2025.
pragma solidity ^0.8.0;

import "./CompoundV3IntegrationTest.sol";
import {ICompoundV3Adapter} from "../../src/adapters/interfaces/ICompoundV3Adapter.sol";

contract CompoundV3IntegrationAllocationTest is CompoundV3IntegrationTest {
    function testAllocateNotAuthorizedReverts(uint256 assets) public {
        assets = bound(assets, 0, MAX_TEST_ASSETS);
        vm.expectRevert(ICompoundV3Adapter.NotAuthorized.selector);
        compoundAdapter.allocate(hex"", assets, bytes4(0), address(0));
    }

    function testDeallocateNotAuthorizedReverts(uint256 assets) public {
        assets = bound(assets, 0, MAX_TEST_ASSETS);
        vm.expectRevert(ICompoundV3Adapter.NotAuthorized.selector);
        compoundAdapter.deallocate(hex"", assets, bytes4(0), address(0));
    }

    function testInvalidData(bytes memory data) public {
        vm.assume(data.length > 0);

        vm.expectRevert(ICompoundV3Adapter.InvalidData.selector);
        compoundAdapter.allocate(data, 0, bytes4(0), address(0));

        vm.expectRevert(ICompoundV3Adapter.InvalidData.selector);
        compoundAdapter.deallocate(data, 0, bytes4(0), address(0));
    }
}
