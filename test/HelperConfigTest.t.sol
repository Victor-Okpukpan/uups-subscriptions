// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract HelperConfigTest is Test {
    HelperConfig config;

    /// @notice Tests that Anvil config is generated correctly (Chain ID 31337)
    function test_GetOrCreateAnvilConfig() public {
        vm.chainId(31337); 
        config = new HelperConfig();

        (address usdc, address treasury, address priceFeed, address deployer) = config.activeNetworkConfig();

        assertTrue(usdc != address(0), "USDC Mock should be deployed");
        assertTrue(priceFeed != address(0), "PriceFeed Mock should be deployed");
        assertEq(treasury, 0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        assertEq(deployer, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    }

    /// @notice Tests that Base Sepolia config returns hardcoded values (Chain ID 84532)
    function test_GetBaseSepoliaConfig() public {
        vm.chainId(84532);
        config = new HelperConfig();

        (address usdc, address treasury, address priceFeed, ) = config.activeNetworkConfig();

        assertEq(usdc, 0x036CbD53842c5426634e7929541eC2318f3dCF7e);
        assertEq(priceFeed, 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);
        assertEq(treasury, 0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    }

    /// @notice Ensures that multiple calls to Anvil config don't re-deploy mocks (Singleton check)
    function test_AnvilConfigIsSingleton() public {
        vm.chainId(31337);
        config = new HelperConfig();
        
        (address usdcOnCallOne, , ,) = config.activeNetworkConfig();
        
        HelperConfig.NetworkConfig memory secondConfig = config.getOrCreateAnvilConfig();
        
        assertEq(usdcOnCallOne, secondConfig.usdc, "Mocks should only be deployed once");
    }
}