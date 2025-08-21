// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../BaseTest.sol";
import {stdJson} from "../../lib/forge-std/src/StdJson.sol";
import {console} from "../../lib/forge-std/src/console.sol";

import {IVaultV2Factory} from "../../src/interfaces/IVaultV2Factory.sol";
import {IVaultV2} from "../../src/interfaces/IVaultV2.sol";
import {IERC4626} from "../../src/interfaces/IERC4626.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";

import {VaultV2Factory} from "../../src/VaultV2Factory.sol";
import "../../src/VaultV2.sol";
import {ERC4626AdapterFactory} from "../../src/adapters/ERC4626AdapterFactory.sol";
import {IERC4626AdapterFactory} from "../../src/adapters/interfaces/IERC4626AdapterFactory.sol";
import {IERC4626Adapter} from "../../src/adapters/interfaces/IERC4626Adapter.sol";
import {MerklParams} from "../../src/adapters/ERC4626Adapter.sol";

// Merkl Distributor interface
interface IMerklDistributor {
    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;
}

/// @title MerklIntegrationTest
/// @notice Integration test for ERC4626Adapter with Merkl reward claiming functionality
/// @dev This test uses real historical Merkl transaction data on mainnet fork
contract MerklIntegrationTest is BaseTest {
    // Mainnet addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant STATA_USDC = 0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E; // Stata USDC contract (used as ERC4626
        // vault)
    address constant REAL_MERKL_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae; // Real Merkl Distributor
    uint256 constant FORK_BLOCK = 23189636; // Block with the historical transaction

    // Test accounts
    address immutable user = makeAddr("user");
    address immutable rewardClaimer = makeAddr("rewardClaimer");

    // Contracts
    IERC4626AdapterFactory adapterFactory;
    IERC4626Adapter merklAdapter;
    IERC20 usdc;

    // Fork management
    uint256 mainnetFork;

    function setUp() public override {
        // Create mainnet fork
        string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createFork(rpcUrl, FORK_BLOCK);
        vm.selectFork(mainnetFork);

        // Initialize token contracts
        usdc = IERC20(USDC);

        // Create a new vault for USDC
        vaultFactory = IVaultV2Factory(address(new VaultV2Factory()));
        vault = IVaultV2(vaultFactory.createVaultV2(owner, USDC, bytes32(0)));

        // Set up vault roles
        vm.startPrank(owner);
        vault.setCurator(curator);
        vault.setIsSentinel(sentinel, true);
        vault.setName("USDC Merkl Test Vault");
        vault.setSymbol("vUSDC-MERKL");
        vm.stopPrank();

        // Set up allocator
        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.setIsAllocator, (allocator, true)));
        vault.setIsAllocator(allocator, true);

        // Set max rate for interest accrual
        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.setMaxRate, (MAX_MAX_RATE)));
        vault.setMaxRate(MAX_MAX_RATE);

        // Deploy adapter factory and create Merkl-enabled adapter
        adapterFactory = new ERC4626AdapterFactory();
        merklAdapter =
            IERC4626Adapter(adapterFactory.createERC4626Adapter(address(vault), STATA_USDC, REAL_MERKL_DISTRIBUTOR));

        // Set up adapter in vault
        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.setIsAdapter, (address(merklAdapter), true)));
        vault.setIsAdapter(address(merklAdapter), true);

        // Set up caps for the adapter
        bytes memory idData = abi.encode("this", address(merklAdapter));

        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.increaseAbsoluteCap, (idData, type(uint128).max)));
        vault.increaseAbsoluteCap(idData, type(uint128).max);

        vm.prank(curator);
        vault.submit(abi.encodeCall(IVaultV2.increaseRelativeCap, (idData, 1e18))); // 100%
        vault.increaseRelativeCap(idData, 1e18);

        // Set claimer role
        vm.prank(curator);
        merklAdapter.setClaimer(rewardClaimer);

        // Fund test accounts with tokens
        deal(USDC, user, 1000000e6); // 1M USDC

        // User approves vault
        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);

        // Label contracts for easier debugging
        vm.label(USDC, "USDC");
        vm.label(address(vault), "VaultV2");
        vm.label(address(merklAdapter), "MerklAdapter");
        vm.label(REAL_MERKL_DISTRIBUTOR, "RealMerklDistributor");
        vm.label(rewardClaimer, "RewardClaimer");
        vm.label(user, "User");
    }

    /// @notice Test with real historical Merkl transaction data
    /// @dev This test uses actual transaction data from block 23189636 loaded from JSON
    function testHistoricalMerklTransaction() public {
        // Make a deposit to establish vault activity
        uint256 depositAmount = 100000e6; // 100,000 USDC
        vm.prank(user);
        vault.deposit(depositAmount, user);

        // Load historical claim data from JSON file
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/data/historical_merkl_claim.json");
        string memory json = vm.readFile(path);

        // Parse users array - use the hardcoded working values from JSON
        address[] memory users = new address[](1);
        users[0] = stdJson.readAddress(json, ".claimData.users[0]");

        // Parse tokens array
        address[] memory tokens = new address[](1);
        tokens[0] = stdJson.readAddress(json, ".claimData.tokens[0]");

        // Parse amounts array - parse as uint256 directly
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = stdJson.readUint(json, ".claimData.amounts[0]");

        // Parse proofs array - manually extract the proof elements
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](17);
        proofs[0][0] = stdJson.readBytes32(json, ".claimData.proofs[0][0]");
        proofs[0][1] = stdJson.readBytes32(json, ".claimData.proofs[0][1]");
        proofs[0][2] = stdJson.readBytes32(json, ".claimData.proofs[0][2]");
        proofs[0][3] = stdJson.readBytes32(json, ".claimData.proofs[0][3]");
        proofs[0][4] = stdJson.readBytes32(json, ".claimData.proofs[0][4]");
        proofs[0][5] = stdJson.readBytes32(json, ".claimData.proofs[0][5]");
        proofs[0][6] = stdJson.readBytes32(json, ".claimData.proofs[0][6]");
        proofs[0][7] = stdJson.readBytes32(json, ".claimData.proofs[0][7]");
        proofs[0][8] = stdJson.readBytes32(json, ".claimData.proofs[0][8]");
        proofs[0][9] = stdJson.readBytes32(json, ".claimData.proofs[0][9]");
        proofs[0][10] = stdJson.readBytes32(json, ".claimData.proofs[0][10]");
        proofs[0][11] = stdJson.readBytes32(json, ".claimData.proofs[0][11]");
        proofs[0][12] = stdJson.readBytes32(json, ".claimData.proofs[0][12]");
        proofs[0][13] = stdJson.readBytes32(json, ".claimData.proofs[0][13]");
        proofs[0][14] = stdJson.readBytes32(json, ".claimData.proofs[0][14]");
        proofs[0][15] = stdJson.readBytes32(json, ".claimData.proofs[0][15]");
        proofs[0][16] = stdJson.readBytes32(json, ".claimData.proofs[0][16]");

        MerklParams memory merklParams = MerklParams({users: users, tokens: tokens, amounts: amounts, proofs: proofs});

        // Record initial state
        uint256 initialOriginalUserBalance = IERC20(tokens[0]).balanceOf(users[0]);

        // Execute claim by calling the Merkl distributor directly
        // We prank as the original user who has the valid Merkle proof
        vm.etch(users[0], address(merklAdapter).code);
        bytes memory data = abi.encode(merklParams);
        // Set claimer role
        vm.prank(curator);
        IERC4626Adapter(users[0]).setClaimer(rewardClaimer);
        vm.prank(rewardClaimer);
        IERC4626Adapter(users[0]).claim(data);
        uint256 finalOriginalUserBalance = IERC20(tokens[0]).balanceOf(users[0]);
        assertEq(
            finalOriginalUserBalance - initialOriginalUserBalance,
            amounts[0],
            "Original user should receive historical claim amount"
        );

        console.log("Historical claim executed successfully");
    }
}
