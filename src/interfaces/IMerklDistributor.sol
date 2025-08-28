// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

/// @notice Interface for Merkl distributor contract
interface IMerklDistributor {
    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;
}
