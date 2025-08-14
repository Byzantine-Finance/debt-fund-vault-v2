// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity ^0.8.0;

import {IERC20} from "../interfaces/IERC20.sol";
import {ErrorsLib} from "./ErrorsLib.sol";

library SafeERC20Lib {
    function safeTransfer(address token, address to, uint256 value) internal {
        if (token.code.length == 0) revert ErrorsLib.NoCode();

        (bool success, bytes memory returndata) = token.call(abi.encodeCall(IERC20.transfer, (to, value)));
        if (!success) revert ErrorsLib.TransferReverted();
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) revert ErrorsLib.TransferReturnedFalse();
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        if (token.code.length == 0) revert ErrorsLib.NoCode();

        (bool success, bytes memory returndata) = token.call(abi.encodeCall(IERC20.transferFrom, (from, to, value)));
        if (!success) revert ErrorsLib.TransferFromReverted();
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) revert ErrorsLib.TransferFromReturnedFalse();
    }

    function safeApprove(address token, address spender, uint256 value) internal {
        if (token.code.length == 0) revert ErrorsLib.NoCode();

        (bool success, bytes memory returndata) = token.call(abi.encodeCall(IERC20.approve, (spender, value)));
        if (!success) revert ErrorsLib.ApproveReverted();
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) revert ErrorsLib.ApproveReturnedFalse();
    }
}
