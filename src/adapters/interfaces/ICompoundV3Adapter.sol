// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

import {IAdapter} from "../../interfaces/IAdapter.sol";

interface ICompoundV3Adapter is IAdapter {
    /* EVENTS */

    event SetClaimer(address indexed newClaimer);
    event Claim(address indexed token, uint256 amount);
    event SetSkimRecipient(address indexed newSkimRecipient);
    event Skim(address indexed token, uint256 assets);

    /* ERRORS */

    error InvalidData();
    error NotAuthorized();

    /* FUNCTIONS */

    function factory() external view returns (address);
    function parentVault() external view returns (address);
    function asset() external view returns (address);
    function comet() external view returns (address);
    function cometRewards() external view returns (address);
    function adapterId() external view returns (bytes32);
    function claimer() external view returns (address);
    function skimRecipient() external view returns (address);
    function allocation() external view returns (uint256);
    function ids() external view returns (bytes32[] memory);
    function setClaimer(address newClaimer) external;
    function claim() external;
    function setSkimRecipient(address newSkimRecipient) external;
    function skim(address token) external;
}
