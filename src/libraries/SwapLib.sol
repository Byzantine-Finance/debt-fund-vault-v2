// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20Lib} from "./SafeERC20Lib.sol";
import {ILifiMinimal} from "../interfaces/ILifiMinimal.sol";

library SwapLib {
    /**
     * @dev Swaps an ERC20 for another ERC20.
     * @param _lifiDiamond The LiFi Diamond contract.
     * @param _transactionId The transaction ID.
     * @param _integrator The integrator.
     * @param _referrer The referrer.
     * @param _receiver The receiver.
     * @param _minAmountOut The minimum amount of the final asset to receive.
     * @param _swapData The swap data.
     */
    function swap(
        ILifiMinimal _lifiDiamond,
        bytes32 _transactionId,
        string memory _integrator,
        string memory _referrer,
        address payable _receiver,
        uint256 _minAmountOut,
        ILifiMinimal.SwapData memory _swapData
    ) internal {
        // Approve the LiFiDiamond contract to spend the tokens
        SafeERC20Lib.safeApprove(_swapData.sendingAssetId, address(_lifiDiamond), _swapData.fromAmount);

        // Call the swapTokensSingleV3ERC20ToERC20 function on the LiFi Diamond contract
        _lifiDiamond.swapTokensSingleV3ERC20ToERC20(
            _transactionId, _integrator, _referrer, _receiver, _minAmountOut, _swapData
        );
    }
}
