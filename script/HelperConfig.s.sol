// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

/**
 * @title HelperConfig
 * @author Victor_TheOracle (@victorokpukpan_)
 * @notice Provides network-specific configurations for testing and deployment.
 * @dev Supports Sepolia and Anvil networks, and deploys mock contracts for USDC and Chainlink price feeds on Anvil.
 */
contract HelperConfig is Script {
    struct NetworkConfig {
        address usdc;
        address treasury;
        address ethUsdPriceFeed;
        address deployer;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 3000e8;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 84532) {
            activeNetworkConfig = getBaseSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getBaseSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            usdc: 0x036CbD53842c5426634e7929541eC2318f3dCF7e,
            treasury: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            ethUsdPriceFeed: 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1,
            deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 //temporary
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.usdc != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockUSDC mockUsdc = new MockUSDC();
        MockV3Aggregator ethUsdMock = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        vm.stopBroadcast();

        return NetworkConfig({
            usdc: address(mockUsdc),
            treasury: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            ethUsdPriceFeed: address(ethUsdMock),
            deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });
    }
}