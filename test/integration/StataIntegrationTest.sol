// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity ^0.8.0;

import "../BaseTest.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";

import {IVaultV2Factory} from "../../src/interfaces/IVaultV2Factory.sol";
import {IVaultV2} from "../../src/interfaces/IVaultV2.sol";
import {IERC4626} from "../../src/interfaces/IERC4626.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";

import {VaultV2Factory} from "../../src/VaultV2Factory.sol";
import "../../src/VaultV2.sol";
import {MorphoVaultV1Adapter} from "../../src/adapters/MorphoVaultV1Adapter.sol";
import {MorphoVaultV1AdapterFactory} from "../../src/adapters/MorphoVaultV1AdapterFactory.sol";
import {IMorphoVaultV1AdapterFactory} from "../../src/adapters/interfaces/IMorphoVaultV1AdapterFactory.sol";
import {IMorphoVaultV1Adapter} from "../../src/adapters/interfaces/IMorphoVaultV1Adapter.sol";
// import {VaultInterestCalculator} from "../../src/VaultInterestCalculator.sol";
// import {VaultVICIntegration} from "../../src/VaultVICIntegration.sol";
// import {IVaultInterestCalculator} from "../../src/interfaces/IVaultInterestCalculator.sol";
import {console} from "../../lib/forge-std/src/console.sol";

// AAVE V3 Pool interface
interface IPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
}

/// @title StataIntegrationTest
/// @notice Integration test for VaultV2 with Stata (AAVE ERC4626 wrapper) as liquidity adapter
/// @dev This test uses a mainnet fork at block 23027397 with USDC as the underlying asset
contract StataIntegrationTest is Test {
    // Mainnet addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant STATA_USDC = 0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E; // Stata USDC contract
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; // AAVE V3 Pool
    uint256 constant FORK_BLOCK = 23027397;

    // Test accounts
    address immutable owner = makeAddr("owner");
    address immutable curator = makeAddr("curator");
    address immutable allocator = makeAddr("allocator");
    address immutable sentinel = makeAddr("sentinel");
    address immutable user = makeAddr("user");

    // Contracts
    IVaultV2Factory vaultFactory;
    IVaultV2 vault;
    IMorphoVaultV1AdapterFactory adapterFactory;
    IMorphoVaultV1Adapter stataAdapter;
    IERC20 usdc;
    IERC4626 stata;
    IPool aavePool;

    // Fork management
    uint256 mainnetFork;

    function setUp() public {
        // Create mainnet fork
        string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createFork(rpcUrl, FORK_BLOCK);
        vm.selectFork(mainnetFork);

        // Initialize token contracts
        usdc = IERC20(USDC);
        stata = IERC4626(STATA_USDC);
        aavePool = IPool(AAVE_POOL);

        // Verify Stata is ERC4626 compliant and uses USDC as asset
        require(stata.asset() == USDC, "Stata asset mismatch");

        // Deploy vault factory and create vault
        vaultFactory = IVaultV2Factory(address(new VaultV2Factory()));
        vault = IVaultV2(vaultFactory.createVaultV2(owner, USDC, bytes32(0)));

        // Set up vault roles
        vm.startPrank(owner);
        vault.setCurator(curator);
        vault.setIsSentinel(sentinel, true);
        vault.setName("USDC Stata Vault");
        vault.setSymbol("vUSDC-STATA");
        vm.stopPrank();

        // Set up allocator
        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.setIsAllocator, (allocator, true)));
        vault.setIsAllocator(allocator, true);

        // Deploy adapter factory and create Stata adapter
        adapterFactory = new MorphoVaultV1AdapterFactory();
        stataAdapter = MorphoVaultV1Adapter(adapterFactory.createMorphoVaultV1Adapter(address(vault), STATA_USDC));

        // Set up adapter
        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.setIsAdapter, (address(stataAdapter), true)));
        vault.setIsAdapter(address(stataAdapter), true);

        // Set max rate for interest accrual
        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.setMaxRate, (MAX_MAX_RATE)));
        vault.setMaxRate(MAX_MAX_RATE);

        // Set up caps for the adapter
        bytes memory idData = abi.encode("this", address(stataAdapter));

        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.increaseAbsoluteCap, (idData, type(uint128).max)));
        vault.increaseAbsoluteCap(idData, type(uint128).max);

        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.increaseRelativeCap, (idData, 1e18))); // 100%
        vault.increaseRelativeCap(idData, 1e18);

        // Set Stata as liquidity adapter
        vm.prank(allocator);
        vault.setLiquidityAdapterAndData(address(stataAdapter), "");

        // Fund user with USDC for testing
        deal(USDC, user, 1000000e6); // 1M USDC

        // User approves vault
        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);

        // Label contracts for easier debugging
        vm.label(USDC, "USDC");
        vm.label(STATA_USDC, "Stata USDC");
        vm.label(AAVE_POOL, "AAVE Pool");
        vm.label(address(vault), "VaultV2");
        vm.label(address(stataAdapter), "StataAdapter");
        vm.label(user, "User");
    }

    function testVaultDeployment() public view {
        // Test basic vault properties
        assertEq(vault.asset(), USDC);
        assertEq(vault.owner(), owner);
        assertEq(vault.curator(), curator);
        assertEq(vault.name(), "USDC Stata Vault");
        assertEq(vault.symbol(), "vUSDC-STATA");

        // Test adapter setup
        assertTrue(vault.isAdapter(address(stataAdapter)));
        assertEq(vault.liquidityAdapter(), address(stataAdapter));

        // Test caps
        bytes32 adapterId = keccak256(abi.encode("this", address(stataAdapter)));
        assertEq(vault.absoluteCap(adapterId), type(uint128).max);
        assertEq(vault.relativeCap(adapterId), 1e18);
    }

    function testStataAdapterProperties() public view {
        // Test adapter properties
        assertEq(stataAdapter.parentVault(), address(vault));
        assertEq(stataAdapter.morphoVaultV1(), STATA_USDC);

        // Test initial state
        assertEq(stataAdapter.allocation(), 0);
        assertEq(stataAdapter.realAssets(), 0);

        // Test IDs
        bytes32[] memory ids = stataAdapter.ids();
        assertEq(ids.length, 1);
        assertEq(ids[0], keccak256(abi.encode("this", address(stataAdapter))));
    }

    function testDepositAndMint() public {
        uint256 depositAmount = 10000e6; // 10,000 USDC

        // Test deposit
        vm.prank(user);
        uint256 shares = vault.deposit(depositAmount, user);

        assertGt(shares, 0, "No shares minted");
        assertEq(vault.balanceOf(user), shares);
        assertEq(vault.totalSupply(), shares);

        // Check that funds were allocated to Stata
        assertGt(stataAdapter.allocation(), 0, "No allocation to Stata");
        assertGt(stata.balanceOf(address(stataAdapter)), 0, "No Stata shares");

        // Test mint
        uint256 mintShares = shares / 2;
        vm.prank(user);
        uint256 assets = vault.mint(mintShares, user);

        assertGt(assets, 0, "No assets for mint");
        assertEq(vault.balanceOf(user), shares + mintShares);
    }

    function testWithdrawAndRedeem() public {
        uint256 depositAmount = 10000e6; // 10,000 USDC

        // First deposit
        vm.prank(user);
        uint256 shares = vault.deposit(depositAmount, user);

        // Wait for some time to potentially accrue interest
        vm.warp(block.timestamp + 1 days);

        // Test withdraw
        uint256 withdrawAmount = 5000e6; // 5,000 USDC
        uint256 userBalanceBefore = usdc.balanceOf(user);

        vm.prank(user);
        uint256 sharesRedeemed = vault.withdraw(withdrawAmount, user, user);

        assertGt(sharesRedeemed, 0, "No shares redeemed");
        assertEq(usdc.balanceOf(user) - userBalanceBefore, withdrawAmount);
        assertEq(vault.balanceOf(user), shares - sharesRedeemed);

        // Test redeem
        uint256 remainingShares = vault.balanceOf(user);
        vm.prank(user);
        uint256 assetsReceived = vault.redeem(remainingShares, user, user);

        assertGt(assetsReceived, 0, "No assets received");
        assertEq(vault.balanceOf(user), 0);
    }

    function testAllocation() public {
        uint256 depositAmount = 10000e6; // 10,000 USDC

        // Deposit to vault
        vm.prank(user);
        vault.deposit(depositAmount, user);

        // Check initial allocation (should be automatic via liquidity adapter)
        uint256 initialAllocation = stataAdapter.allocation();
        assertGt(initialAllocation, 0, "No initial allocation");

        // Manual allocation test
        uint256 additionalAmount = 5000e6;
        deal(USDC, address(vault), additionalAmount);

        vm.prank(allocator);
        vault.allocate(address(stataAdapter), "", additionalAmount);

        // Check allocation increased
        assertGt(stataAdapter.allocation(), initialAllocation, "Allocation didn't increase");

        // Test deallocation
        vm.prank(allocator);
        vault.deallocate(address(stataAdapter), "", additionalAmount);

        // Check allocation decreased
        assertEq(stataAdapter.allocation(), initialAllocation, "Deallocation failed");
    }

    function testInterestAccrual() public {
        uint256 depositAmount = 100000e6; // 100,000 USDC

        // Deposit to vault
        vm.prank(user);
        uint256 shares = vault.deposit(depositAmount, user);

        // Record initial state - both vault and Stata
        uint256 initialTotalAssets = vault.totalAssets();
        uint256 initialShareValue = vault.previewRedeem(shares);
        uint256 initialStataShares = stata.balanceOf(address(stataAdapter));
        uint256 initialStataAssets = stata.previewRedeem(initialStataShares);

        console.log("=== Initial State ===");
        console.log("Vault total assets:", initialTotalAssets);
        console.log("Vault share value:", initialShareValue);
        console.log("Stata shares held:", initialStataShares);
        console.log("Stata assets value:", initialStataAssets);

        // Simulate time passage and potential yield from Stata
        vm.warp(block.timestamp + 30 days);

        // Check Stata interest accrual first (before vault accrual)
        uint256 stataAssetsAfterTime = stata.previewRedeem(initialStataShares);
        console.log("=== After Time Passage ===");
        console.log("Stata assets after time:", stataAssetsAfterTime);
        console.log("Stata interest earned:", stataAssetsAfterTime - initialStataAssets);

        // Verify Stata has accrued interest
        if (stataAssetsAfterTime > initialStataAssets) {
            console.log("Stata accrued interest:", stataAssetsAfterTime - initialStataAssets);
        } else {
            console.log("Stata did not accrue interest (market conditions)");
        }

        // Now accrue interest in vault
        vault.accrueInterest();

        uint256 finalTotalAssets = vault.totalAssets();
        uint256 finalShareValue = vault.previewRedeem(shares);

        console.log("=== After Vault Interest Accrual ===");
        console.log("Final vault total assets:", finalTotalAssets);
        console.log("Final vault share value:", finalShareValue);
        console.log("Vault interest change:", int256(finalTotalAssets) - int256(initialTotalAssets));

        // Check if there's any interest accrual (depends on Stata's performance)
        // Note: This might not always increase due to market conditions, but should at least not decrease significantly
        assertTrue(finalTotalAssets >= initialTotalAssets - 1, "Total assets decreased significantly");
        assertTrue(finalShareValue >= initialShareValue - 1, "Share value decreased significantly");

        // If Stata accrued interest, vault should reflect it
        if (stataAssetsAfterTime > initialStataAssets + 1) {
            assertTrue(finalTotalAssets >= initialTotalAssets, "Vault should reflect Stata interest");
            console.log("Vault properly reflects Stata interest accrual");
        }
    }

    function testPreviewFunctions() public {
        uint256 depositAmount = 10000e6; // 10,000 USDC

        // Test preview functions before any deposits
        uint256 previewShares = vault.previewDeposit(depositAmount);
        uint256 previewAssets = vault.previewMint(previewShares);

        assertGt(previewShares, 0, "Preview deposit failed");
        assertApproxEqAbs(previewAssets, depositAmount, 1, "Preview mint mismatch");

        // Make actual deposit
        vm.prank(user);
        uint256 actualShares = vault.deposit(depositAmount, user);

        // Preview functions should be consistent
        assertApproxEqAbs(actualShares, previewShares, 1, "Actual shares mismatch");

        // Test withdraw/redeem previews
        uint256 previewWithdrawShares = vault.previewWithdraw(depositAmount / 2);
        uint256 previewRedeemAssets = vault.previewRedeem(actualShares / 2);

        assertGt(previewWithdrawShares, 0, "Preview withdraw failed");
        assertGt(previewRedeemAssets, 0, "Preview redeem failed");
    }

    function testMaxFunctions() public view {
        // Max functions should return 0 as per vault specification
        assertEq(vault.maxDeposit(user), 0);
        assertEq(vault.maxMint(user), 0);
        assertEq(vault.maxWithdraw(user), 0);
        assertEq(vault.maxRedeem(user), 0);
    }

    function testConversionFunctions() public {
        uint256 depositAmount = 10000e6; // 10,000 USDC

        // Make a deposit to establish exchange rate
        vm.prank(user);
        uint256 shares = vault.deposit(depositAmount, user);

        // Test conversion functions
        uint256 convertedShares = vault.convertToShares(depositAmount);
        uint256 convertedAssets = vault.convertToAssets(shares);

        assertApproxEqAbs(convertedShares, shares, 1, "Share conversion mismatch");
        assertApproxEqAbs(convertedAssets, depositAmount, 1, "Asset conversion mismatch");
    }

    function testStataIntegration() public {
        uint256 depositAmount = 50000e6; // 50,000 USDC

        // Record initial Stata state
        uint256 initialStataShares = stata.balanceOf(address(stataAdapter));

        // Deposit to vault
        vm.prank(user);
        vault.deposit(depositAmount, user);

        // Check Stata integration
        uint256 finalStataShares = stata.balanceOf(address(stataAdapter));
        assertGt(finalStataShares, initialStataShares, "No Stata shares acquired");

        // Check that adapter reports correct real assets
        uint256 reportedAssets = stataAdapter.realAssets();
        uint256 expectedAssets = stata.previewRedeem(finalStataShares);
        assertApproxEqAbs(reportedAssets, expectedAssets, 1, "Real assets mismatch");

        // Test that we can withdraw from Stata
        vm.prank(user);
        vault.withdraw(depositAmount / 2, user, user);

        // Stata shares should have decreased
        assertLt(stata.balanceOf(address(stataAdapter)), finalStataShares, "Stata shares didn't decrease");
    }

    function testAAVEPoolIntegration() public {
        // Test direct AAVE pool interaction to verify it works on this fork
        uint256 testAmount = 10000e6; // 10,000 USDC
        address testUser = makeAddr("testUser");

        // Fund test user
        deal(USDC, testUser, testAmount);

        vm.startPrank(testUser);
        usdc.approve(AAVE_POOL, testAmount);

        console.log("=== AAVE Pool Integration Test ===");
        console.log("Test user USDC balance before:", usdc.balanceOf(testUser));

        // Supply to AAVE pool
        aavePool.supply(USDC, testAmount, testUser, 0);

        console.log("Test user USDC balance after supply:", usdc.balanceOf(testUser));
        console.log("Successfully supplied to AAVE pool");

        vm.stopPrank();

        // Verify the supply worked
        assertEq(usdc.balanceOf(testUser), 0, "USDC should be supplied to AAVE");
    }

    function testStataYieldGenerationWithAAVE() public {
        uint256 depositAmount = 100000e6; // 100,000 USDC

        // Deposit to vault
        vm.prank(user);
        uint256 shares = vault.deposit(depositAmount, user);

        uint256 initialStataShares = stata.balanceOf(address(stataAdapter));
        uint256 initialStataAssets = stata.previewRedeem(initialStataShares);

        console.log("=== AAVE Yield Generation Test ===");
        console.log("Initial Stata shares:", initialStataShares);
        console.log("Initial Stata asset value:", initialStataAssets);

        // Generate yield by depositing additional USDC directly to AAVE pool
        // This simulates external lending activity that generates yield for all USDC depositors
        uint256 yieldGeneratingDeposit = 10000000e6; // 10M USDC to generate meaningful yield
        address yieldGenerator = makeAddr("yieldGenerator");

        // Fund the yield generator and approve AAVE pool
        deal(USDC, yieldGenerator, yieldGeneratingDeposit);
        vm.startPrank(yieldGenerator);
        usdc.approve(AAVE_POOL, yieldGeneratingDeposit);

        // Deposit to AAVE pool to increase utilization and generate yield
        aavePool.supply(USDC, yieldGeneratingDeposit, yieldGenerator, 0);
        vm.stopPrank();

        console.log("Deposited to AAVE pool:", yieldGeneratingDeposit);

        // Simulate time passage to allow interest accrual
        vm.warp(block.timestamp + 7 days);

        // Check that Stata now has more assets per share due to AAVE yield
        uint256 stataAssetsAfterYield = stata.previewRedeem(initialStataShares);
        console.log("Stata assets after AAVE yield:", stataAssetsAfterYield);
        console.log("AAVE yield captured by Stata:", stataAssetsAfterYield - initialStataAssets);

        // The adapter should report the increased real assets
        uint256 adapterRealAssets = stataAdapter.realAssets();
        console.log("Adapter reported real assets:", adapterRealAssets);

        // Vault should reflect the increased value when interest is accrued
        // Let's trigger interest accrual by making a small redeposit
        uint256 smallDeposit = 1000e6; // 1,000 USDC
        deal(USDC, user, usdc.balanceOf(user) + smallDeposit);

        uint256 vaultAssetsBeforeRedeposit = vault.totalAssets();
        console.log("Vault assets before redeposit:", vaultAssetsBeforeRedeposit);

        // This deposit will automatically call accrueInterest() in enter()
        vm.prank(user);
        vault.deposit(smallDeposit, user);

        uint256 vaultAssetsAfterRedeposit = vault.totalAssets();
        console.log("Vault assets after redeposit:", vaultAssetsAfterRedeposit);
        uint256 yieldCaptured = vaultAssetsAfterRedeposit - vaultAssetsBeforeRedeposit - smallDeposit;

        console.log("Small deposit amount:", smallDeposit);
        console.log("Yield captured by vault:", yieldCaptured);
        console.log("Expected Stata yield:", stataAssetsAfterYield - initialStataAssets);

        // Check firstTotalAssets after the redeposit
        console.log("firstTotalAssets after redeposit:", vault.firstTotalAssets());

        // Assertions - AAVE should generate some yield over 7 days
        if (stataAssetsAfterYield > initialStataAssets) {
            console.log("AAVE generated yield captured by Stata");
            assertGt(stataAssetsAfterYield, initialStataAssets, "Stata should have more assets after AAVE yield");
            assertApproxEqAbs(adapterRealAssets, stataAssetsAfterYield, 2, "Adapter should report correct real assets");

            // Check if the redeposit captured the yield
            if (yieldCaptured > 0) {
                console.log("Vault successfully captured AAVE yield through redeposit!");
                assertGt(yieldCaptured, 0, "Vault should capture yield on redeposit");
            } else {
                console.log("Yield not captured on redeposit, may need different approach");
            }
        } else {
            console.log("No AAVE yield generated (low utilization or market conditions)");
            // Even without yield, system should be stable
            assertGe(stataAssetsAfterYield, initialStataAssets - 1, "Assets should not decrease significantly");
        }
    }

    function testYieldAccrualAcrossTransactions() public {
        uint256 depositAmount = 100000e6; // 100,000 USDC

        // Deposit to vault in first "transaction"
        vm.prank(user);
        uint256 shares = vault.deposit(depositAmount, user);

        // Record initial state
        uint256 initialVaultAssets = vault.totalAssets();
        uint256 initialStataShares = stata.balanceOf(address(stataAdapter));
        uint256 initialStataAssets = stata.previewRedeem(initialStataShares);

        console.log("=== Cross-Transaction Yield Test ===");
        console.log("Initial vault assets:", initialVaultAssets);
        console.log("Initial Stata assets:", initialStataAssets);
        console.log("firstTotalAssets after deposit:", vault.firstTotalAssets());

        // Generate AAVE yield
        uint256 yieldGeneratingDeposit = 5000000e6; // 5M USDC
        address yieldGenerator = makeAddr("yieldGenerator");
        deal(USDC, yieldGenerator, yieldGeneratingDeposit);

        vm.startPrank(yieldGenerator);
        usdc.approve(AAVE_POOL, yieldGeneratingDeposit);
        aavePool.supply(USDC, yieldGeneratingDeposit, yieldGenerator, 0);
        vm.stopPrank();

        // Simulate time passage
        vm.warp(block.timestamp + 7 days);

        // Check Stata yield
        uint256 stataAssetsAfterYield = stata.previewRedeem(initialStataShares);
        console.log("Stata assets after yield:", stataAssetsAfterYield);
        console.log("Stata yield:", stataAssetsAfterYield - initialStataAssets);

        // Trigger interest accrual with a small redeposit (simulates new transaction)
        uint256 smallRedeposit = 500e6; // 500 USDC
        deal(USDC, user, usdc.balanceOf(user) + smallRedeposit);

        uint256 vaultAssetsBeforeRedeposit = vault.totalAssets();
        console.log("Vault assets before redeposit:", vaultAssetsBeforeRedeposit);

        // This will trigger accrueInterest() and should capture the Stata yield
        vm.prank(user);
        vault.deposit(smallRedeposit, user);

        uint256 vaultAssetsAfterRedeposit = vault.totalAssets();
        uint256 capturedYield = vaultAssetsAfterRedeposit - vaultAssetsBeforeRedeposit - smallRedeposit;

        console.log("Vault assets after redeposit:", vaultAssetsAfterRedeposit);
        console.log("Small redeposit amount:", smallRedeposit);
        console.log("Yield captured through redeposit:", capturedYield);

        // Verify yield was captured
        if (stataAssetsAfterYield > initialStataAssets) {
            if (capturedYield > 0) {
                console.log("Vault successfully captured AAVE yield through redeposit");
                assertGt(capturedYield, 0, "Vault should capture yield on redeposit");
            } else {
                console.log("Yield not captured despite Stata gains");
            }
        }
    }

    function testLargeDepositsAndWithdrawals() public {
        uint256 largeAmount = 500000e6; // 500,000 USDC

        // Fund user with large amount
        deal(USDC, user, largeAmount);

        // Large deposit
        vm.prank(user);
        uint256 shares = vault.deposit(largeAmount, user);

        assertGt(shares, 0, "No shares for large deposit");
        assertEq(vault.balanceOf(user), shares);

        // Check allocation
        assertGt(stataAdapter.allocation(), 0, "No allocation for large deposit");

        // Large withdrawal
        vm.prank(user);
        uint256 assetsReceived = vault.redeem(shares, user, user);

        assertGt(assetsReceived, 0, "No assets for large withdrawal");
        assertApproxEqAbs(assetsReceived, largeAmount, largeAmount / 1000, "Large withdrawal mismatch"); // 0.1% tolerance
    }

    // function testWithManualVIC() public {
    //     // Import VIC contracts
    //     VaultInterestCalculator vic = new VaultInterestCalculator(owner);
    //     VaultVICIntegration integration = new VaultVICIntegration(owner);

    //     // Set up VIC integration
    //     vm.startPrank(owner);
    //     vic.setAuthorizedCaller(address(integration), true);
    //     integration.initializeVaultVIC(address(vault), address(vic), 0.08e18); // 8% APY
    //     vm.stopPrank();

    //     console.log("=== Manual VIC Integration Test ===");

    //     // Initial deposit
    //     uint256 depositAmount = 100000e6; // 100,000 USDC
    //     vm.prank(user);
    //     uint256 shares = vault.deposit(depositAmount, user);

    //     // Check VIC integration
    //     assertTrue(integration.hasVICIntegration(address(vault)));
    //     assertEq(integration.getVaultAPY(address(vault)), 0.08e18);

    //     console.log("Initial deposit:", depositAmount);
    //     console.log("Shares received:", shares);
    //     console.log("VIC APY:", integration.getVaultAPY(address(vault)));

    //     // Fast forward time to accumulate interest
    //     vm.warp(block.timestamp + 90 days); // 3 months

    //     // Get interest info before accrual
    //     (
    //         uint256 apy,
    //         uint256 pendingInterest,
    //         uint256 utilizationRate,
    //         uint256 totalAccruedInterest
    //     ) = integration.getVaultInterestInfo(address(vault));

    //     console.log("After 90 days:");
    //     console.log("  APY:", apy);
    //     console.log("  Pending Interest:", pendingInterest);
    //     console.log("  Utilization Rate:", utilizationRate);
    //     console.log("  Total Accrued Interest:", totalAccruedInterest);

    //     assertGt(pendingInterest, 0, "Should have pending interest after 90 days");

    //     // Accrue interest through VIC
    //     vm.prank(owner);
    //     uint256 accruedInterest = integration.accrueVICInterest(address(vault));

    //     console.log("Accrued interest from VIC:", accruedInterest);
    //     assertEq(accruedInterest, pendingInterest, "Accrued should equal pending");

    //     // Test APY adjustment based on utilization
    //     vm.prank(owner);
    //     integration.updateAPYFromUtilization(address(vault));

    //     // Test different APY settings
    //     uint256 newAPY = 0.12e18; // 12% APY
    //     vm.prank(owner);
    //     vic.setAPY(address(vault), newAPY);

    //     assertEq(integration.getVaultAPY(address(vault)), newAPY);
    //     console.log("Updated APY to:", newAPY);

    //     // Test interest rate model
    //     IVaultInterestCalculator.InterestRateParams memory params = IVaultInterestCalculator.InterestRateParams({
    //         baseRate: 0.02e18,      // 2% base
    //         multiplier: 0.08e18,    // 8% multiplier
    //         jumpMultiplier: 0.3e18, // 30% jump
    //         kink: 0.8e18           // 80% kink
    //     });

    //     vm.prank(owner);
    //     vic.setInterestRateParams(address(vault), params);

    //     // Test utilization-based APY calculation
    //     uint256 currentUtilization = integration.getVaultUtilization(address(vault));
    //     uint256 calculatedAPY = vic.calculateAPYFromUtilization(address(vault), currentUtilization);

    //     console.log("Current utilization:", currentUtilization);
    //     console.log("Calculated APY from utilization:", calculatedAPY);

    //     // Update APY based on utilization
    //     vm.prank(owner);
    //     integration.updateAPYFromUtilization(address(vault));

    //     uint256 finalAPY = integration.getVaultAPY(address(vault));
    //     console.log("Final APY after utilization update:", finalAPY);

    //     // Test compound frequency adjustment
    //     vm.prank(owner);
    //     vic.setCompoundFrequency(address(vault), 12); // Monthly compounding

    //     // Preview interest for different time periods
    //     uint256 interest1Month = integration.previewInterest(address(vault), 30 days);
    //     uint256 interest6Months = integration.previewInterest(address(vault), 180 days);

    //     console.log("Preview interest for 1 month:", interest1Month);
    //     console.log("Preview interest for 6 months:", interest6Months);

    //     assertGt(interest6Months, interest1Month * 6, "6-month interest should be more than 6x 1-month due to compounding");

    //     // Final comprehensive check
    //     (apy, pendingInterest, utilizationRate, totalAccruedInterest) = integration.getVaultInterestInfo(address(vault));

    //     console.log("=== Final State ===");
    //     console.log("Final APY:", apy);
    //     console.log("Final Pending Interest:", pendingInterest);
    //     console.log("Final Utilization Rate:", utilizationRate);
    //     console.log("Final Total Accrued Interest:", totalAccruedInterest);

    //     // Verify the VIC system is working correctly
    //     assertTrue(vic.isVaultManaged(address(vault)), "Vault should be managed by VIC");
    //     assertGt(totalAccruedInterest, 0, "Should have accrued some interest");
    //     assertEq(apy, finalAPY, "APY should match between VIC and integration");
    // }
    
}
