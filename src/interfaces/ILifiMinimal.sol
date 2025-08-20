// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev This interface is a minimal version of the LiFi Diamond interface.
 * @dev The interface only contains the functions that are used in the SwapLib library.
 */
interface ILifiMinimal {
    /// @notice Struct containing all necessary data to execute a swap or generic call
    /// @param callTo The address of the contract to call for executing the swap
    /// @param approveTo The address that will receive token approval (can be different than callTo for some DEXs)
    /// @param sendingAssetId The address of the token being sent
    /// @param receivingAssetId The address of the token expected to be received
    /// @param fromAmount The exact amount of the sending asset to be used in the call
    /// @param callData Encoded function call data to be sent to the `callTo` contract
    /// @param requiresDeposit A flag indicating whether the tokens must be deposited (pulled) before the call
    struct SwapData {
        address callTo;
        address approveTo;
        address sendingAssetId;
        address receivingAssetId;
        uint256 fromAmount;
        bytes callData;
        bool requiresDeposit;
    }

    /// @notice Performs a single swap from an ERC20 token to another ERC20 token
    /// @param _transactionId the transaction id associated with the operation
    /// @param _integrator the name of the integrator
    /// @param _referrer the address of the referrer
    /// @param _receiver the address to receive the swapped tokens into (also excess tokens)
    /// @param _minAmountOut the minimum amount of the final asset to receive
    /// @param _swapData an object containing swap related data to perform swaps before bridging
    function swapTokensSingleV3ERC20ToERC20(
        bytes32 _transactionId,
        string calldata _integrator,
        string calldata _referrer,
        address payable _receiver,
        uint256 _minAmountOut,
        SwapData calldata _swapData
    ) external;
}
