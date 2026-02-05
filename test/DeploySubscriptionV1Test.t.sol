// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeploySubscriptionV1} from "../script/DeploySubscriptionV1.s.sol";
import {SubscriptionV1} from "../src/SubscriptionV1.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeploySubscriptionV1Test is Test {
    DeploySubscriptionV1 deployer;
    SubscriptionV1 proxy;
    HelperConfig config;

    address usdc;
    address treasury;
    address owner;

    function setUp() public {
        deployer = new DeploySubscriptionV1();
        (address _proxyAddress, HelperConfig _config) = deployer.run();
        
        proxy = SubscriptionV1(_proxyAddress);
        config = _config;

        (usdc, treasury, , owner) = config.activeNetworkConfig();
    }

    function test_ProxyIsInitializedWithCorrectConfig() public view {
        assertEq(proxy.s_usdc(), usdc);
        assertEq(proxy.s_treasury(), treasury);
        assertEq(proxy.owner(), owner);
    }

    function test_NextPlanIdIsOne() public view {
        assertEq(proxy.s_nextPlanId(), 1);
    }

    function test_ImplementationCannotBeInitializedDirectly() public {
        bytes32 implSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        address implementation = address(uint160(uint256(vm.load(address(proxy), implSlot))));

        vm.expectRevert(); // Should fail because of _disableInitializers()
        SubscriptionV1(implementation).initialize(address(0x1), address(0x2), address(0x3));
    }
}