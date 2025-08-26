// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >= 0.5.0;

import {IAdapter} from "../../interfaces/IAdapter.sol";

interface IERC4626Adapter is IAdapter {
    /* STRUCTS */

    struct MerklParams {
        address[] users;
        address[] tokens;
        uint256[] amounts;
        bytes32[][] proofs;
    }

    /* EVENTS */

    event SetSkimRecipient(address indexed newSkimRecipient);
    event SetClaimer(address indexed newClaimer);
    event SetMerklDistributor(address indexed newMerklDistributor);
    event Skim(address indexed token, uint256 assets);
    event ClaimRewards(address[] indexed users, address[] indexed tokens, uint256[] amounts);

    /* ERRORS */

    error AssetMismatch();
    error CannotSkimERC4626Shares();
    error InvalidData();
    error MerklDistributorNotSet();
    error NotAuthorized();

    /* FUNCTIONS */

    function factory() external view returns (address);
    function parentVault() external view returns (address);
    function erc4626Vault() external view returns (address);
    function merklDistributor() external view returns (address);
    function adapterId() external view returns (bytes32);
    function skimRecipient() external view returns (address);
    function claimer() external view returns (address);
    function allocation() external view returns (uint256);
    function ids() external view returns (bytes32[] memory);
    function setSkimRecipient(address newSkimRecipient) external;
    function setClaimer(address newClaimer) external;
    function setMerklDistributor(address newMerklDistributor) external;
    function skim(address token) external;
    function claim(bytes calldata data) external;
}
