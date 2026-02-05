// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {SubscriptionV1} from "../src/SubscriptionV1.sol";
import {SubscriptionV2} from "../src/SubscriptionV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

/**
 * @title UpgradeSubscriptionV1
 * @author Victor_TheOracle (@victorokpukpan_)
 * @notice This script upgrades the deployed SubscriptionV1 contract to SubscriptionV2.
 * @dev Deploys the SubscriptionV2 implementation and upgrades the proxy to use the new implementation.
 */
contract UpgradeSubscriptionV1 is Script {
    // UpgradeSubscriptionV1.s.sol
    function run() external returns (address) {
        address mostRecentDeployment = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);
        return upgrade(mostRecentDeployment);
    }

    function upgrade(address proxyAddress) public returns (address) {
        HelperConfig config = new HelperConfig();
        (,, address ethUsdcPriceFeed, address deployer) = config.activeNetworkConfig();

        vm.startBroadcast(deployer);
        SubscriptionV2 newImplementation = new SubscriptionV2();
        bytes memory data = abi.encodeWithSelector(SubscriptionV2.initializeV2.selector, ethUsdcPriceFeed);
        SubscriptionV1(proxyAddress).upgradeToAndCall(address(newImplementation), data);
        vm.stopBroadcast();
        return proxyAddress;
    }
}
