//SPDx-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeploySubscriptionV1} from "../script/DeploySubscriptionV1.s.sol";
import {UpgradeSubscriptionV1} from "../script/UpgradeSubscriptionV1.s.sol";
import {SubscriptionV1} from "../src/SubscriptionV1.sol";
import {SubscriptionV2} from "../src/SubscriptionV2.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SubscriptionV1Test is Test {
    DeploySubscriptionV1 deployer;
    UpgradeSubscriptionV1 upgrader;
    SubscriptionV1 proxy;
    HelperConfig config;

    address owner;
    address usdc;
    address treasury;
    address user = makeAddr("user");

    uint256 constant BILLING_PERIOD = 30 days;

    function setUp() public {
        deployer = new DeploySubscriptionV1();
        upgrader = new UpgradeSubscriptionV1();
        (address _proxyAddress, HelperConfig _config) = deployer.run();
        proxy = SubscriptionV1(_proxyAddress);
        config = _config;

        (usdc, treasury,, owner) = config.activeNetworkConfig();

        deal(usdc, user, 500 * 1e6);
    }

    function test_subscriptionHasBeenDeployedAndInitialized() public {
        vm.startPrank(owner);
        vm.expectRevert();
        proxy.initialize(owner, usdc, treasury);
        vm.stopPrank();
    }

    function test_valuesHaveBeenInitializedProperly() public view {
        assertEq(proxy.owner(), owner);
        assertEq(proxy.s_treasury(), treasury);
        assertEq(proxy.s_usdc(), usdc);
    }

    function test_onlyOwnerCanCreatePlan() public {
        vm.startPrank(user);
        vm.expectRevert();
        proxy.createPlan(50);
        vm.stopPrank();
    }

    function test_RevertWhencreatePlansPriceIsZero() public {
        vm.startPrank(owner);
        vm.expectRevert(SubscriptionV1.Subscription__CannotBeZero.selector);
        proxy.createPlan(0);
        vm.stopPrank();
    }

    function test_createPlan() public {
        vm.startPrank(owner);
        uint256 id = proxy.createPlan(50);
        vm.stopPrank();

        (uint256 pricePerPeriod, bool active) = proxy.s_plans(id);

        assertEq(id, 1);
        assertEq(pricePerPeriod, 50);
        assertEq(active, true);
        assertEq(proxy.s_nextPlanId(), 2);
    }

    function test_onlyOwnerCanSetPlanStatus() public {
        vm.startPrank(owner);
        proxy.createPlan(50);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert();
        proxy.setPlanStatus(1, false);
        vm.stopPrank();
    }

    function test_RevertWhenSetPlanStatusIsSetToZero() public {
        uint256 planId = 0;
        bool status = true;

        vm.startPrank(owner);
        proxy.createPlan(50);
        vm.expectRevert(SubscriptionV1.Subscription__PlanDoesNotExist.selector);
        proxy.setPlanStatus(planId, status);
        vm.stopPrank();
    }

    function test_RevertWhenSetPlanStatusIsSetToInvalidId() public {
        uint256 planId = 2;
        bool status = true;

        vm.startPrank(owner);
        proxy.createPlan(50);
        vm.expectRevert(SubscriptionV1.Subscription__PlanDoesNotExist.selector);
        proxy.setPlanStatus(planId, status);
        vm.stopPrank();
    }

    function test_RevertWhenSetPlanStatusIsSame() public {
        uint256 planId = 1;
        bool status = true;

        vm.startPrank(owner);
        proxy.createPlan(50);
        vm.expectRevert(SubscriptionV1.Subscription__SameStatus.selector);
        proxy.setPlanStatus(planId, status);
        vm.stopPrank();
    }

    function test_SetPlanStatusWorks() public {
        uint256 planId = 1;
        bool status = false;

        bool previousActiveState;
        bool newActiveState;

        vm.startPrank(owner);
        proxy.createPlan(50);

        (, previousActiveState) = proxy.s_plans(planId);

        proxy.setPlanStatus(planId, status);

        (, newActiveState) = proxy.s_plans(planId);
        vm.stopPrank();

        assert(newActiveState != previousActiveState);
    }

    function test_onlyOwnerCanSetTreasury() public {
        vm.startPrank(user);
        vm.expectRevert();
        proxy.setTreasury(address(1));
        vm.stopPrank();
    }

    function test_RevertWhenSetTreasuryIsZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(SubscriptionV1.Subscription__ZeroAddress.selector);
        proxy.setTreasury(address(0));
        vm.stopPrank();
    }

    function test_setTreasuryWorks() public {
        vm.startPrank(owner);
        proxy.setTreasury(address(0x2));
        vm.stopPrank();

        assertEq(proxy.s_treasury(), address(0x2));
    }

    function test_RevertWhenSubscribeToNonExistentPlan() public {
        vm.startPrank(user);
        vm.expectRevert(SubscriptionV1.Subscription__PlanDoesNotExist.selector);
        proxy.subscribe(999); // Non-existent plan ID
        vm.stopPrank();
    }

    function test_RevertWhenSubscribeToInactivePlan() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        proxy.setPlanStatus(planId, false); // Deactivate the plan
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(SubscriptionV1.Subscription__PlanDoesNotExist.selector);
        proxy.subscribe(planId);
        vm.stopPrank();
    }

    function test_RevertWhenAlreadySubscribed() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.startPrank(user);
        IERC20(usdc).approve(address(proxy), type(uint256).max);
        proxy.subscribe(planId);
        vm.expectRevert(SubscriptionV1.Subscription__AlreadySubscribed.selector);
        proxy.subscribe(planId);
        vm.stopPrank();
    }

    function test_SubscribeWorks() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.startPrank(user);
        IERC20(usdc).approve(address(proxy), type(uint256).max);
        proxy.subscribe(planId);
        vm.stopPrank();

        SubscriptionV1.Subscription memory subscription = proxy.getSubscription(user);
        assertEq(subscription.planId, planId);
        assertEq(subscription.active, true);
        assert(subscription.nextPaymentDue > block.timestamp);
    }

    function test_RevertWhenRenewWithoutSubscription() public {
        vm.startPrank(user);
        vm.expectRevert(SubscriptionV1.Subscription__NotSubscribedToAnyPlan.selector);
        proxy.renewSubscription();
        vm.stopPrank();
    }

    function test_RevertWhenRenewBeforeExpiration() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.startPrank(user);
        IERC20(usdc).approve(address(proxy), type(uint256).max);
        proxy.subscribe(planId);
        vm.expectRevert(SubscriptionV1.Subscription__NotYetExpired.selector);
        proxy.renewSubscription();
        vm.stopPrank();
    }

    function test_RenewSubscriptionWorks() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.startPrank(user);
        IERC20(usdc).approve(address(proxy), type(uint256).max);
        proxy.subscribe(planId);
        skip(BILLING_PERIOD + 1);
        proxy.renewSubscription();
        vm.stopPrank();

        SubscriptionV1.Subscription memory subscription = proxy.getSubscription(user);
        assert(subscription.nextPaymentDue > block.timestamp);
    }

    function test_RevertWhenCancelWithoutSubscription() public {
        vm.startPrank(user);
        vm.expectRevert(SubscriptionV1.Subscription__NotSubscribedToAnyPlan.selector);
        proxy.cancelSubscription();
        vm.stopPrank();
    }

    function test_CancelSubscriptionWorks() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.startPrank(user);

        IERC20(usdc).approve(address(proxy), type(uint256).max);
        proxy.subscribe(planId);
        proxy.cancelSubscription();
        vm.stopPrank();

        SubscriptionV1.Subscription memory subscription = proxy.getSubscription(user);
        assertEq(subscription.active, false);
        assertEq(subscription.planId, 0);
        assertEq(subscription.nextPaymentDue, 0);
    }

    function test_RevertWhenGetNonExistentPlan() public {
        vm.startPrank(user);
        vm.expectRevert(SubscriptionV1.Subscription__PlanDoesNotExist.selector);
        proxy.getPlan(999); // Non-existent plan ID
        vm.stopPrank();
    }

    function test_GetPlanWorks() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        SubscriptionV1.Plan memory plan = proxy.getPlan(planId);
        assertEq(plan.pricePerPeriod, 50);
        assertEq(plan.active, true);
    }

    function test_GetSubscriptionWorks() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.startPrank(user);
        IERC20(usdc).approve(address(proxy), type(uint256).max);
        proxy.subscribe(planId);
        vm.stopPrank();

        SubscriptionV1.Subscription memory subscription = proxy.getSubscription(user);
        assertEq(subscription.planId, planId);
        assertEq(subscription.active, true);
        assert(subscription.nextPaymentDue > block.timestamp);
    }

    function test_GetSubscriptionForNonSubscriber() public {
        SubscriptionV1.Subscription memory subscription = proxy.getSubscription(user);
        assertEq(subscription.planId, 0);
        assertEq(subscription.active, false);
        assertEq(subscription.nextPaymentDue, 0);
    }

    function test_IsPaymentDueReturnsFalseForNonSubscriber() public {
        bool paymentDue = proxy.isPaymentDue(user);
        assertEq(paymentDue, false);
    }

    function test_IsPaymentDueReturnsFalseForActiveSubscription() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.startPrank(user);
        IERC20(usdc).approve(address(proxy), type(uint256).max);
        proxy.subscribe(planId);
        bool paymentDue = proxy.isPaymentDue(user);
        vm.stopPrank();

        assertEq(paymentDue, false);
    }

    function test_IsPaymentDueReturnsTrueWhenExpired() public {
        vm.startPrank(owner);
        uint256 planId = proxy.createPlan(50);
        vm.stopPrank();

        vm.startPrank(user);
        IERC20(usdc).approve(address(proxy), type(uint256).max);
        proxy.subscribe(planId);
        skip(BILLING_PERIOD + 1);
        bool paymentDue = proxy.isPaymentDue(user);
        vm.stopPrank();

        assertEq(paymentDue, true);
    }

    function test_UpgradeToSubscriptionV2() public {
        vm.startPrank(owner);
        SubscriptionV2 newImplementation = new SubscriptionV2();

        address mockPriceFeed = makeAddr("mockPriceFeed");
        bytes memory data = abi.encodeWithSelector(SubscriptionV2.initializeV2.selector, mockPriceFeed);
        proxy.upgradeToAndCall(address(newImplementation), data);
        SubscriptionV2 upgradedProxy = SubscriptionV2(address(proxy));

        assertEq(upgradedProxy.s_ethUsdPriceFeed(), mockPriceFeed);
        vm.stopPrank();
    }

    function test_UpgradeFailsWhenCalledByNonOwner() public {
        vm.startPrank(user);
        SubscriptionV2 newImplementation = new SubscriptionV2();

        address mockPriceFeed = makeAddr("mockPriceFeed");
        bytes memory data = abi.encodeWithSelector(SubscriptionV2.initializeV2.selector, mockPriceFeed);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(newImplementation), data);
        vm.stopPrank();
    }
}
