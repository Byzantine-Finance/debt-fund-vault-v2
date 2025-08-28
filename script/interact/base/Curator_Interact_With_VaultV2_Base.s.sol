// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {IVaultV2} from "../../../src/interfaces/IVaultV2.sol";
import {ICompoundV3Adapter} from "../../../src/adapters/interfaces/ICompoundV3Adapter.sol";

/**
 * @notice Script used for the interaction of a Curator with a VaultV2 on Base
 *
 * To interact:
 * forge script script/interact/base/Curator_Interact_With_VaultV2_Base.s.sol \
 * --sig "allocate(address,bytes,uint256)" \
 * --rpc-url $BASE_RPC_URL \
 * --private-key $PRIVATE_KEY \
 * --broadcast \
 * -- <adapterAddress> <data> <amount> \
 * -vv
 */
contract Curator_Interact_With_VaultV2_Base is Script {
    // Fetch Allocator private key
    uint256 public privateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

    function allocate(address adapterAddress, bytes memory data, uint256 amount) public {
        IVaultV2 vault = IVaultV2(ICompoundV3Adapter(adapterAddress).parentVault());

        // START RECORDING TRANSACTIONS FOR INTERACTION
        vm.startBroadcast(privateKey);

        vault.allocate(adapterAddress, data, amount);

        // STOP RECORDING TRANSACTIONS FOR INTERACTION
        vm.stopBroadcast();
    }
}
