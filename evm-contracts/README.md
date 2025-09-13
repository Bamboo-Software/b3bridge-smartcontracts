# B3Bridge - Cross-Chain Bridge Smart Contract

A comprehensive cross-chain bridge smart contract system built with Solidity for bridging native tokens between different blockchain networks. The project implements two major cross-chain protocols: **Chainlink CCIP** and **Hyperlane** for robust, secure, and efficient cross-chain operations.

## Features

- **Dual Protocol Support**: Chainlink CCIP and Hyperlane integration
- **Cross-chain native token bridging** with multi-token support
- **Multi-signature validation system** with configurable threshold
- **Pausable and reentrancy-protected operations** for security
- **Dynamic fee calculation** with real-time price feeds
- **Support for multiple token types** (ETH, USDC, USDT)
- **Modular architecture** with separated business logic
- **Emergency controls** and circuit breakers

## Architecture

The project consists of two main bridge implementations:

### Core Contracts
- **B3BridgeETH.sol**: Main bridge contract with Chainlink CCIP receiver functionality
- **B3HyperlaneBridge.sol**: Hyperlane protocol implementation for advanced bridging
- **MockCCIPRouter.sol**: Mock CCIP router for testing
- **MockERC20.sol**: Mock ERC20 token for testing

### Modular Components
- **contracts/events/**: Event definitions for bridge operations
- **contracts/interfaces/**: Interface definitions (IHypERC20, etc.)
- **contracts/logics/**: Business logic contracts (FeeLogic)
- **contracts/structs/**: Data structure definitions (TokenRouteHyperlane)

## Supported Networks

- **Ethereum Mainnet** (chainId: 1)
- **Sepolia Testnet** (chainId: 11155111)
- **BSC Mainnet** (chainId: 56)
- **BSC Testnet** (chainId: 97)
- **Sei Network**
- **Localhost** (for development)

## Prerequisites

- Node.js >= 16
- npm or yarn
- Hardhat
- A wallet with private key for deployment

## Installation

1. Clone the repository
2. Install dependencies:
```bash
npm install
```

3. Set up environment files:
```bash
# For development
cp .env.dev .env

# For production
cp .env.prod .env
```

## Configuration

The project uses environment variables for configuration stored in `.env.dev` and `.env.prod` files.

### Network Configuration

Configure your network settings in `hardhat.config.ts`. Compiler settings:
- **Solidity Version**: 0.8.20
- **Optimizer**: Enabled with 100 runs
- **viaIR**: true (Intermediate Representation)
- **EVM Version**: paris

### Deploy Configuration

Network-specific deployment parameters are defined in `config/deploy_config.ts`:
- **Bridge Config**: Validators, threshold, token mappings, fee configurations
- **Hyperlane Config**: Route configurations, fee settings, price feeds

## Usage

### Compilation

```bash
# Development compilation (uses .env.dev)
npm run compile:dev

# Production compilation (uses .env.prod)  
npm run compile:prod
```

### Deployment

#### Bridge Deployment
```bash
# Deploy bridge to testnet
npm run deploy:bridge:testnet

# Deploy bridge to mainnet
npm run deploy:bridge:mainnet
```

#### Hyperlane Bridge Deployment
```bash
# Deploy Hyperlane bridge to testnet
npm run deploy:hyperlane:testnet

# Deploy Hyperlane bridge to mainnet
npm run deploy:hyperlane:mainnet

# Deploy to BSC
npm run deploy:hyperlane:bsc
npm run deploy:hyperlane:bsc-testnet
```

### Contract Verification

```bash
# Verify contracts using verification script
npx hardhat run scripts/verify.js --network <network>

# Manual verification
npx hardhat verify --network <network> <contract-address> <constructor-args>
```

### Testing

```bash
# Run all tests
npx hardhat test

# Run specific test suites
npx hardhat test test/NativeBridge.test.js
npx hardhat test test/getFeeBridge.test.js
npx hardhat test test/unified-pricing.test.js
```

### Hyperlane Setup Scripts

```bash
# Setup Hyperlane domains
npx hardhat run scripts/bridge/hyperlane/setupDomains.js --network <network>

# Setup price feeds
npx hardhat run scripts/bridge/hyperlane/setupPriceFeeds.js --network <network>

# Setup token routes
npx hardhat run scripts/bridge/hyperlane/setupRoutes.js --network <network>

# Setup fee configurations
npx hardhat run scripts/bridge/hyperlane/setupFees.js --network <network>
```

## Smart Contract Details

### B3BridgeETH Contract (Chainlink CCIP)

The main bridge contract implements:
- **Multi-signature validation** with configurable threshold
- **Cross-chain message handling** via Chainlink CCIP
- **Dynamic fee calculation** based on token type and amount
- **Pausable operations** for emergency stops
- **Reentrancy protection** on all state-changing functions

### B3HyperlaneBridge Contract (Hyperlane Protocol)

Advanced bridging features:
- **Hyperlane integration** for cross-chain communication
- **Modular fee logic** with customizable fee structures
- **Token route management** for multiple destination domains
- **Price feed integration** for accurate fee calculations
- **Batch operations** for efficient multi-token setup

### Key Functions

#### Bridge Operations
- `lockTokenCCIP()` / `lockTokenVL()`: Lock tokens for cross-chain transfer
- `unLockTokenVL()`: Unlock tokens after cross-chain verification
- `bridgeTokenHyperlane()`: Bridge tokens using Hyperlane protocol

#### Validator Management
- `addValidator()`: Add new validator to the system
- `removeValidator()`: Remove validator from the system
- `setThreshold()`: Update validation threshold

#### Fee & Price Management
- `getFeeBridge()`: Calculate bridge fees
- `setTokenPriceFeed()`: Set price feed for tokens
- `setTokenFeeConfig()`: Configure fee parameters

## Security Features

- **Multi-signature validation system** with configurable threshold
- **Reentrancy guards** on all state-changing functions using OpenZeppelin's ReentrancyGuard
- **Pausable contract** for emergency stops (Pausable pattern)
- **Access controls** with owner-only functions for critical operations
- **Input validation** and proper error handling with descriptive messages
- **SafeERC20** usage for secure token transfers
- **Transaction key tracking** to prevent replay attacks
- **Circuit breaker patterns** for emergency controls

## Dependencies

### Core Libraries
- **OpenZeppelin Contracts** v4.9.2 - Security patterns and standards
- **Chainlink Contracts** v1.4.0 & CCIP v1.6.0 - Cross-chain infrastructure
- **Hyperlane Core** v9.0.2 & SDK v13.2.1 - Advanced bridging protocol
- **LayerZero Examples** v1.1.0 - Cross-chain examples

### Development Tools
- **Hardhat** v2.24.0 - Development framework
- **Hardhat Toolbox** v5.0.0 - Essential plugins
- **Contract Sizer** v2.10.0 - Gas optimization analysis

## License

MIT License

## Development Workflow

1. **Setup**: Clone repository and install dependencies
2. **Configuration**: Set up `.env.dev` or `.env.prod` environment files
3. **Compilation**: Use `npm run compile:dev` for development
4. **Testing**: Run `npx hardhat test` to ensure code quality
5. **Deployment**: Use appropriate npm scripts for target network
6. **Verification**: Verify contracts on block explorers

## Project Structure

```
smartcontract-evm/
├── contracts/              # Smart contracts
│   ├── B3BridgeETH.sol    # Main CCIP bridge
│   ├── B3HyperlaneBridge.sol # Hyperlane bridge
│   ├── events/            # Event definitions
│   ├── interfaces/        # Contract interfaces
│   ├── logics/           # Business logic contracts
│   └── structs/          # Data structures
├── scripts/               # Deployment scripts
│   └── bridge/           # Bridge-specific scripts
├── test/                 # Test files
├── config/               # Configuration files
└── package.json          # Dependencies and scripts
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Make your changes following the existing code style
4. Add comprehensive tests for new functionality
5. Ensure all tests pass (`npx hardhat test`)
6. Submit a pull request with detailed description

## Support

For issues and questions, please create an issue in the GitHub repository.