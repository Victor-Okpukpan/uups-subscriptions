// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {SubscriptionV2} from "../src/SubscriptionV2.sol";
import {SubscriptionV1} from "../src/SubscriptionV1.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {DeploySubscriptionV1} from "../script/DeploySubscriptionV1.s.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SubscriptionV2Test is Test {
    SubscriptionV2 proxy;
    DeploySubscriptionV1 deployer;
    HelperConfig config;

    address owner;
    address usdc;
    address treasury;
    address user = makeAddr("user");
    address ethusdpricefeed;

    uint256 constant BILLING_PERIOD = 30 days;

    function setUp() public {
        deployer = new DeploySubscriptionV1();
        (address _proxyAddress, HelperConfig _config) = deployer.run();
        proxy = SubscriptionV2(_proxyAddress);
        config = _config;

        (usdc, treasury, ethusdpricefeed, owner) = config.activeNetworkConfig();

        vm.startPrank(owner);
        SubscriptionV2 newImplementation = new SubscriptionV2();
        bytes memory data = abi.encodeWithSelector(SubscriptionV2.initializeV2.selector, ethusdpricefeed);
        proxy.upgradeToAndCall(address(newImplementation), data);
        vm.stopPrank();

        deal(usdc, user, 500 * 1e6);
    }

    function test_initializeV2SetsPriceFeed() public {
        assertEq(proxy.s_ethUsdPriceFeed(), ethusdpricefeed);
    }

    function test_SubscribeWithEthRevertsForNonExistentPlan() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        vm.expectRevert(SubscriptionV1.Subscription__PlanDoesNotExist.selector);
        proxy.subscribeWithEth{value: 1 ether}(999);
        vm.stopPrank();
    }

    function test_SubscribeWithEthRevertsForInsufficientEth() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.deal(user, 0.01 ether);
        vm.startPrank(user);
        vm.expectRevert(SubscriptionV2.Subscription__NotEnoughEth.selector);
        proxy.subscribeWithEth{value: 0.01 ether}(planId);
        vm.stopPrank();
    }

    function test_SubscribeWithEthWorks() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.deal(user, 1 ether);
        vm.startPrank(user);
        proxy.subscribeWithEth{value: 1 ether}(planId);
        vm.stopPrank();

        SubscriptionV1.Subscription memory subscription = proxy.getSubscription(user);
        assertEq(subscription.planId, planId);
        assertEq(subscription.active, true);
        assert(subscription.nextPaymentDue > block.timestamp);
    }

    function test_RenewSubscriptionWithEthRevertsForNonEthSubscriber() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        IERC20(usdc).approve(address(proxy), type(uint256).max);
        proxy.subscribe(planId);

        skip(BILLING_PERIOD + 1);
        MockV3Aggregator(proxy.s_ethUsdPriceFeed()).updateAnswer(3000e8);

        vm.expectRevert(SubscriptionV2.Subscription__NotEthSubscriber.selector);
        proxy.renewSubscriptionWithEth{value: 1 ether}();
        vm.stopPrank();
    }

    function test_RenewSubscriptionWithEthWorks() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.deal(user, 2 ether);
        vm.startPrank(user);
        proxy.subscribeWithEth{value: 1 ether}(planId);
        skip(BILLING_PERIOD + 1);
        address priceFeed = proxy.s_ethUsdPriceFeed();
        MockV3Aggregator(priceFeed).updateAnswer(3000e8);
        proxy.renewSubscriptionWithEth{value: 1 ether}();
        vm.stopPrank();

        SubscriptionV1.Subscription memory subscription = proxy.getSubscription(user);
        assert(subscription.nextPaymentDue > block.timestamp);
    }

    function test_CancelSubscriptionResetsEthFlag() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.deal(user, 1 ether);
        vm.startPrank(user);
        proxy.subscribeWithEth{value: 1 ether}(planId);
        proxy.cancelSubscription();
        vm.stopPrank();

        SubscriptionV1.Subscription memory subscription = proxy.getSubscription(user);
        assertEq(subscription.active, false);
        assertEq(proxy.s_isEth(user), false);
    }

    function test_RevertIfEthPriceIsNegative() public {
        vm.prank(owner);
        uint256 planId = proxy.createPlan(50);

        MockV3Aggregator(proxy.s_ethUsdPriceFeed()).updateAnswer(-1);

        vm.deal(user, 1 ether);
        vm.startPrank(user);
        vm.expectRevert(SubscriptionV2.Subscription__InvalidPrice.selector);
        proxy.subscribeWithEth{value: 1 ether}(planId);
        vm.stopPrank();
    }

    function test_RevertIfAlreadySubscribed() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.deal(user, 2 ether);
        vm.startPrank(user);
        proxy.subscribeWithEth{value: 1 ether}(planId);
        vm.expectRevert(SubscriptionV1.Subscription__AlreadySubscribed.selector);
        proxy.subscribeWithEth{value: 1 ether}(planId);
        vm.stopPrank();
    }

    function test_RevertIfNotYetExpired() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.deal(user, 2 ether);
        vm.startPrank(user);
        proxy.subscribeWithEth{value: 1 ether}(planId);
        vm.expectRevert(SubscriptionV1.Subscription__NotYetExpired.selector);
        proxy.renewSubscriptionWithEth{value: 1 ether}();
        vm.stopPrank();
    }

    function test_RevertIfNotSubscribedToAnyPlan() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        vm.expectRevert(SubscriptionV1.Subscription__NotSubscribedToAnyPlan.selector);
        proxy.renewSubscriptionWithEth{value: 1 ether}();
        vm.stopPrank();
    }

    function test_RevertIfPriceIsStale() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.deal(user, 1 ether);
        vm.startPrank(user);
        MockV3Aggregator(proxy.s_ethUsdPriceFeed()).updateAnswer(3000e8);
        skip(2 hours); 
        vm.expectRevert(SubscriptionV2.Subscription__StalePrice.selector);
        proxy.subscribeWithEth{value: 1 ether}(planId);
        vm.stopPrank();
    }
}
