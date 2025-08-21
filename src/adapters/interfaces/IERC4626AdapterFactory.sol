// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >=0.5.0;

interface IERC4626AdapterFactory {
    /* EVENTS */

    event CreateERC4626Adapter(
        address indexed parentVault, address indexed erc4626Vault, address indexed erc4626Adapter
    );

    /* FUNCTIONS */

    function erc4626Adapter(address parentVault, address erc4626Vault) external view returns (address);
    function isERC4626Adapter(address account) external view returns (bool);
    function createERC4626Adapter(address parentVault, address erc4626Vault, address merklDistributor)
        external
        returns (address erc4626Adapter);
}
