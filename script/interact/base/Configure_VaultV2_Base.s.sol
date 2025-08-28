// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {IVaultV2} from "../../../src/interfaces/IVaultV2.sol";
import {ICompoundV3Adapter} from "../../../src/adapters/interfaces/ICompoundV3Adapter.sol";
import "../../../src/libraries/ConstantsLib.sol";

/**
 * @notice Script used for the configuration of a VaultV2 and its Adapters on Base
 * forge script script/interact/base/Configure_VaultV2_Base.s.sol --rpc-url $BASE_RPC_URL --private-key $PRIVATE_KEY
 * --broadcast -vv
 *
 */
contract Configure_VaultV2_Base is Script {
    // Contracts
    IVaultV2 public vault;
    ICompoundV3Adapter public compoundV3Adapter;

    // Data for Vault setup
    uint256 public maxRate = MAX_MAX_RATE;
    uint256 public absoluteCap = type(uint128).max;
    uint256 public relativeCap = WAD;

    // Private key (assuming the owner and the curator are the same)
    uint256 public privateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

    // Vault variables
    address public vaultOwner = 0x89523c33416c256a3c27Dc46CfD5ac939ADE2951;
    address public curator = 0x89523c33416c256a3c27Dc46CfD5ac939ADE2951;
    address public sentinel = 0x89523c33416c256a3c27Dc46CfD5ac939ADE2951;
    address public allocator = 0x89523c33416c256a3c27Dc46CfD5ac939ADE2951;
    address public claimer = 0x89523c33416c256a3c27Dc46CfD5ac939ADE2951;

    // Internal variables
    bytes32 internal expectedAdapterId;
    bytes internal expectedAdapterIdData;

    // Load addresses from file
    string internal root = vm.projectRoot();
    string internal path = string.concat(root, "/script/deploy/base/Addresses_Base_VaultV2.json");

    function run() public {
        // Load deployed addresses
        _loadAddresses(path);

        // START RECORDING TRANSACTIONS FOR INTERACTION
        vm.startBroadcast(privateKey);

        _setupByOwner();
        _setupByCurator();

        // STOP RECORDING TRANSACTIONS FOR INTERACTION
        vm.stopBroadcast();
    }

    function _setupByOwner() internal {
        vault.setCurator(curator);
        vault.setIsSentinel(sentinel, true);
    }

    function _setupByCurator() internal {
        expectedAdapterIdData = abi.encode("this", address(compoundV3Adapter));
        expectedAdapterId = keccak256(expectedAdapterIdData);

        vault.submit(abi.encodeCall(IVaultV2.setIsAllocator, (allocator, true)));
        vault.setIsAllocator(allocator, true);

        vault.submit(abi.encodeCall(IVaultV2.setIsAdapter, (address(compoundV3Adapter), true)));
        vault.setIsAdapter(address(compoundV3Adapter), true);

        vault.submit(abi.encodeCall(IVaultV2.setMaxRate, (maxRate)));
        vault.setMaxRate(maxRate);

        vault.submit(abi.encodeCall(IVaultV2.increaseAbsoluteCap, (expectedAdapterIdData, absoluteCap)));
        vault.increaseAbsoluteCap(expectedAdapterIdData, absoluteCap);

        vault.submit(abi.encodeCall(IVaultV2.increaseRelativeCap, (expectedAdapterIdData, relativeCap)));
        vault.increaseRelativeCap(expectedAdapterIdData, relativeCap);

        compoundV3Adapter.setClaimer(claimer);
    }

    // Load deployed addresses
    function _loadAddresses(string memory loadPath) internal {
        string memory json = vm.readFile(loadPath);

        vault = IVaultV2(stdJson.readAddress(json, ".addresses.vault"));
        compoundV3Adapter = ICompoundV3Adapter(stdJson.readAddress(json, ".addresses.compoundV3Adapter"));
    }
}
