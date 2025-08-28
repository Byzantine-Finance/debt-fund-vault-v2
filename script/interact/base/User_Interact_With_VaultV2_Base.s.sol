// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {IVaultV2} from "../../../src/interfaces/IVaultV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice Script used for the interaction of a User with a VaultV2 on Base
 *
 * To deposit:
 * forge script script/interact/base/User_Interact_With_VaultV2_Base.s.sol \
 * --sig "deposit(address,uint256,address)" \
 * --rpc-url $BASE_RPC_URL \
 * --private-key $PRIVATE_KEY \
 * --broadcast \
 * -- <vaultAddr> <amount> <onBehalf> \
 * -vv
 */
contract User_Interact_With_VaultV2_Base is Script {
    // Fetch Depositor private key
    uint256 public privateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

    function deposit(address vaultAddr, uint256 amount, address onBehalf) public {
        IVaultV2 vault = IVaultV2(vaultAddr);

        // START RECORDING TRANSACTIONS FOR INTERACTION
        vm.startBroadcast(privateKey);

        IERC20(vault.asset()).approve(address(vault), amount);
        vault.deposit(amount, onBehalf);

        // STOP RECORDING TRANSACTIONS FOR INTERACTION
        vm.stopBroadcast();
    }
}
