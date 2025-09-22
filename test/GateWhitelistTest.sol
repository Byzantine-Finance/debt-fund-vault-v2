// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity ^0.8.0;

import "./BaseTest.sol";
import "../src/gate/GateWhitelist.sol";

contract Bundler3Mock {
    address private _initiator;

    constructor(address initiator_) {
        _initiator = initiator_;
    }

    function initiator() external view returns (address) {
        return _initiator;
    }
}

contract BundlerAdapterMock {
    IBundler3 private _bundler3;

    constructor(IBundler3 bundler3_) {
        _bundler3 = bundler3_;
    }

    function BUNDLER3() external view returns (IBundler3) {
        return _bundler3;
    }
}

contract GateWhitelistTest is BaseTest {
    GateWhitelist gate;
    address immutable gateOwner = makeAddr("gateOwner");

    function setUp() public override {
        super.setUp();
        gate = new GateWhitelist(gateOwner);
    }

    function testConstructor() public view {
        assertEq(gate.owner(), gateOwner);
    }

    function testOwnerOperations(address newOwner, address nonOwner) public {
        vm.assume(newOwner != address(0));
        vm.assume(nonOwner != address(0) && nonOwner != gateOwner);

        // Non-owner cannot set owner
        vm.prank(nonOwner);
        vm.expectRevert(GateWhitelist.Unauthorized.selector);
        gate.setOwner(newOwner);

        // Owner can set owner
        vm.prank(gateOwner);
        vm.expectEmit();
        emit GateWhitelist.SetOwner(gateOwner, newOwner);
        gate.setOwner(newOwner);
        assertEq(gate.owner(), newOwner);
    }

    function testWhitelistOperations(address account, bool isWhitelisted, address nonOwner) public {
        vm.assume(account != address(0));
        vm.assume(nonOwner != address(0) && nonOwner != gateOwner);

        // Non-owner cannot whitelist
        vm.prank(nonOwner);
        vm.expectRevert(GateWhitelist.Unauthorized.selector);
        gate.setIsWhitelisted(account, isWhitelisted);

        // Owner can whitelist
        vm.prank(gateOwner);
        vm.expectEmit();
        emit GateWhitelist.SetIsWhitelisted(account, isWhitelisted);
        gate.setIsWhitelisted(account, isWhitelisted);
        assertEq(gate.whitelisted(account), isWhitelisted);

        // Check that permission functions match whitelist status
        assertEq(gate.canSendShares(account), isWhitelisted);
        assertEq(gate.canReceiveAssets(account), isWhitelisted);
        assertEq(gate.canReceiveShares(account), isWhitelisted);
        assertEq(gate.canSendAssets(account), isWhitelisted);
    }

    function testSetIsWhitelistedBatch(bool[] memory isWhitelistedArray, address nonOwner) public {
        vm.assume(isWhitelistedArray.length > 0 && isWhitelistedArray.length <= 10);
        vm.assume(nonOwner != address(0) && nonOwner != gateOwner);
        address[] memory accounts = new address[](isWhitelistedArray.length);
        for (uint256 i; i < accounts.length; ++i) {
            accounts[i] = makeAddr(string(abi.encodePacked("account", vm.toString(i))));
        }

        // Non-owner cannot whitelist batch
        vm.prank(nonOwner);
        vm.expectRevert(GateWhitelist.Unauthorized.selector);
        gate.setIsWhitelistedBatch(accounts, isWhitelistedArray);

        // Owner can whitelist batch
        vm.prank(gateOwner);
        for (uint256 i; i < accounts.length; ++i) {
            vm.expectEmit();
            emit GateWhitelist.SetIsWhitelisted(accounts[i], isWhitelistedArray[i]);
        }
        gate.setIsWhitelistedBatch(accounts, isWhitelistedArray);

        // Verify that all accounts have been correctly updated
        for (uint256 i; i < accounts.length; ++i) {
            assertEq(gate.whitelisted(accounts[i]), isWhitelistedArray[i]);

            // Check that permission functions match whitelist status
            assertEq(gate.canSendShares(accounts[i]), isWhitelistedArray[i]);
            assertEq(gate.canReceiveAssets(accounts[i]), isWhitelistedArray[i]);
            assertEq(gate.canReceiveShares(accounts[i]), isWhitelistedArray[i]);
            assertEq(gate.canSendAssets(accounts[i]), isWhitelistedArray[i]);
        }
    }

    function testSetIsWhitelistedBatchArrayLengthMismatch(address[] memory accounts, bool[] memory isWhitelistedArray)
        public
    {
        vm.assume(accounts.length != isWhitelistedArray.length);
        vm.assume(accounts.length > 0 || isWhitelistedArray.length > 0);

        vm.prank(gateOwner);
        vm.expectRevert(GateWhitelist.ArrayLengthMismatch.selector);
        gate.setIsWhitelistedBatch(accounts, isWhitelistedArray);
    }

    function testBundlerAdapterOperations(address bundlerAdapterAddr, bool isAdapter, address nonOwner) public {
        vm.assume(bundlerAdapterAddr != address(0));
        vm.assume(nonOwner != address(0) && nonOwner != gateOwner);

        // Non-owner cannot set bundler adapter
        vm.prank(nonOwner);
        vm.expectRevert(GateWhitelist.Unauthorized.selector);
        gate.setIsBundlerAdapter(bundlerAdapterAddr, isAdapter);

        // Owner can set bundler adapter
        vm.prank(gateOwner);
        vm.expectEmit();
        emit GateWhitelist.SetIsBundlerAdapter(bundlerAdapterAddr, isAdapter);
        gate.setIsBundlerAdapter(bundlerAdapterAddr, isAdapter);
        assertEq(gate.isBundlerAdapter(bundlerAdapterAddr), isAdapter);
    }

    function testAdapterWithWhitelistedInitiator(address initiatorAddr, bool isWhitelisted) public {
        vm.assume(initiatorAddr != address(0));

        // Create a new bundler and adapter for the test
        address bundlerAddr = address(new Bundler3Mock(initiatorAddr));
        address bundlerAdapterAddr = address(new BundlerAdapterMock(IBundler3(bundlerAddr)));

        // Whitelist initiator
        vm.prank(gateOwner);
        gate.setIsWhitelisted(initiatorAddr, isWhitelisted);

        // Test when bundler adapter is not registered
        assertFalse(gate.canSendShares(bundlerAdapterAddr));
        assertFalse(gate.canReceiveAssets(bundlerAdapterAddr));
        assertFalse(gate.canReceiveShares(bundlerAdapterAddr));
        assertFalse(gate.canSendAssets(bundlerAdapterAddr));

        // Test when bundler adapter is registered
        vm.prank(gateOwner);
        gate.setIsBundlerAdapter(bundlerAdapterAddr, true);

        assertEq(gate.canSendShares(bundlerAdapterAddr), isWhitelisted);
        assertEq(gate.canReceiveAssets(bundlerAdapterAddr), isWhitelisted);
        assertEq(gate.canReceiveShares(bundlerAdapterAddr), isWhitelisted);
        assertEq(gate.canSendAssets(bundlerAdapterAddr), isWhitelisted);

        // Unwhitelist initiator
        vm.prank(gateOwner);
        gate.setIsWhitelisted(initiatorAddr, false);

        assertFalse(gate.canSendShares(bundlerAdapterAddr));
        assertFalse(gate.canReceiveAssets(bundlerAdapterAddr));
        assertFalse(gate.canReceiveShares(bundlerAdapterAddr));
        assertFalse(gate.canSendAssets(bundlerAdapterAddr));
    }
}
