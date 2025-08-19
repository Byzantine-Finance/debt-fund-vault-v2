// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CompoundV3IntegrationTest.sol";
import "forge-std/console2.sol";

contract CompoundV3IntegrationWithdrawTest is CompoundV3IntegrationTest {
    uint256 internal initialInIdle = 0.3e12 - 1;
    uint256 internal initialInCompoundFromAdapter = 0.7e12;
    uint256 internal initialTotal = 1e12 - 1;
    uint256 internal initialInCompound;

    function setUp() public virtual override {
        super.setUp();

        assertEq(initialTotal, initialInIdle + initialInCompoundFromAdapter);
        initialInCompound = initialInCompoundFromAdapter + usdc.balanceOf(address(comet));

        vault.deposit(initialTotal, address(this));

        vm.prank(allocator);
        vault.allocate(address(compoundAdapter), hex"", initialInCompoundFromAdapter);

        assertEq(usdc.balanceOf(address(vault)), initialInIdle);
        assertEq(usdc.balanceOf(address(comet)), initialInCompound);
    }

    function testWithdrawLessThanIdle(uint256 assets) public {
        assets = bound(assets, 0, initialInIdle);

        vault.withdraw(assets, receiver, address(this));

        assertEq(usdc.balanceOf(receiver), assets, "A");
        assertEq(usdc.balanceOf(address(vault)), initialInIdle - assets, "B");
        assertEq(usdc.balanceOf(address(comet)), initialInCompound, "C");
        assertEq(usdc.balanceOf(address(compoundAdapter)), 0, "D");
        assertApproxEqAbs(comet.balanceOf(address(compoundAdapter)), initialInCompoundFromAdapter, 2 wei, "E");
    }

    function testWithdrawMoreThanIdleNoLiquidityAdapter(uint256 assets) public {
        assets = bound(assets, initialInIdle + 1, MAX_TEST_ASSETS);

        vm.expectRevert();
        vault.withdraw(assets, receiver, address(this));
    }

    function testWithdrawThanksToLiquidityAdapter(uint256 assets) public {
        assets = bound(assets, initialInIdle + 1, initialTotal);
        vm.prank(allocator);
        vault.setLiquidityAdapterAndData(address(compoundAdapter), hex"");

        uint256 adapterBalanceBefore = comet.balanceOf(address(compoundAdapter));
        vm.warp(block.timestamp + 1 seconds);
        uint256 accruedInterest = comet.balanceOf(address(compoundAdapter)) - adapterBalanceBefore;

        vault.withdraw(assets, receiver, address(this));
        assertEq(usdc.balanceOf(receiver), assets, "A");
        assertEq(usdc.balanceOf(address(vault)), 0, "B");
        assertEq(usdc.balanceOf(address(comet)), initialInCompound + initialInIdle - assets, "C");
        assertEq(usdc.balanceOf(address(compoundAdapter)), 0, "D");
        assertApproxEqAbs(
            comet.balanceOf(address(compoundAdapter)), initialTotal + accruedInterest - assets, 4 wei, "E"
        );
    }

    function testWithdrawTooMuchEvenWithLiquidityAdapter(uint256 assets) public {
        assets = bound(assets, initialTotal + 1, MAX_TEST_ASSETS);
        vm.prank(allocator);
        vault.setLiquidityAdapterAndData(address(compoundAdapter), hex"");

        vm.expectRevert();
        vault.withdraw(assets, receiver, address(this));
    }

    function testWithdrawLiquidityAdapterNoLiquidityy(uint256 assets) public {
        assets = bound(assets, initialInIdle + 1, initialTotal);
        vm.prank(allocator);
        vault.setLiquidityAdapterAndData(address(compoundAdapter), hex"");

        // Fund borrower cbBTC collateral assets
        uint256 cbBTCSupplied = comet.totalsCollateral(address(cbBTC)).totalSupplyAsset;
        uint256 cbBTCSupplyCap = comet.getAssetInfoByAddress(address(cbBTC)).supplyCap;
        uint256 cbBTCToSupply = cbBTCSupplyCap - cbBTCSupplied;
        deal(address(cbBTC), borrower, cbBTCToSupply);

        // Fund borrower wstETH collateral assets
        uint256 wstETHSupplied = comet.totalsCollateral(address(wstETH)).totalSupplyAsset;
        uint256 wstETHSupplyCap = comet.getAssetInfoByAddress(address(wstETH)).supplyCap;
        uint256 wstETHToSupply = wstETHSupplyCap - wstETHSupplied;
        deal(address(wstETH), borrower, wstETHToSupply);

        // Remove liquidity by borrowing.
        vm.startPrank(borrower);
        cbBTC.approve(address(comet), type(uint256).max);
        comet.supply(address(cbBTC), cbBTCToSupply);
        wstETH.approve(address(comet), type(uint256).max);
        comet.supply(address(wstETH), wstETHToSupply);
        comet.withdraw(address(usdc), usdc.balanceOf(address(comet)));
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(comet)), 0);

        vm.expectRevert();
        vault.withdraw(assets, receiver, address(this));
    }
}
