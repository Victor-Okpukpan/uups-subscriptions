// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeploySubscriptionV1} from "../script/DeploySubscriptionV1.s.sol";
import {UpgradeSubscriptionV1} from "../script/UpgradeSubscriptionV1.s.sol";
import {SubscriptionV1} from "../src/SubscriptionV1.sol";
import {SubscriptionV2} from "../src/SubscriptionV2.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract UpgradeSubscriptionTest is Test {
    DeploySubscriptionV1 deployer;
    UpgradeSubscriptionV1 upgrader;
    
    address public proxyAddress;
    address owner;
    HelperConfig config;

    function setUp() public {
        deployer = new DeploySubscriptionV1();
        upgrader = new UpgradeSubscriptionV1();
        
        (address _proxy, HelperConfig _config) = deployer.run();
        proxyAddress = _proxy;
        config = _config;

        (,,, owner) = config.activeNetworkConfig();
    }

    function test_UpgradeViaScriptWorks() public {
        address upgradedProxy = upgrader.upgrade(proxyAddress);
        assertEq(upgradedProxy, proxyAddress, "Proxy address should not change");

        SubscriptionV2 v2Proxy = SubscriptionV2(upgradedProxy);
        assertTrue(v2Proxy.s_ethUsdPriceFeed() != address(0), "V2 initialization failed");
    }

    function test_StatePreservationAfterUpgrade() public {
        SubscriptionV1 v1 = SubscriptionV1(proxyAddress);

        vm.startPrank(owner);
        uint256 planId = v1.createPlan(100);
        vm.stopPrank();

        upgrader.upgrade(proxyAddress);

        SubscriptionV2 v2 = SubscriptionV2(proxyAddress);
        (uint256 price, bool active) = v2.s_plans(planId);
        
        assertEq(price, 100, "Storage slot corruption: Price mismatch");
        assertTrue(active, "Storage slot corruption: Active status lost");
    }
}