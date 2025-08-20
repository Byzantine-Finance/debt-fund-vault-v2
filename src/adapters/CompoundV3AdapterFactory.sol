// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {CompoundV3Adapter} from "./CompoundV3Adapter.sol";
import {ICompoundV3AdapterFactory} from "./interfaces/ICompoundV3AdapterFactory.sol";

contract CompoundV3AdapterFactory is ICompoundV3AdapterFactory {
    /* STORAGE */

    mapping(address => mapping(address => address)) public compoundV3Adapter;
    mapping(address => bool) public isCompoundV3Adapter;

    /* FUNCTIONS */

    /// @dev Returns the address of the deployed CompoundV3Adapter.
    function createCompoundV3Adapter(address parentVault, address comet, address cometRewards)
        external
        returns (address)
    {
        address _compoundV3Adapter = address(new CompoundV3Adapter{salt: bytes32(0)}(parentVault, comet, cometRewards));
        compoundV3Adapter[parentVault][comet] = _compoundV3Adapter;
        isCompoundV3Adapter[_compoundV3Adapter] = true;
        emit CreateCompoundV3Adapter(parentVault, comet, cometRewards, _compoundV3Adapter);
        return _compoundV3Adapter;
    }
}
