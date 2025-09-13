# B3Bridge Cross-Chain Bridge Smart Contracts

B3Bridge is a secure cross-chain bridge solution that enables seamless token transfers between different blockchain networks using two main protocols:
- **Chainlink CCIP** (Cross-Chain Interoperability Protocol)
- **Hyperlane** cross-chain messaging protocol

The bridge supports multi-signature validator consensus and flexible fee management across multiple blockchain networks.

## 🚀 Features

- **Dual Bridge Architecture**: Supports both Chainlink CCIP and Hyperlane protocols
- **Cross-Chain Token Transfers**: Secure token bridging between multiple blockchain networks
- **Multi-Signature Security**: Validator consensus mechanism with configurable thresholds
- **Flexible Fee Management**: Percentage-based and fixed fees with min/max limits
- **Token Mapping**: Support for multiple token types with custom route configurations
- **Wrapped Token Support**: Native WETH and WUSDC implementations
- **Sei Oracle Integration**: Built-in price feeds for Sei and ETH/USD
- **Emergency Controls**: Pause/unpause functionality and emergency withdrawal mechanisms

## 🏗️ Architecture

### Core Contracts

- **`B3BridgeSei.sol`**: Primary CCIP bridge contract handling cross-chain token transfers with validator consensus
- **`B3HyperlaneBridge.sol`**: Hyperlane bridge implementation with domain routing and fee management
- **`CustomCoin.sol`**: Base custom token implementation for bridge operations
- **`WETH.sol`** / **`WUSDC.sol`**: Wrapped Ethereum and USD Coin implementations

### Modular Components

- **`contracts/logic/`**: Business logic modules
  - `CCIPLogic.sol`: Chainlink CCIP integration
  - `ValidatorLogic.sol`: Multi-signature validator management
  - `FeeLogic.sol`: Fee calculation and distribution
- **`contracts/libs/`**: Utility libraries
  - `PayloadLib.sol`: Payload processing utilities
  - `SignatureLib.sol`: Cryptographic signature handling
- **`contracts/structs/`**: Data structure definitions
- **`contracts/events/`**: Event definitions
- **`contracts/interfaces/`**: Interface definitions

## 🛠️ Prerequisites

- Node.js >= 16.0.0
- npm or yarn
- Hardhat

## 📦 Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd smartcontract-cosmos
```

2. Install dependencies:
```bash
npm install
```

3. Set up environment variables:
```bash
# For development
cp .env.dev.example .env

# For production
cp .env.prod.example .env

# Edit .env with your configuration
```

## ⚙️ Configuration

### Environment Setup

The project uses separate environment files for different deployment environments:
- `.env.dev.example`: Development/testnet configuration
- `.env.prod.example`: Production/mainnet configuration

#### Core Configuration
- `PRIVATE_KEY`: Deployer wallet private key
- `SEI_RPC_URL`: Sei network RPC endpoint
- `SEI_EXPLORER_API_KEY`: For contract verification on Sei networks
- `SEI_BROWSER_URL`: Block explorer URL (optional)

#### Bridge Configuration
Configure validator settings:
- `VALIDATORS`: Comma-separated validator addresses
- `THRESHOLD`: Required validator signatures for consensus

#### Token Configuration (WETH/WUSDC)
For each token, configure:
- `TOKEN_ID`: Unique token identifier (hex format)
- `TOKEN_ADDRESS`: Deployed contract address
- `FEE_RATE`: Percentage fee (basis points)
- `FIXED_FEE`: Fixed fee amount
- `DECIMALS`: Token decimal places

## 🚀 Quick Start: Deploy & Configure Bridge

### 1. Environment-Specific Compilation and Deployment

The project uses npm scripts that automatically handle environment setup:

#### For Development/Testnet:
```bash
# Compile with development environment
npm run compile:dev

# Deploy tokens to testnet
npm run deploy:weth:testnet
npm run deploy:wusdc:testnet

# Deploy bridge to testnet
npm run deploy:bridge:testnet

# Deploy Hyperlane bridge to testnet
npm run deploy:hyperlane:testnet
```

#### For Production/Mainnet:
```bash
# Compile with production environment
npm run compile:prod

# Deploy tokens to mainnet
npm run deploy:weth:mainnet
npm run deploy:wusdc:mainnet

# Deploy bridge to mainnet
npm run deploy:bridge:mainnet

# Deploy Hyperlane bridge to mainnet
npm run deploy:hyperlane:mainnet
```

### 2. Post-Deployment Configuration

After deployment, you may need to configure:

1. **Token Role Management**: Set minter/burner roles
```bash
npx hardhat run scripts/customCoins/set_roles_token.js --network sei
```

2. **Hyperlane Setup**: Configure domains, routes, and fees
```bash
npx hardhat run scripts/bridge/hyperlane/setup/setupDomains.js --network sei
npx hardhat run scripts/bridge/hyperlane/setup/setupRoutes.js --network sei
npx hardhat run scripts/bridge/hyperlane/setup/setupFees.js --network sei
```

### 3. Contract Verification

Verify deployed contracts:
```bash
npx hardhat run scripts/verify.js --network sei
```

## 📦 Available npm Scripts

### Compilation
- **`npm run compile:dev`**: Compile with development environment (.env.dev)
- **`npm run compile:prod`**: Compile with production environment (.env.prod)

### Bridge Deployment
- **`npm run deploy:bridge:testnet`**: Deploy CCIP bridge to Sei testnet
- **`npm run deploy:bridge:mainnet`**: Deploy CCIP bridge to Sei mainnet
- **`npm run deploy:hyperlane:testnet`**: Deploy Hyperlane bridge to testnet
- **`npm run deploy:hyperlane:mainnet`**: Deploy Hyperlane bridge to mainnet

### Token Deployment
- **`npm run deploy:weth:testnet`** / **`npm run deploy:weth:mainnet`**: Deploy WETH token
- **`npm run deploy:wusdc:testnet`** / **`npm run deploy:wusdc:mainnet`**: Deploy WUSDC token

### Manual Commands
```bash
# Run tests
npx hardhat test

# Local development
npx hardhat node

# Contract verification
npx hardhat verify --network sei <contract_address> <constructor_args>
```


## 🌐 Supported Networks

The project primarily focuses on Sei networks with cross-chain bridging capabilities:

| Network | Chain ID | RPC Endpoint | Status |
|---------|----------|--------------|--------|
| Sei Mainnet | 1329 | https://evm-rpc.sei-apis.com | ✅ Primary |
| Sei Testnet | 1328 | Configurable via SEI_RPC_URL | ✅ Primary |
| Local Hardhat | 31337 | http://localhost:8545 | ✅ Development |

Historical support includes Ethereum Sepolia, BSC, and other networks via CCIP integration.

## 🔧 Bridge Operations

### Token Transfer Flow

1. **Source Chain**: User initiates transfer by burning/locking tokens
2. **CCIP Message**: Chainlink CCIP sends cross-chain message
3. **Validator Consensus**: Validators sign the transfer payload
4. **Destination Chain**: Tokens are minted/unlocked after consensus

### Key Functions

#### CCIP Bridge (B3BridgeSei.sol)
- `burnTokenCCIP()`: Burn tokens on source chain via CCIP
- `burnTokenVL()`: Burn tokens via validator consensus
- `mintTokenVL()`: Mint tokens on destination chain with validator signatures
- `setTokenMapping()`: Configure token mappings
- `addValidator()` / `removeValidator()`: Manage validator set
- `setThreshold()`: Update signature threshold
- `setFeeRate()`: Configure fee percentages
- `distributeFee()`: Handle fee distribution

#### Hyperlane Bridge (B3HyperlaneBridge.sol)
- `bridgeTokenHyperlane()`: Bridge tokens via Hyperlane protocol
- `updateTokenRouteHyperlane()`: Configure cross-chain token routes
- `setTokenFeeConfig()`: Set fee configurations for tokens
- `updateSupportedDomainHyperlane()`: Manage supported domains
- `setMinMaxFeeBridge()`: Configure fee limits
- `pause()` / `unpause()`: Emergency controls

## 🛡️ Security Features

- **Multi-Signature Validation**: Configurable validator threshold
- **Reentrancy Protection**: OpenZeppelin ReentrancyGuard
- **Access Control**: Ownable pattern for admin functions
- **Signature Verification**: ECDSA cryptographic signatures
- **Transaction Uniqueness**: Prevention of replay attacks

## 📁 Project Structure

```
smartcontract-cosmos/
├── contracts/                 # Smart contracts
│   ├── B3BridgeSei.sol       # Main CCIP bridge contract
│   ├── B3HyperlaneBridge.sol # Hyperlane bridge implementation
│   ├── CustomCoin.sol        # Base token contract
│   ├── WETH.sol / WUSDC.sol  # Wrapped token implementations
│   ├── logic/                # Business logic modules
│   │   ├── CCIPLogic.sol    # CCIP integration
│   │   ├── ValidatorLogic.sol # Multi-sig validation
│   │   └── FeeLogic.sol     # Fee management
│   ├── libs/                # Utility libraries
│   ├── structs/             # Data structures
│   ├── events/              # Event definitions
│   └── interfaces/          # Interface definitions
├── scripts/                 # Deployment and management scripts
│   ├── bridge/             # Bridge deployment scripts
│   │   ├── deploy.js       # Main CCIP bridge deployment
│   │   └── hyperlane/      # Hyperlane bridge deployment
│   │       ├── deploy_hyperlane.js
│   │       └── setup/      # Configuration scripts
│   ├── customCoins/        # Token deployment scripts
│   └── verify.js           # Contract verification
├── test/                   # Test files
├── .env.dev.example        # Development environment template
├── .env.prod.example       # Production environment template
├── hardhat.config.ts       # Hardhat configuration
├── package.json            # npm scripts and dependencies
```

## 🧪 Testing

The project includes comprehensive test suites:

```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/Lock.ts

# Run tests with gas reporting
REPORT_GAS=true npx hardhat test
```

## 🔧 Development Workflow

### Recommended Development Process

1. **Environment Setup**: Choose appropriate environment configuration
```bash
npm run compile:dev    # For testnet development
npm run compile:prod   # For mainnet deployment
```

2. **Testing**: Ensure all tests pass before deployment
```bash
npx hardhat test
```

3. **Deployment**: Use environment-specific npm scripts
```bash
# Example testnet deployment workflow
npm run deploy:weth:testnet
npm run deploy:wusdc:testnet
npm run deploy:bridge:testnet
```

4. **Verification**: Verify contracts on block explorer
```bash
npx hardhat run scripts/verify.js --network sei
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Contact the development team

## ⚠️ Security Considerations

- Always test on testnets before mainnet deployment
- Verify all contract addresses and configurations
- Use multisig wallets for admin operations
- Regular security audits are recommended
- Monitor validator consensus and performance