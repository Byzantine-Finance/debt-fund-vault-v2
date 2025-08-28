// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ICompoundV3AdapterFactory} from "../../../src/adapters/interfaces/ICompoundV3AdapterFactory.sol";
import {IVaultV2Factory} from "../../../src/interfaces/IVaultV2Factory.sol";
import {IVaultV2} from "../../../src/interfaces/IVaultV2.sol";
import {ICompoundV3Adapter} from "../../../src/adapters/interfaces/ICompoundV3Adapter.sol";

/**
 * @notice Script used for the deployment of a VaultV2 and its Adapters on Base
 * forge script script/deploy/base/Deploy_Base_VaultV2.s.sol --rpc-url $BASE_RPC_URL --private-key $PRIVATE_KEY
 * --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vv
 *
 */
contract Deploy_Base_VaultV2 is Script, Test {
    // Token Addresses on Base Mainnet
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    // Contract Addresses on Base Mainnet
    address constant COMET = 0xb125E6687d4313864e53df431d5425969c15Eb2F;
    address constant COMET_REWARDS = 0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;

    // Contracts
    IVaultV2Factory public vaultV2Factory;
    ICompoundV3AdapterFactory public compoundV3AdapterFactory;
    IVaultV2 public vault;
    ICompoundV3Adapter public compoundV3Adapter;

    // Load addresses from file
    string internal root = vm.projectRoot();
    string internal path = string.concat(root, "/script/deploy/base/Addresses_Base.json");

    // Deploy variables
    address public vaultOwner = 0x89523c33416c256a3c27Dc46CfD5ac939ADE2951;

    function run() external {
        // Load factory addresses
        _loadFactoryAddresses(path);

        // START RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.startBroadcast();

        emit log_named_address("Deployer Address", msg.sender);

        _deployFromScratch();

        // STOP RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.stopBroadcast();

        _logAndOutputContractAddresses("./script/deploy/base/Addresses_Base_VaultV2.json");
    }

    function _deployFromScratch() internal {
        // Deploy Vault
        bytes32 salt = bytes32(block.timestamp);
        vault = IVaultV2(vaultV2Factory.createVaultV2(vaultOwner, USDC, salt));

        // Deploy Compound Adapter
        compoundV3Adapter =
            ICompoundV3Adapter(compoundV3AdapterFactory.createCompoundV3Adapter(address(vault), COMET, COMET_REWARDS));
    }

    function _loadFactoryAddresses(string memory loadPath) internal {
        string memory json = vm.readFile(loadPath);

        vaultV2Factory = IVaultV2Factory(stdJson.readAddress(json, ".addresses.vaultV2Factory"));
        compoundV3AdapterFactory =
            ICompoundV3AdapterFactory(stdJson.readAddress(json, ".addresses.compoundV3AdapterFactory"));
    }

    function _logAndOutputContractAddresses(string memory outputPath) internal {
        // WRITE JSON DATA
        string memory parent_object = "parent object";
        string memory deployed_addresses = "addresses";
        string memory chain_info = "chainInfo";

        vm.serializeAddress(deployed_addresses, "vault", address(vault));
        string memory deployed_addresses_output =
            vm.serializeAddress(deployed_addresses, "compoundV3Adapter", address(compoundV3Adapter));

        vm.serializeUint(chain_info, "deploymentBlock", block.number);
        string memory chain_info_output = vm.serializeUint(chain_info, "chainId", block.chainid);

        // serialize all the data
        vm.serializeString(parent_object, deployed_addresses, deployed_addresses_output);
        string memory finalJson = vm.serializeString(parent_object, chain_info, chain_info_output);

        vm.writeJson(finalJson, outputPath);
    }
}
