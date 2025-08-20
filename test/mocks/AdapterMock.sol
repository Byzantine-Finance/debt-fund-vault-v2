// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity ^0.8.0;

import {IAdapter} from "../../src/interfaces/IAdapter.sol";
import {IVaultV2} from "../../src/interfaces/IVaultV2.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";
import {SafeERC20Lib} from "../../src/libraries/SafeERC20Lib.sol";
import {SwapLib} from "../../src/libraries/SwapLib.sol";
import {ILifiMinimal} from "../../src/interfaces/ILifiMinimal.sol";

contract AdapterMock is IAdapter {
    using MathLib for uint256;

    address public immutable vault;
    // USDC address on mainnet
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    bytes32[] public _ids;
    uint256 public interest;
    uint256 public loss;
    uint256 public deposit;

    bytes public recordedAllocateData;
    uint256 public recordedAllocateAssets;
    bytes public recordedDeallocateData;
    uint256 public recordedDeallocateAssets;
    bytes4 public recordedSelector;
    address public recordedSender;

    ILifiMinimal public lifiDiamond;

    struct ClaimRewardsInputs {
        address token;
        uint256 rewardsAmount;
        uint256 minAmountOut;
        ILifiMinimal.SwapData swapData;
        string integrator;
        string referrer;
    }

    constructor(address _vault) {
        vault = _vault;
        if (_vault != address(0)) {
            IERC20(IVaultV2(_vault).asset()).approve(_vault, type(uint256).max);
        }

        _ids.push(keccak256("id-0"));
        _ids.push(keccak256("id-1"));
    }

    function setInterest(uint256 _interest) external {
        interest = _interest;
    }

    function setLoss(uint256 _loss) external {
        loss = _loss;
    }

    function allocate(bytes memory data, uint256 assets, bytes4 selector, address sender)
        external
        returns (bytes32[] memory, int256)
    {
        recordedAllocateData = data;
        recordedAllocateAssets = assets;
        recordedSelector = selector;
        recordedSender = sender;
        deposit += assets;
        return (_ids, int256(assets) + int256(interest) - int256(loss));
    }

    function deallocate(bytes memory data, uint256 assets, bytes4 selector, address sender)
        external
        returns (bytes32[] memory, int256)
    {
        recordedDeallocateData = data;
        recordedDeallocateAssets = assets;
        recordedSelector = selector;
        recordedSender = sender;
        deposit -= assets;
        return (_ids, -int256(assets) + int256(interest) - int256(loss));
    }

    function realAssets() external view returns (uint256) {
        return deposit + interest - loss;
    }

    /// Set the LiFiDiamond address
    function setLifiDiamond(address _lifiDiamond) external {
        lifiDiamond = ILifiMinimal(_lifiDiamond);
    }

    /// @dev for testing purposes, we transfer the ERC20 tokens from the caller to the adapter to simulate the claim
    function claimRewards(ClaimRewardsInputs calldata _inputs) external {
        // Verify that the receiving asset is USDC
        address receivingAsset = _inputs.swapData.receivingAssetId;
        if (receivingAsset != USDC) revert InvalidReceivingAsset(receivingAsset);

        // Fake the claim by transferring the tokens to the adapter
        SafeERC20Lib.safeTransferFrom(_inputs.token, msg.sender, address(this), _inputs.rewardsAmount);

        // Call the swap function on the SwapLib contract
        // 1. Send the tokens to the LiFiDiamond
        // 2. Call underlying Dex swap function to swap the tokens to USDC
        // 3. Send the USDC to the vault
        SwapLib.swap(
            lifiDiamond,
            "",
            _inputs.integrator,
            _inputs.referrer,
            payable(vault),
            _inputs.minAmountOut,
            _inputs.swapData
        );
    }

    // Errors
    error InvalidReceivingAsset(address _receivingAssetId);
}
