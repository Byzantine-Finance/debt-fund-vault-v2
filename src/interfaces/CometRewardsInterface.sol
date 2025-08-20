// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/**
 * @title Compound's Comet Rewards Interface
 * @notice A contract to claim Compound rewards / incentives
 * @author Byzantine Finance
 */
interface CometRewardsInterface {
    struct RewardConfig {
        address token;
        uint64 rescaleFactor;
        bool shouldUpscale;
        // Note: We define new variables after existing variables to keep interface backwards-compatible
        uint256 multiplier;
    }

    struct RewardOwed {
        address token;
        uint256 owed;
    }

    function rewardConfigs(address comet) external view returns (RewardConfig memory);
    function getRewardOwed(address comet, address account) external returns (RewardOwed memory);
    function rewardsClaimed(address comet, address account) external view returns (uint256);
    function claim(address comet, address src, bool shouldAccrue) external;
    function claimTo(address comet, address src, address to, bool shouldAccrue) external;
}
