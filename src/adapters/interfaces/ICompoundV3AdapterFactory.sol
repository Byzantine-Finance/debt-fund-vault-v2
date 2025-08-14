// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface ICompoundV3AdapterFactory {
    /* EVENTS */

    event CreateCompoundV3Adapter(
        address indexed parentVault, address indexed comet, address indexed compoundV3Adapter
    );

    /* FUNCTIONS */

    function compoundV3Adapter(address parentVault, address comet) external view returns (address);
    function isCompoundV3Adapter(address account) external view returns (bool);
    function createCompoundV3Adapter(address parentVault, address comet) external returns (address compoundV3Adapter);
}
