// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VaultV2Factory, IVaultV2Factory} from "../../src/VaultV2Factory.sol";
import {IVaultV2, IERC20} from "../../src/interfaces/IVaultV2.sol";
import "../../src/libraries/ConstantsLib.sol";

import {ERC4626AdapterFactory} from "../../src/adapters/ERC4626AdapterFactory.sol";
import {IERC4626AdapterFactory} from "../../src/adapters/interfaces/IERC4626AdapterFactory.sol";
import {IERC4626Adapter} from "../../src/adapters/interfaces/IERC4626Adapter.sol";

import {IERC4626} from "../../src/interfaces/IERC4626.sol";

import {Test, console2} from "../../lib/forge-std/src/Test.sol";

contract SkyIntegrationTest is Test {
    uint256 constant MAX_TEST_ASSETS = 1e12;
    uint256 constant FORK_BLOCK = 23027397;

    // Addresses of Sky sUSDC, sUSDS, USDS and USDC on Ethereum Mainnet
    IERC4626 internal sUSDC = IERC4626(0xBc65ad17c5C0a2A4D159fa5a503f4992c7B545FE);
    IERC4626 internal sUSDS = IERC4626(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
    IERC20 internal usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);

    // Test accounts
    address immutable owner = makeAddr("owner");
    address immutable curator = makeAddr("curator");
    address immutable allocator = makeAddr("allocator");
    address immutable sentinel = makeAddr("sentinel");
    address internal immutable receiver = makeAddr("receiver");
    address internal immutable borrower = makeAddr("borrower");

    // Expected data
    bytes32 internal expectedAdapterId;
    bytes internal expectedAdapterIdData;

    // Contracts
    IVaultV2Factory internal vaultFactory;
    IVaultV2 internal vault;
    IERC4626AdapterFactory internal erc4626AdapterFactory;
    IERC4626Adapter internal skyAdapter;

    function setUp() public virtual {
        // Create mainnet fork
        string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
        uint256 mainnetFork = vm.createFork(rpcUrl, FORK_BLOCK);
        vm.selectFork(mainnetFork);

        vm.label(address(this), "testContract");
        vm.label(address(sUSDC), "sUSDC");
        vm.label(address(sUSDS), "sUSDS");
        vm.label(address(usdc), "usdc");
        vm.label(address(usds), "usds");

        /* VAULT SETUP */

        vaultFactory = IVaultV2Factory(address(new VaultV2Factory()));
        vault = IVaultV2(vaultFactory.createVaultV2(owner, address(usdc), bytes32(0)));
        vm.label(address(vault), "vault");

        erc4626AdapterFactory = IERC4626AdapterFactory(address(new ERC4626AdapterFactory()));
        skyAdapter = IERC4626Adapter(erc4626AdapterFactory.createERC4626Adapter(address(vault), address(sUSDC)));
        expectedAdapterIdData = abi.encode("this", address(skyAdapter));
        expectedAdapterId = keccak256(expectedAdapterIdData);
        vm.label(address(skyAdapter), "skyAdapter");

        vm.startPrank(owner);
        vault.setCurator(curator);
        vault.setIsSentinel(sentinel, true);
        vm.stopPrank();

        vm.startPrank(curator);

        vault.submit(abi.encodeCall(IVaultV2.setIsAllocator, (allocator, true)));
        vault.setIsAllocator(allocator, true);

        vault.submit(abi.encodeCall(IVaultV2.setIsAdapter, (address(skyAdapter), true)));
        vault.setIsAdapter(address(skyAdapter), true);

        vault.submit(abi.encodeCall(IVaultV2.setMaxRate, (MAX_MAX_RATE)));
        vault.setMaxRate(MAX_MAX_RATE);

        vault.submit(abi.encodeCall(IVaultV2.increaseAbsoluteCap, (expectedAdapterIdData, type(uint128).max)));
        vault.increaseAbsoluteCap(expectedAdapterIdData, type(uint128).max);

        vault.submit(abi.encodeCall(IVaultV2.increaseRelativeCap, (expectedAdapterIdData, WAD)));
        vault.increaseRelativeCap(expectedAdapterIdData, WAD);

        vm.stopPrank();

        // Set Sky as liquidity adapter
        vm.prank(allocator);
        vault.setLiquidityAdapterAndData(address(skyAdapter), "");

        // Fund user with USDC for testing
        deal(address(usdc), address(this), MAX_TEST_ASSETS);
        usdc.approve(address(vault), type(uint256).max);
    }

    function testsUSDCDeposit(uint256 assets) public {
        assets = bound(assets, 0, MAX_TEST_ASSETS);

        uint256 USDSBalanceBefore = usds.balanceOf(address(sUSDC));
        uint256 expectedReceivedShares = sUSDC.previewDeposit(assets);
        // USDC are swapped to USDS that are deposited to sUSDS
        vault.deposit(assets, address(this));

        assertEq(sUSDC.balanceOf(address(skyAdapter)), expectedReceivedShares, "adapter sUSDC balance");
        assertApproxEqAbs(
            sUSDC.convertToAssets(sUSDC.balanceOf(address(skyAdapter))), assets, 1 wei, "adapter sUSDC conversion"
        );

        uint256 USDSBalanceAfter = usds.balanceOf(address(sUSDC));
        assertGe(USDSBalanceBefore + assets, USDSBalanceAfter, "sUSDS USDS balance");
    }

    /// forge-config: default.isolate = true
    function testsUSDCWithdrawInterest(uint256 assets, uint256 elapsed) public {
        assets = bound(assets, 0, MAX_TEST_ASSETS);
        elapsed = bound(elapsed, 1, 10 * 365 days);

        vault.deposit(assets, address(this));

        skip(elapsed);

        uint256 newAssets = sUSDC.convertToAssets(sUSDC.balanceOf(address(skyAdapter)));
        uint256 interest = newAssets - assets;

        vault.redeem(vault.balanceOf(address(this)), receiver, address(this));
        assertApproxEqAbs(usdc.balanceOf(receiver), assets + interest, 1 wei, "withdraw all");
    }
}
