<p align="center">
  <img alt="Bamboo Logo" style="width: 200px" src="https://via.placeholder.com/200x100/4CAF50/FFFFFF?text=BAMBOO"/>
</p>

<h1 align="center">Bamboo Cross-Chain Token & Launchpad</h1>

<p align="center">Bamboo is a cross-chain token ecosystem built on <a href="https://docs.layerzero.network/v2/concepts/applications/oft-standard">LayerZero OFT</a> protocol, featuring seamless token transfers across multiple blockchains and a comprehensive presale launchpad system.</p>

<p align="center">
 <a href="https://docs.layerzero.network/" style="color: #a77dff">LayerZero Docs</a> |
 <a href="https://bamboo.finance" style="color: #4CAF50">Bamboo Finance</a>
</p>

## Table of Contents

- [Features](#features)
- [Smart Contracts](#smart-contracts)
- [Requirements](#requirements)
- [Setup](#setup)
- [Build & Compilation](#build--compilation)
- [Testing](#testing)
- [Deployment](#deployment)
- [Cross-Chain Configuration](#cross-chain-configuration)
- [Usage Examples](#usage-examples)
- [Supported Networks](#supported-networks)
- [Gas Profiling](#gas-profiling)
- [Development Tools](#development-tools)
- [Production Checklist](#production-checklist)
- [Troubleshooting](#troubleshooting)

## Features

🌐 **Cross-Chain Token**: BambooOFT enables seamless token transfers across multiple blockchains using LayerZero v2
🚀 **Presale Launchpad**: Comprehensive presale system supporting both native tokens (ETH/BNB/AVAX) and ERC20 payments
🔒 **Security First**: Built with OpenZeppelin standards, reentrancy protection, and controlled minting
💎 **Multi-Chain Support**: Ethereum, BSC, Avalanche (mainnet and testnet)
⚡ **Gas Optimized**: Foundry-optimized contracts with extensive gas profiling tools
🎯 **Production Ready**: Complete deployment scripts, verification, and monitoring tools

## Smart Contracts

### BambooOFT
**Location**: `contracts/BambooOFT.sol`

An Omnichain Fungible Token (OFT) that extends LayerZero's OFT standard with additional features:
- **Controlled Minting**: Owner-only minting with finalization mechanism
- **Batch Operations**: Efficient batch minting to multiple addresses
- **Auto-Deployment**: Automatically mints total supply to delegate on deployment
- **Supply Management**: Track current supply, max supply, and minting status

**Key Features**:
- Cross-chain transfers via LayerZero protocol
- Mintable with owner controls
- Batch minting capabilities
- Finalization mechanism to lock minting
- Supply tracking and reporting

### BambooPresale
**Location**: `contracts/BambooPresale.sol`

A comprehensive presale contract for token distribution with advanced features:
- **Dual Payment Support**: Accept native tokens (ETH/BNB/AVAX) or ERC20 tokens (USDT)
- **Soft/Hard Cap**: Configurable funding targets with automatic refunds
- **Time-Bounded**: Start/end time controls with automatic validation
- **Single Contribution**: One contribution per address to ensure fair distribution
- **Claim System**: Secure token claiming after successful presale
- **Fee Structure**: Built-in 2% system fee on successful campaigns

**Key Features**:
- Native token or ERC20 payment options
- Soft cap/hard cap mechanism
- Time-bounded campaigns
- Anti-reentrancy protection
- Single contribution per address
- Automatic refunds on failure
- Emergency withdrawal functions

## Requirements

- `Node.js` >= 18.16.0
- `pnpm` (recommended) - or npm/yarn
- `forge` (optional) >= 0.2.0 for Foundry testing and compilation

## Setup

1. **Clone the repository**:
```bash
git clone <repository-url>
cd launchpad-contracts
```

2. **Install dependencies**:
```bash
pnpm install
```

3. **Environment setup**:
```bash
cp .env.example .env
```

4. **Configure your environment variables**:
```env
# Deployer account (choose one)
MNEMONIC="your twelve word mnemonic phrase here"
# OR
PRIVATE_KEY="0xYourPrivateKeyHere"

# RPC URLs (optional - defaults provided)
RPC_URL_ETHEREUM="https://ethereum-rpc.publicnode.com"
RPC_URL_BSC="https://bsc-rpc.publicnode.com"
RPC_URL_AVALANCHE="https://avalanche-c-chain-rpc.publicnode.com"

# Testnet RPCs
RPC_URL_SEPOLIA="https://ethereum-sepolia-rpc.publicnode.com"
RPC_URL_BSC_TESTNET="https://bsc-testnet-rpc.publicnode.com"
RPC_URL_AVALANCHE_TESTNET="https://avalanche-fuji-c-chain-rpc.publicnode.com"

# API Keys for verification
ETHERSCAN_API_KEY="your-etherscan-api-key"
```

5. **Fund your deployer account** with native tokens of the chains you want to deploy to.

## Build & Compilation

This project supports both Hardhat and Foundry compilation for maximum flexibility:

**Compile both (recommended)**:
```bash
pnpm compile
```

**Compile individually**:
```bash
pnpm compile:hardhat    # Hardhat compilation
pnpm compile:forge      # Foundry compilation
```

**Clean build artifacts**:
```bash
pnpm clean
```

## Testing

Run comprehensive tests with both Hardhat and Foundry:

**All tests**:
```bash
pnpm test
```

**Individual test suites**:
```bash
pnpm test:hardhat      # Hardhat tests
pnpm test:forge        # Foundry tests
```

**Test files**:
- `test/foundry/BambooOFT.t.sol` - BambooOFT contract tests
- `test/foundry/BambooPresale.t.sol` - BambooPresale contract tests

## Deployment

### Deploy BambooOFT

Deploy the cross-chain token to your desired networks:

```bash
pnpm hardhat lz:deploy --tags BambooOFT
```

This will deploy BambooOFT with:
- Name: "BambooOFT"
- Symbol: "BBOFT"
- Total Supply: 1,000,000 tokens (automatically minted to deployer)

### Deploy BambooPresale

The presale contract deployment requires custom parameters. Modify `deploy/BambooPresale.ts` with your specific values:

```typescript
const presaleTokenAddress = '0x...' // Your BambooOFT address
const paymentToken = '0x...'        // USDT address (or address(0) for native)
const targetAmount = '1000'         // Target funding amount
const softCap = '500'              // Minimum funding threshold
// ... other parameters
```

Then deploy:
```bash
pnpm hardhat deploy --tags BambooPresale --network <network-name>
```

## Cross-Chain Configuration

After deploying BambooOFT to multiple chains, configure cross-chain messaging:

### 1. Update LayerZero Configuration

Modify `layerzero.config.ts` for your specific chains:

```typescript
const ethContract: OmniPointHardhat = {
    eid: EndpointId.ETHEREUM_V2_MAINNET,
    contractName: 'BambooOFT',
}

const bscContract: OmniPointHardhat = {
    eid: EndpointId.BSC_V2_MAINNET,
    contractName: 'BambooOFT',
}
```

### 2. Wire Cross-Chain Connections

Configure the pathways between deployed contracts:

```bash
pnpm hardhat lz:oapp:wire --oapp-config layerzero.config.ts
```

This will set up:
- Peer relationships between chains
- DVN configurations for security
- Gas settings for cross-chain execution

### 3. Verify Configuration

Check that your configuration is correct:

```bash
pnpm hardhat lz:oapp:config:get --oapp-config layerzero.config.ts
```

## Usage Examples

### Cross-Chain Token Transfer

Send BambooOFT tokens from one chain to another:

```bash
# Send 100 BBOFT from Ethereum to BSC
pnpm hardhat lz:oft:send \
  --src-eid 30101 \
  --dst-eid 30102 \
  --amount 100 \
  --to 0xRecipientAddress
```

### Presale Operations

1. **Start a presale**:
```solidity
// Deploy presale with your parameters
// Users contribute with contribute(amount) function
```

2. **Contribute to presale**:
```solidity
// For native token payments
presaleContract.contribute{value: 1 ether}(1 ether);

// For ERC20 payments (approve first)
usdtContract.approve(presaleAddress, amount);
presaleContract.contribute(amount);
```

3. **Claim tokens after successful presale**:
```solidity
presaleContract.claimTokens();
```

## Supported Networks

Bamboo supports the following networks:

### Mainnet
| Network | Chain ID | LayerZero EID | Status |
|---------|----------|---------------|---------|
| Ethereum | 1 | 30101 | ✅ Supported |
| BSC | 56 | 30102 | ✅ Supported |
| Avalanche | 43114 | 30106 | ✅ Supported |

### Testnet
| Network | Chain ID | LayerZero EID | Status |
|---------|----------|---------------|---------|
| Sepolia | 11155111 | 40161 | ✅ Supported |
| BSC Testnet | 97 | 40102 | ✅ Supported |
| Avalanche Fuji | 43113 | 40106 | ✅ Supported |

## Gas Profiling

Optimize gas costs for cross-chain operations:

**Profile lzReceive gas usage**:
```bash
pnpm gas:lzReceive <rpcUrl> <endpointAddress> <srcEid> <sender> <dstEid> <receiver> <message> <msgValue> <numOfRuns>
```

**Profile lzCompose gas usage**:
```bash
pnpm gas:lzCompose <rpcUrl> <endpointAddress> <srcEid> <sender> <dstEid> <receiver> <composer> <composeMsg> <msgValue> <numOfRuns>
```

## Development Tools

### Code Quality
```bash
pnpm lint              # Lint JavaScript/TypeScript and Solidity
pnpm lint:js           # JavaScript/TypeScript only
pnpm lint:sol          # Solidity only
pnpm lint:fix          # Auto-fix issues
```

### Contract Verification
```bash
pnpm dlx @layerzerolabs/verify-contract -n <NETWORK> -u <API_URL> -k <API_KEY> --contracts <CONTRACT_NAME>
```

### LayerZero Helper Tasks
```bash
# Get configuration details
pnpm hardhat lz:oapp:config:get --oapp-config layerzero.config.ts

# Get executor configuration
pnpm hardhat lz:oapp:config:get:executor --oapp-config layerzero.config.ts

# Initialize config file
pnpm hardhat lz:oapp:config:init --contract-name BambooOFT --oapp-config layerzero.config.ts
```

## Production Checklist

Before deploying to production:

✅ **Security**
- [ ] Use `BambooOFT` (not `BambooOFTMock`) in production
- [ ] Set proper DVN configurations
- [ ] Test all cross-chain pathways on testnet
- [ ] Verify contracts on block explorers

✅ **Gas Optimization**
- [ ] Profile gas usage for `lzReceive` on all destination chains
- [ ] Set appropriate gas limits in LayerZero config
- [ ] Test with various message sizes

✅ **Presale Setup**
- [ ] Verify all presale parameters
- [ ] Test deposit/contribution/claim flows
- [ ] Set up proper multisig for system wallet
- [ ] Configure emergency procedures

✅ **Monitoring**
- [ ] Set up LayerZero Scan monitoring
- [ ] Configure alerts for failed transactions
- [ ] Monitor gas costs and optimize as needed

## Troubleshooting

### Common Issues

**LayerZero Configuration Errors**:
- Ensure endpoint IDs match your target networks
- Verify DVN configurations are correct
- Check that contracts are deployed before wiring

**Cross-Chain Transfer Failures**:
- Verify sufficient gas limits in LayerZero config
- Check token approvals and balances
- Monitor LayerZero Scan for transaction status

**Presale Issues**:
- Ensure tokens are deposited before contributions
- Check contribution limits and timing
- Verify payment token approvals (for ERC20 payments)

### Debugging Resources
- [LayerZero Debugging Guide](https://docs.layerzero.network/v2/developers/evm/troubleshooting/debugging-messages)
- [Error Codes & Handling](https://docs.layerzero.network/v2/developers/evm/troubleshooting/error-messages)
- [LayerZero Scan](https://layerzeroscan.com/) - Transaction monitoring

---

<p align="center">
  <strong>Bamboo Finance</strong> - Building the Future of Cross-Chain DeFi
</p>

<p align="center">
  <a href="https://layerzero.network/community" style="color: #a77dff">LayerZero Community</a> |
  <a href="https://docs.layerzero.network/" style="color: #a77dff">LayerZero Docs</a> |
  <a href="https://bamboo.finance" style="color: #4CAF50">Bamboo Finance</a>
</p>

## Advanced Configuration

### Adding New Chains

To add support for additional EVM chains:

1. **Update `hardhat.config.ts`**:
```typescript
networks: {
  'new-chain': {
    eid: EndpointId.NEW_CHAIN_V2_MAINNET,
    url: process.env.RPC_URL_NEW_CHAIN,
    accounts,
    chainId: 12345,
  }
}
```

2. **Update `layerzero.config.ts`**:
```typescript
const newChainContract: OmniPointHardhat = {
    eid: EndpointId.NEW_CHAIN_V2_MAINNET,
    contractName: 'BambooOFT',
}
```

3. **Re-run wiring**:
```bash
pnpm hardhat lz:oapp:wire --oapp-config layerzero.config.ts
```

### Using Multisigs

For production deployments with Safe multisigs:

```typescript
// hardhat.config.ts
networks: {
  ethereum: {
    /* ... */
    safeConfig: {
      safeUrl: 'https://safe-transaction-mainnet.safe.global/',
      safeAddress: '0xYourMultisigAddress'
    }
  }
}
```

Then use the `--safe` flag:
```bash
pnpm hardhat lz:oapp:wire --safe --oapp-config layerzero.config.ts
```
