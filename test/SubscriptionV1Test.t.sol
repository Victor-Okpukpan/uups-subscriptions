//SPDx-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeploySubscriptionV1} from "../script/DeploySubscriptionV1.s.sol";
import {UpgradeSubscriptionV1} from "../script/UpgradeSubscriptionV1.s.sol";
import {SubscriptionV1} from "../src/SubscriptionV1.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract SubscriptionV1Test is Test {
    DeploySubscriptionV1 deployer;
    UpgradeSubscriptionV1 upgrader;
    SubscriptionV1 proxy;
    HelperConfig config;

    address owner;
    address usdc;
    address treasury;
    address user = makeAddr("user");

    function setUp() public {
        deployer = new DeploySubscriptionV1();
        upgrader = new UpgradeSubscriptionV1();
        (address _proxyAddress, HelperConfig _config) = deployer.run();
        proxy = SubscriptionV1(_proxyAddress);
        config = _config;

        (usdc, treasury,, owner) = config.activeNetworkConfig();
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

    function test_setTreasuryWorks() public {
        vm.startPrank(owner);
        proxy.setTreasury(address(0x2));
        vm.stopPrank();

        assertEq(proxy.s_treasury(), address(0x2));
    }
}
