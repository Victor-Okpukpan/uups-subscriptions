// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SubscriptionV1
 * @author Victor_TheOracle (@victorokpukpan_)
 * @notice A UUPS upgradeable subscription contract that allows users to subscribe to plans using USDC payments.
 * @dev This contract manages subscription plans, user subscriptions, and handles billing periods of 30 days.
 * It uses USDC for payments and transfers funds to a designated treasury.
 */
contract SubscriptionV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    /// @notice Thrown when an invalid zero address is provided.
    error Subscription__ZeroAddress();
    /// @notice Thrown when a value that cannot be zero is set to zero.
    error Subscription__CannotBeZero();
    /// @notice Thrown when attempting to access a non-existent plan.
    error Subscription__PlanDoesNotExist();
    /// @notice Thrown when trying to set a plan status to the same value it already has.
    error Subscription__SameStatus();
    /// @notice Thrown when a user tries to subscribe while already having an active subscription.
    error Subscription__AlreadySubscribed();
    /// @notice Thrown when attempting to renew a subscription before it has expired.
    error Subscription__NotYetExpired();
    /// @notice Thrown when a user tries to perform an action without an active subscription.
    error Subscription__NotSubscribedToAnyPlan();

    /// @notice The address of the treasury where subscription payments are sent.
    address public s_treasury;
    /// @notice The ID for the next plan to be created.
    uint256 public s_nextPlanId;
    /// @notice The address of the USDC token used for payments.
    address public s_usdc;
    /// @notice The billing period for subscriptions, set to 30 days.
    uint256 public constant BILLING_PERIOD = 30 days;

    /// @notice Mapping of plan IDs to their details.
    mapping(uint256 id => Plan) public s_plans;
    /// @notice Mapping of user addresses to their subscription details.
    mapping(address user => Subscription) public s_subscriptions;

    /// @notice Represents a subscription plan.
    struct Plan {
        /// @notice The price per billing period in USD (without decimals).
        uint256 pricePerPeriod;
        /// @notice Whether the plan is active and available for subscription.
        bool active;
    }

    /// @notice Represents a user's subscription details.
    struct Subscription {
        /// @notice The ID of the subscribed plan.
        uint256 planId;
        /// @notice The timestamp when the next payment is due.
        uint256 nextPaymentDue;
        /// @notice Whether the subscription is active.
        bool active;
    }

    /// @notice Emitted when a new plan is created.
    event NewPlanCreated(uint256 indexed planId);
    /// @notice Emitted when a plan's status is changed.
    event StatusChanged(uint256 indexed planId, bool status);
    /// @notice Emitted when the treasury address is updated.
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    /// @notice Emitted when a user activates a new subscription.
    event UserSubscriptionActivated(address indexed user, uint256 planId);
    /// @notice Emitted when a user renews their subscription.
    event UserSubscribed(address indexed user, uint256 planId);
    /// @notice Emitted when a user cancels their subscription.
    event SubscriptionCancelled(address indexed user);

    /// @notice Constructor that disables initializers.
    /// @dev This prevents the contract from being initialized directly.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with owner, USDC, and treasury addresses.
    /// @param _owner The address to set as the initial owner.
    /// @param _usdc The address of the USDC token contract.
    /// @param _treasury The address of the treasury for receiving payments.
    /// @dev This function can only be called once due to the initializer modifier.
    function initialize(address _owner, address _usdc, address _treasury) external initializer {
        __Ownable_init(_owner);

        s_usdc = _usdc;
        s_treasury = _treasury;
        s_nextPlanId = 1;
    }

    /// @notice Creates a new subscription plan.
    /// @param _pricePerPeriod The price per billing period in USD (without decimals).
    /// @return id The ID of the newly created plan.
    /// @dev Only the owner can call this. The plan starts as inactive.
    function createPlan(uint256 _pricePerPeriod) external onlyOwner returns (uint256 id) {
        if (_pricePerPeriod == 0) {
            revert Subscription__CannotBeZero();
        }
        id = s_nextPlanId;
        s_plans[id] = Plan({pricePerPeriod: _pricePerPeriod, active: true});
        s_nextPlanId++;
        emit NewPlanCreated(id);
    }

    /// @notice Sets the active status of a subscription plan.
    /// @param _planId The ID of the plan to update.
    /// @param _status The new active status for the plan.
    /// @dev Only the owner can call this. Emits StatusChanged event.
    function setPlanStatus(uint256 _planId, bool _status) external onlyOwner {
        if (_planId == 0 || _planId >= s_nextPlanId) {
            revert Subscription__PlanDoesNotExist();
        }
        if (s_plans[_planId].active == _status) {
            revert Subscription__SameStatus();
        }
        s_plans[_planId].active = _status;
        emit StatusChanged(_planId, _status);
    }

    /// @notice Updates the treasury address where payments are sent.
    /// @param _treasury The new treasury address.
    /// @dev Only the owner can call this. Emits TreasuryUpdated event.
    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) {
            revert Subscription__ZeroAddress();
        }
        emit TreasuryUpdated(s_treasury, _treasury);
        s_treasury = _treasury;
    }

    // User functions

    /// @notice Subscribes the caller to a specified plan using USDC payment.
    /// @param _planId The ID of the plan to subscribe to.
    /// @dev Transfers the plan's price in USDC from the user to the treasury. Activates the subscription for 30 days.
    function subscribe(uint256 _planId) external {
        if (_planId == 0 || _planId >= s_nextPlanId || !s_plans[_planId].active) {
            revert Subscription__PlanDoesNotExist();
        }

        Subscription storage userSubscription = s_subscriptions[msg.sender];
        if (userSubscription.active == true) {
            revert Subscription__AlreadySubscribed();
        }

        uint256 amountToPay = s_plans[_planId].pricePerPeriod * 1e6;

        SafeERC20.safeTransferFrom(IERC20(s_usdc), msg.sender, address(s_treasury), amountToPay);

        s_subscriptions[msg.sender] =
            Subscription({planId: _planId, nextPaymentDue: block.timestamp + BILLING_PERIOD, active: true});

        emit UserSubscriptionActivated(msg.sender, _planId);
    }

    /// @notice Renews the caller's active subscription for another billing period.
    /// @dev Transfers USDC for the plan's price. Can only be called after the current period expires.
    function renewSubscription() external {
        Subscription storage userSubscription = s_subscriptions[msg.sender];

        if (!userSubscription.active) {
            revert Subscription__NotSubscribedToAnyPlan();
        }
        if (block.timestamp < userSubscription.nextPaymentDue) {
            revert Subscription__NotYetExpired();
        }

        uint256 planId = userSubscription.planId;
        uint256 amountToPay = s_plans[planId].pricePerPeriod * 1e6;

        SafeERC20.safeTransferFrom(IERC20(s_usdc), msg.sender, address(s_treasury), amountToPay);

        userSubscription.nextPaymentDue = block.timestamp + BILLING_PERIOD;

        emit UserSubscribed(msg.sender, planId);
    }

    /// @notice Cancels the caller's active subscription.
    /// @dev Deactivates the subscription and resets its details. Can be overridden in upgraded versions.
    function cancelSubscription() public virtual {
        Subscription storage userSubscription = s_subscriptions[msg.sender];

        if (!userSubscription.active) {
            revert Subscription__NotSubscribedToAnyPlan();
        }

        userSubscription.active = false;
        userSubscription.nextPaymentDue = 0;
        userSubscription.planId = 0;

        emit SubscriptionCancelled(msg.sender);
    }

    /// @notice Retrieves the details of a specific subscription plan.
    /// @param _planId The ID of the plan to retrieve.
    /// @return The Plan struct with price and active status.
    function getPlan(uint256 _planId) external view returns (Plan memory) {
        if (_planId == 0 || _planId >= s_nextPlanId) {
            revert Subscription__PlanDoesNotExist();
        }
        return s_plans[_planId];
    }

    /// @notice Retrieves the subscription details of a specific user.
    /// @param _user The address of the user whose subscription to retrieve.
    /// @return The Subscription struct containing the user's subscription info.
    function getSubscription(address _user) external view returns (Subscription memory) {
        return s_subscriptions[_user];
    }

    /// @notice Checks if the payment for a user's subscription is currently due.
    /// @param _user The address of the user to check.
    /// @return True if the subscription is active and the next payment is due, false otherwise.
    function isPaymentDue(address _user) public view returns (bool) {
        Subscription storage userSubscription = s_subscriptions[_user];
        if (!userSubscription.active) {
            return false;
        }
        return block.timestamp > s_subscriptions[_user].nextPaymentDue;
    }

    /// @notice Authorizes upgrades to new implementations.
    /// @param newImplementation The address of the new contract implementation.
    /// @dev Only the owner can perform upgrades. Required for UUPS pattern.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
