// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VaultV2Factory, IVaultV2Factory} from "../../src/VaultV2Factory.sol";
import {IVaultV2, IERC4626, IERC20} from "../../src/interfaces/IVaultV2.sol";
import "../../src/libraries/ConstantsLib.sol";

import {ERC4626AdapterFactory, IERC4626AdapterFactory} from "../../src/adapters/ERC4626AdapterFactory.sol";
import {IERC4626Adapter} from "../../src/adapters/interfaces/IERC4626Adapter.sol";

import {Test, console2} from "../../lib/forge-std/src/Test.sol";

contract ERC4626AdapterIntegrationTest is Test {
    uint256 constant MAX_TEST_ASSETS = 1e18;
    uint256 constant FORK_BLOCK = 23189636; // Block with the historical transaction

    // Addresses of USDC, Stata USDC, and Merkl Distributor on Ethereum Mainnet
    IERC20 internal usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC4626 constant stataUSDC = IERC4626(0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E); // Stata USDC contract
    address constant merklDistributor = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae; // Merkl Distributor

    // Test accounts
    address immutable owner = makeAddr("owner");
    address immutable curator = makeAddr("curator");
    address immutable allocator = makeAddr("allocator");
    address immutable sentinel = makeAddr("sentinel");
    address internal immutable receiver = makeAddr("receiver");
    address internal immutable borrower = makeAddr("borrower");
    address immutable rewardClaimer = makeAddr("rewardClaimer");

    // Expected data
    bytes32 internal expectedAdapterId;
    bytes internal expectedAdapterIdData;

    // Contracts
    IVaultV2Factory internal vaultFactory;
    IVaultV2 internal vault;
    IERC4626AdapterFactory internal erc4626AdapterFactory;
    IERC4626Adapter internal erc4626Adapter;

    function setUp() public virtual {
        // Create mainnet fork
        string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
        uint256 mainnetFork = vm.createFork(rpcUrl, FORK_BLOCK);
        vm.selectFork(mainnetFork);

        vm.label(address(this), "testContract");
        vm.label(address(usdc), "usdc");
        vm.label(address(stataUSDC), "stataUSDC");
        vm.label(merklDistributor, "merklDistributor");

        // Create a new vault for USDC
        vaultFactory = IVaultV2Factory(address(new VaultV2Factory()));
        vault = IVaultV2(vaultFactory.createVaultV2(owner, address(usdc), bytes32(0)));
        vm.label(address(vault), "vault");

        // Deploy adapter factory and create adapter
        erc4626AdapterFactory = new ERC4626AdapterFactory();
        erc4626Adapter = IERC4626Adapter(erc4626AdapterFactory.createERC4626Adapter(address(vault), address(stataUSDC)));
        expectedAdapterIdData = abi.encode("this", address(erc4626Adapter));
        expectedAdapterId = keccak256(expectedAdapterIdData);
        vm.label(address(erc4626Adapter), "erc4626Adapter");

        // Set up vault roles
        vm.startPrank(owner);
        vault.setCurator(curator);
        vault.setIsSentinel(sentinel, true);
        vm.stopPrank();

        vm.startPrank(curator);

        // Set up allocator
        vault.submit(abi.encodeCall(IVaultV2.setIsAllocator, (allocator, true)));
        vault.setIsAllocator(allocator, true);

        // Set up adapter in vault
        vault.submit(abi.encodeCall(IVaultV2.setIsAdapter, (address(erc4626Adapter), true)));
        vault.setIsAdapter(address(erc4626Adapter), true);

        // Set max rate for interest accrual
        vault.submit(abi.encodeCall(IVaultV2.setMaxRate, (MAX_MAX_RATE)));
        vault.setMaxRate(MAX_MAX_RATE);

        // Set up absolute cap for the adapter
        vault.submit(abi.encodeCall(IVaultV2.increaseAbsoluteCap, (expectedAdapterIdData, type(uint128).max)));
        vault.increaseAbsoluteCap(expectedAdapterIdData, type(uint128).max);

        // Set up relative cap for the adapter
        vault.submit(abi.encodeCall(IVaultV2.increaseRelativeCap, (expectedAdapterIdData, WAD)));
        vault.increaseRelativeCap(expectedAdapterIdData, WAD);

        // Set claimer role
        erc4626Adapter.setClaimer(rewardClaimer);

        vm.stopPrank();

        // Fund user with USDC for testing
        deal(address(usdc), address(this), MAX_TEST_ASSETS);
        usdc.approve(address(vault), type(uint256).max);
    }

    function _setIsAdapter(address adapter, bool newIsAdapter) internal {
        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.setIsAdapter, (adapter, newIsAdapter)));
        vault.setIsAdapter(adapter, newIsAdapter);
    }

    function _setAdapterAbsoluteCap(bytes memory idData, uint256 newCap) internal {
        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.increaseAbsoluteCap, (idData, newCap)));
        vault.increaseAbsoluteCap(idData, newCap);
    }

    function _setAdapterRelativeCap(bytes memory idData, uint256 newCap) internal {
        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.increaseRelativeCap, (idData, newCap)));
        vault.increaseRelativeCap(idData, newCap);
    }
}
