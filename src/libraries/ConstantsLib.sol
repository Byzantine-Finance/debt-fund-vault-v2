// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity ^0.8.0;

uint256 constant WAD = 1e18;
bytes32 constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
bytes32 constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
uint256 constant MAX_MAX_RATE = 200e16 / uint256(365 days); // 200% APR
uint256 constant TIMELOCK_CAP = 3 weeks;
uint256 constant MAX_PERFORMANCE_FEE = 0.5e18; // 50%
uint256 constant MAX_MANAGEMENT_FEE = 0.05e18 / uint256(365 days); // 5%
uint256 constant MAX_FORCE_DEALLOCATE_PENALTY = 0.02e18; // 2%
address constant LIFI_DIAMOND = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
string constant INTEGRATOR = "byzantine";
