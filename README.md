# UUPS Subscriptions

This repository contains a UUPS (Universal Upgradeable Proxy Standard) upgradeable subscription system implemented in Solidity. The system allows users to subscribe to plans using USDC or ETH payments, with support for Chainlink price feeds for ETH/USD conversions.

## Contracts

### SubscriptionV1
- **Description**: The base contract for managing subscription plans and user subscriptions.
- **Features**:
  - Create and manage subscription plans.
  - Users can subscribe, renew, and cancel subscriptions using USDC.
  - Billing period is set to 30 days.
  - Funds are transferred to a designated treasury address.

### SubscriptionV2
- **Description**: An upgraded version of `SubscriptionV1` that adds support for ETH payments.
- **Features**:
  - Users can subscribe, renew, and cancel subscriptions using ETH.
  - ETH payments are converted from USD prices using Chainlink price feeds.
  - Handles price staleness and refunds excess ETH.

## Scripts

### HelperConfig
- **Purpose**: Provides network-specific configurations for testing and deployment.
- **Features**:
  - Supports Sepolia and Anvil networks.
  - Deploys mock contracts for USDC and Chainlink price feeds on Anvil.

### DeploySubscriptionV1
- **Purpose**: Deploys the `SubscriptionV1` contract using the UUPS proxy pattern.
- **Details**:
  - Deploys the `SubscriptionV1` implementation contract.
  - Initializes the proxy with the owner, USDC token address, and treasury address.

### UpgradeSubscriptionV1
- **Purpose**: Upgrades the deployed `SubscriptionV1` contract to `SubscriptionV2`.
- **Details**:
  - Deploys the `SubscriptionV2` implementation contract.
  - Upgrades the proxy to use the new implementation.
  - Initializes the new implementation with the Chainlink ETH/USD price feed address.

## Usage

### Build
```bash
forge build
```

### Test
```bash
forge test
```

### Deploy
```bash
forge script script/DeploySubscriptionV1.s.sol:DeploySubscriptionV1 --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Upgrade
```bash
forge script script/UpgradeSubscriptionV1.s.sol:UpgradeSubscriptionV1 --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Format
```bash
forge fmt
```

## Dependencies
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Chainlink Contracts](https://github.com/smartcontractkit/chainlink)
- [Foundry](https://github.com/foundry-rs/foundry)

## License

This project is licensed under the MIT License.
