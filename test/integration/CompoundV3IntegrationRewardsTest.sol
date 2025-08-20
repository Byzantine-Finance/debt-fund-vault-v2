// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CompoundV3IntegrationTest.sol";

contract CompoundV3IntegrationRewardsTest is CompoundV3IntegrationTest {
    address immutable claimer = makeAddr("claimer");
    uint256 internal initialDeposit = 1e12;

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
    function testClaimRewards(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, 365 days);

        CometRewardsInterface.RewardOwed memory rewardOwed =
            cometRewards.getRewardOwed(address(comet), address(compoundAdapter));
        address rewardToken = rewardOwed.token;
        uint256 rewardsBefore = rewardOwed.owed;

        skip(elapsed);

        uint256 rewardsAfter = cometRewards.getRewardOwed(address(comet), address(compoundAdapter)).owed;

        vm.expectEmit();
        emit ICompoundV3Adapter.Claim(rewardToken, rewardsAfter - rewardsBefore);

        vm.prank(claimer);
        compoundAdapter.claim();

        assertEq(cometRewards.rewardsClaimed(address(comet), address(compoundAdapter)), rewardsAfter - rewardsBefore);
        assertEq(IERC20(rewardToken).balanceOf(address(compoundAdapter)), rewardsAfter - rewardsBefore);
        assertEq(cometRewards.getRewardOwed(address(comet), address(compoundAdapter)).owed, 0);
    }
}
