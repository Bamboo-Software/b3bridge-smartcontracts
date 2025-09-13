import "@nomicfoundation/hardhat-verify";
import * as dotenv from "dotenv";
import { HardhatUserConfig } from 'hardhat/types';
import "@nomicfoundation/hardhat-ethers";
dotenv.config();
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100,
      },
      viaIR: true,
      evmVersion: "paris",
    },
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY!],
    },
    ethereum: {
      url: process.env.ETHEREUM_RPC_URL || `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      chainId: 1,
      accounts: [process.env.PRIVATE_KEY!],
    },
    bsc: {
      url: process.env.BSC_RPC_URL || "https://bsc-dataseed.binance.org/",
      chainId: 56,
      accounts: [process.env.PRIVATE_KEY!],
    },
    bscTestnet: {
      url: process.env.BSC_TESTNET_RPC_URL || "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey:  process.env.ETHERSCAN_API_KEY,
    customChains:[
      {
        network: "bsc",
        chainId: 56,
        urls: {
          apiURL: process.env.BSC_API_URL || "https://api.bscscan.com/api",
          browserURL: "https://bscscan.com",
        }
      },  
      {
        network: "bscTestnet",
        chainId: 97,
        urls: {
          apiURL: process.env.BSC_TESTNET_API_URL || "https://api-testnet.bscscan.com/api",
          browserURL: "https://testnet.bscscan.com",
        }
      },
      {
        network: "sepolia",
        chainId: 11155111,
        urls: {
          apiURL: process.env.SEPOLIA_API_URL || "https://api-sepolia.etherscan.io/api",
          browserURL: "https://sepolia.etherscan.io",
        }
      },
      {
        network: "ethereum",
        chainId: 1,
        urls: {
          apiURL: process.env.ETHEREUM_API_URL || "https://api.etherscan.io/api",
          browserURL: "https://etherscan.io",
        }
      }
    ]
  },
};

export default config;
