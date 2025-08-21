// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity 0.8.28;

import {ERC4626Adapter} from "./ERC4626Adapter.sol";
import {IERC4626AdapterFactory} from "./interfaces/IERC4626AdapterFactory.sol";

contract ERC4626AdapterFactory is IERC4626AdapterFactory {
    /* STORAGE */

    mapping(address parentVault => mapping(address erc4626Vault => address)) public erc4626Adapter;
    mapping(address account => bool) public isERC4626Adapter;

    /* FUNCTIONS */

    /// @dev Returns the address of the deployed ERC4626Adapter.
    function createERC4626Adapter(address parentVault, address erc4626Vault) external returns (address) {
        address _erc4626Adapter = address(new ERC4626Adapter{salt: bytes32(0)}(parentVault, erc4626Vault));
        erc4626Adapter[parentVault][erc4626Vault] = _erc4626Adapter;
        isERC4626Adapter[_erc4626Adapter] = true;
        emit CreateERC4626Adapter(parentVault, erc4626Vault, _erc4626Adapter);
        return _erc4626Adapter;
    }
}
