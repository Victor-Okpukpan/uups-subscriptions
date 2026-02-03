// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {SubscriptionV1} from "../src/SubscriptionV1.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title SubscriptionV2
 * @author Victor_TheOracle (@victorokpukpan_)
 * @notice An upgraded version of SubscriptionV1 that adds support for ETH payments using Chainlink price feeds.
 * @dev Extends SubscriptionV1 with ETH subscription and renewal functions, converting USD prices to ETH amounts.
 */
contract SubscriptionV2 is SubscriptionV1 {
    /// @notice Thrown when a user tries to subscribe with ETH while already subscribed.
    error Subscription__AlreadySubscribedEth();
    /// @notice Thrown when the sent ETH amount is insufficient for the subscription.
    error Subscription__NotEnoughEth();
    /// @notice Thrown when an ETH transfer fails.
    error Subscription__TransferFailed();
    /// @notice Thrown when the Chainlink price feed returns an invalid (negative) price.
    error Subscription__InvalidPrice();
    /// @notice Thrown when the Chainlink price feed data is stale (older than 1 hour).
    error Subscription__StalePrice();
    /// @notice Thrown when a user tries to renew with ETH but is not an ETH subscriber.
    error Subscription__NotEthSubscriber();

    /// @notice The address of the Chainlink ETH/USD price feed.
    address public s_ethUsdPriceFeed;
    /// @notice Constant for one hour in seconds, used for price staleness check.
    uint256 public constant ONE_HOUR = 1 hours;
    /// @notice Mapping to track if a user subscribed with ETH.
    mapping(address => bool) public s_isEth;

    /// @notice Initializes the V2 upgrade with the ETH/USD price feed address.
    /// @param _ethUsdPriceFeed The address of the Chainlink AggregatorV3Interface for ETH/USD.
    /// @dev Uses reinitializer(2) to ensure it's called only once for this version.
    function initializeV2(address _ethUsdPriceFeed) external reinitializer(2) {
        if (_ethUsdPriceFeed == address(0)) {
            revert Subscription__ZeroAddress();
        }
        s_ethUsdPriceFeed = _ethUsdPriceFeed;
    }

    /// @notice Subscribes the caller to a plan using ETH payment.
    /// @param _planId The ID of the plan to subscribe to.
    /// @dev Calculates required ETH based on current price feed, transfers to treasury, and refunds excess.
    function subscribeWithEth(uint256 _planId) external payable {
        if (_planId == 0 || _planId >= s_nextPlanId || !s_plans[_planId].active) {
            revert Subscription__PlanDoesNotExist();
        }

        if (s_subscriptions[msg.sender].active) {
            revert Subscription__AlreadySubscribed();
        }

        uint256 requiredEth = _getRequiredEth(_planId);

        if (msg.value < requiredEth) {
            revert Subscription__NotEnoughEth();
        }

        _finalizeEthPayments(requiredEth);

        s_subscriptions[msg.sender] =
            Subscription({planId: _planId, nextPaymentDue: block.timestamp + BILLING_PERIOD, active: true});

        s_isEth[msg.sender] = true;

        emit UserSubscriptionActivated(msg.sender, _planId);
    }

    /// @notice Renews the caller's subscription using ETH payment.
    /// @dev Only callable by users who subscribed with ETH. Handles payment and extends subscription.
    function renewSubscriptionWithEth() external payable {
        Subscription storage userSubscription = s_subscriptions[msg.sender];
        if (!userSubscription.active) revert Subscription__NotSubscribedToAnyPlan();

        if (!s_isEth[msg.sender]) revert Subscription__NotEthSubscriber();

        if (block.timestamp < userSubscription.nextPaymentDue) revert Subscription__NotYetExpired();

        uint256 requiredEth = _getRequiredEth(userSubscription.planId);
        if (msg.value < requiredEth) revert Subscription__NotEnoughEth();

        _finalizeEthPayments(requiredEth);
        userSubscription.nextPaymentDue = block.timestamp + BILLING_PERIOD;

        emit UserSubscribed(msg.sender, userSubscription.planId);
    }

    /// @notice Cancels the caller's subscription and resets the ETH payment flag.
    /// @dev Calls the parent cancelSubscription and additionally sets s_isEth to false.
    function cancelSubscription() public override {
        super.cancelSubscription();
        s_isEth[msg.sender] = false;
    }

    /// @notice Calculates the required ETH amount for subscribing to or renewing a plan.
    /// @param _planId The ID of the plan.
    /// @return requiredEth The amount of ETH required in wei.
    /// @dev Fetches the latest ETH/USD price from Chainlink and performs the conversion.
    function _getRequiredEth(uint256 _planId) internal view returns (uint256 requiredEth) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_ethUsdPriceFeed);
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();

        if (price < 0) {
            revert Subscription__InvalidPrice();
        }

        if (block.timestamp - updatedAt > ONE_HOUR) {
            revert Subscription__StalePrice();
        }

        uint256 decimals = uint256(priceFeed.decimals());

        requiredEth = (s_plans[_planId].pricePerPeriod * 1e18 * (10 ** decimals)) / uint256(price);
    }

    function _finalizeEthPayments(uint256 _required) internal {
        (bool success,) = payable(s_treasury).call{value: _required}("");
        if (!success) {
            revert Subscription__TransferFailed();
        }

        uint256 excess = msg.value - _required;
        if (excess > 0) {
            (bool refundSuccess,) = payable(msg.sender).call{value: excess}("");
            if (!refundSuccess) {
                revert Subscription__TransferFailed();
            }
        }
    }
}
