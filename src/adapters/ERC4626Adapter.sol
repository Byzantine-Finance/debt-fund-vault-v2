// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity 0.8.28;

import {IVaultV2} from "../interfaces/IVaultV2.sol";
import {IERC4626} from "../interfaces/IERC4626.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IERC4626Adapter} from "./interfaces/IERC4626Adapter.sol";
import {SafeERC20Lib} from "../libraries/SafeERC20Lib.sol";

/// @notice Merkl claim parameters struct
struct MerklParams {
    address[] users;
    address[] tokens;
    uint256[] amounts;
    bytes32[][] proofs;
}

/// @notice Interface for Merkl distributor contract
interface IMerklDistributor {
    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;
}

/// @dev Generic ERC4626 adapter with Merkl rewards claiming functionality
/// @dev Designed for integration with ERC4626-compliant vaults like Stata (AAVE wrapper)
/// @dev This adapter must be used with ERC4626 vaults that are protected against inflation attacks
/// @dev Must not be used with an ERC4626 vault which can re-enter the parent vault
contract ERC4626Adapter is IERC4626Adapter {
    /* IMMUTABLES */

    address public immutable factory;
    address public immutable parentVault;
    address public immutable erc4626Vault;
    address public immutable merklDistributor;
    bytes32 public immutable adapterId;

    /* STORAGE */

    address public skimRecipient;
    address public claimer;

    /* FUNCTIONS */

    constructor(address _parentVault, address _erc4626Vault, address _merklDistributor) {
        factory = msg.sender;
        parentVault = _parentVault;
        erc4626Vault = _erc4626Vault;
        merklDistributor = _merklDistributor;
        adapterId = keccak256(abi.encode("this", address(this)));
        address asset = IVaultV2(_parentVault).asset();
        require(asset == IERC4626(_erc4626Vault).asset(), AssetMismatch());
        SafeERC20Lib.safeApprove(asset, _parentVault, type(uint256).max);
        SafeERC20Lib.safeApprove(asset, _erc4626Vault, type(uint256).max);
    }

    function setSkimRecipient(address newSkimRecipient) external {
        require(msg.sender == IVaultV2(parentVault).owner(), NotAuthorized());
        skimRecipient = newSkimRecipient;
        emit SetSkimRecipient(newSkimRecipient);
    }

    function setClaimer(address newClaimer) external {
        if (msg.sender != IVaultV2(parentVault).curator()) revert NotAuthorized();
        claimer = newClaimer;
        emit SetClaimer(newClaimer);
    }

    /// @dev Skims the adapter's balance of `token` and sends it to `skimRecipient`.
    /// @dev This is useful to handle rewards that the adapter has earned.
    function skim(address token) external {
        require(msg.sender == skimRecipient, NotAuthorized());
        require(token != erc4626Vault, CannotSkimERC4626Shares());
        uint256 balance = IERC20(token).balanceOf(address(this));
        SafeERC20Lib.safeTransfer(token, skimRecipient, balance);
        emit Skim(token, balance);
    }

    /// @dev Claims rewards from Merkl distributor contract
    /// @dev Only the claimer can call this function
    /// @param data Encoded MerklParams struct containing users, tokens, amounts, and proofs
    function claim(bytes calldata data) external {
        require(msg.sender == claimer, NotAuthorized());
        require(merklDistributor != address(0), MerklDistributorNotSet());

        // Decode the claim data to MerklParams struct
        MerklParams memory params = abi.decode(data, (MerklParams));

        // Call the Merkl distributor
        IMerklDistributor(merklDistributor).claim(params.users, params.tokens, params.amounts, params.proofs);
        
        emit ClaimRewards(params.users, params.tokens, params.amounts);
    }

    /// @dev Does not log anything because the ids (logged in the parent vault) are enough.
    /// @dev Returns the ids of the allocation and the change in allocation.
    function allocate(bytes memory data, uint256 assets, bytes4, address) external returns (bytes32[] memory, int256) {
        require(data.length == 0, InvalidData());
        require(msg.sender == parentVault, NotAuthorized());

        if (assets > 0) IERC4626(erc4626Vault).deposit(assets, address(this));
        uint256 oldAllocation = allocation();
        uint256 newAllocation = IERC4626(erc4626Vault).previewRedeem(IERC4626(erc4626Vault).balanceOf(address(this)));

        // Safe casts because ERC4626 vaults bound the total supply, and allocation is less than the
        // max total assets of the vault.
        return (ids(), int256(newAllocation) - int256(oldAllocation));
    }

    /// @dev Does not log anything because the ids (logged in the parent vault) are enough.
    /// @dev Returns the ids of the deallocation and the change in allocation.
    function deallocate(bytes memory data, uint256 assets, bytes4, address)
        external
        returns (bytes32[] memory, int256)
    {
        require(data.length == 0, InvalidData());
        require(msg.sender == parentVault, NotAuthorized());

        if (assets > 0) IERC4626(erc4626Vault).withdraw(assets, address(this), address(this));
        uint256 oldAllocation = allocation();
        uint256 newAllocation = IERC4626(erc4626Vault).previewRedeem(IERC4626(erc4626Vault).balanceOf(address(this)));

        // Safe casts because ERC4626 vaults bound the total supply, and allocation is less than the
        // max total assets of the vault.
        return (ids(), int256(newAllocation) - int256(oldAllocation));
    }

    /// @dev Returns adapter's ids.
    function ids() public view returns (bytes32[] memory) {
        bytes32[] memory ids_ = new bytes32[](1);
        ids_[0] = adapterId;
        return ids_;
    }

    function allocation() public view returns (uint256) {
        return IVaultV2(parentVault).allocation(adapterId);
    }

    function realAssets() external view returns (uint256) {
        return allocation() != 0
            ? IERC4626(erc4626Vault).previewRedeem(IERC4626(erc4626Vault).balanceOf(address(this)))
            : 0;
    }
}
