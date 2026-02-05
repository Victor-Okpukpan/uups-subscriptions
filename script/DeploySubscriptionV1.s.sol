// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {SubscriptionV1} from "../src/SubscriptionV1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @title DeploySubscriptionV1
 * @author Victor_TheOracle (@victorokpukpan_)
 * @notice This script deploys the SubscriptionV1 contract using the UUPS proxy pattern.
 * @dev It initializes the proxy with the owner, USDC token address, and treasury address.
 */
contract DeploySubscriptionV1 is Script {
    function run() external returns (address, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (address usdc, address treasury,, address deployer) = config.activeNetworkConfig();

        vm.startBroadcast();
        SubscriptionV1 implementation = new SubscriptionV1();
        bytes memory data = abi.encodeWithSelector(SubscriptionV1.initialize.selector, deployer, usdc, treasury);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        vm.stopBroadcast();
        return (address(proxy), config);
    }
}
