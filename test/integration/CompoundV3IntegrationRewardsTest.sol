// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CompoundV3IntegrationTest.sol";
import {stdJson} from "../../lib/forge-std/src/StdJson.sol";

contract CompoundV3IntegrationRewardsTest is CompoundV3IntegrationTest {
    address immutable claimer = makeAddr("claimer");
    uint256 internal initialDeposit = 1e12;

    // Load quote data from JSON file
    string internal root = vm.projectRoot();
    string internal path = string.concat(root, "/test/data/quote_data_from_swapper.json");

    // The transaction data from the quote
    bytes internal transactionData;
    uint256 internal minAmountOut; // only used to assert
    address internal vaultUsedInQuote;

    function setUp() public virtual override {
        super.setUp();

        vault.deposit(initialDeposit, address(this));

        vm.prank(allocator);
        vault.allocate(address(compoundAdapter), hex"", initialDeposit);

        vm.expectEmit();
        emit ICompoundV3Adapter.SetClaimer(claimer);

        vm.prank(curator);
        compoundAdapter.setClaimer(claimer);

        assertApproxEqAbs(vault.allocation(compoundAdapter.adapterId()), initialDeposit, 1 wei);
        assertEq(compoundAdapter.claimer(), claimer);
    }

    /// forge-config: default.isolate = true
    function testClaimRewards() public {
        _loadQuoteData(path);

        // etch the vault address used in the quote
        vm.etch(vaultUsedInQuote, address(vault).code);

        // get the reward token
        address rewardToken = cometRewards.getRewardOwed(address(comet), address(compoundAdapter)).token;

        skip(50 days);

        // get the accumulated rewards
        uint256 owed = cometRewards.getRewardOwed(address(comet), address(compoundAdapter)).owed;

        // vault's USDC balance before the claim
        uint256 vaultUSDCBalanceBefore = IERC20(usdc).balanceOf(vaultUsedInQuote);

        // encode the data to claim the rewards
        bytes memory data = abi.encode(transactionData, LIFI_DIAMOND);

        vm.startPrank(claimer);

        vm.expectEmit();
        emit ICompoundV3Adapter.Claim(rewardToken, owed);

        compoundAdapter.claim(data);
        vm.stopPrank();

        // Verify the vault's USDC balance has the minimum amount out provided in the quote
        assertGe(IERC20(usdc).balanceOf(vaultUsedInQuote) - vaultUSDCBalanceBefore, minAmountOut);

        assertEq(cometRewards.rewardsClaimed(address(comet), address(compoundAdapter)), owed);
        assertEq(IERC20(rewardToken).balanceOf(address(compoundAdapter)), 0);
        assertEq(cometRewards.getRewardOwed(address(comet), address(compoundAdapter)).owed, 0);
    }

    function _loadQuoteData(string memory _path) internal {
        string memory json = vm.readFile(_path);

        // Parse transactionData
        transactionData = stdJson.readBytes(json, ".transactionData");

        // Parse minAmountOut
        minAmountOut = stdJson.readUint(json, ".minAmountOut");

        // Parse vaultUsedInQuote
        vaultUsedInQuote = stdJson.readAddress(json, ".vaultUsedInQuote");
    }
}
