// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {stdJson} from "../../lib/forge-std/src/StdJson.sol";

import "./ERC4626AdapterIntegrationTest.sol";

/// @title MerklIntegrationTest
/// @notice Integration test for ERC4626Adapter with Merkl reward claiming functionality
/// @dev This test uses real historical Merkl transaction data on mainnet fork
contract ERC4626AdapterIntegrationMerklTest is ERC4626AdapterIntegrationTest {
    uint256 internal initialDeposit = 100000e6; // 100,000 USDC

    // Fake swapping data
    address internal swapper = makeAddr("swapper");
    bytes internal swapData = hex"";

    // Load historical claim data from JSON file
    string internal root = vm.projectRoot();
    string internal path = string.concat(root, "/test/data/historical_merkl_claim.json");

    // Merkl claim data
    IERC4626Adapter.MerklParams internal merklParams;
    address[] internal users;
    address[] internal tokens;
    uint256[] internal amounts;
    bytes32[][] internal proofs;

    // Adapter claim data
    IERC4626Adapter.ClaimParams internal claimParams;

    function setUp() public virtual override {
        super.setUp();

        vault.deposit(initialDeposit, address(this));

        vm.prank(allocator);
        vault.allocate(address(erc4626Adapter), hex"", initialDeposit);
    }

    /// @notice Test with real historical Merkl transaction data
    /// @dev This test uses actual transaction data from block 23189636 loaded from JSON
    function testHistoricalMerklTransaction() public {
        _loadHistoricalMerklTransaction(path);

        // Encode claim data
        merklParams = IERC4626Adapter.MerklParams({users: users, tokens: tokens, amounts: amounts, proofs: proofs});
        claimParams = IERC4626Adapter.ClaimParams({
            merklDistributor: merklDistributor,
            merklParams: merklParams,
            swapper: swapper,
            swapData: swapData
        });
        bytes memory claimData = abi.encode(claimParams);

        // etch adapter logic to user --> gives the adapter the ability to claim
        vm.etch(users[0], address(erc4626Adapter).code);

        // Set claimer role in etched adapter
        vm.prank(curator);
        IERC4626Adapter(users[0]).setClaimer(rewardClaimer);

        // Record initial state
        uint256 initialUserBalance = IERC20(tokens[0]).balanceOf(users[0]);

        // Claim Merkl rewards
        vm.prank(rewardClaimer);
        IERC4626Adapter(users[0]).claim(claimData);
        uint256 finalUserBalance = IERC20(tokens[0]).balanceOf(users[0]);
        assertEq(finalUserBalance - initialUserBalance, amounts[0], "User should receive historical claim amount");
    }

    function _loadHistoricalMerklTransaction(string memory _path) internal {
        string memory json = vm.readFile(_path);

        // Parse users array - use the hardcoded working values from JSON
        users = new address[](1);
        users[0] = stdJson.readAddress(json, ".claimData.users[0]");

        // Parse tokens array
        tokens = new address[](1);
        tokens[0] = stdJson.readAddress(json, ".claimData.tokens[0]");

        // Parse amounts array - parse as uint256 directly
        amounts = new uint256[](1);
        amounts[0] = stdJson.readUint(json, ".claimData.amounts[0]");

        // Parse proofs array - manually extract the proof elements
        proofs = new bytes32[][](1);
        proofs[0] = stdJson.readBytes32Array(json, ".claimData.proofs[0]");
    }
}
