import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();
const config = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
      evmVersion: "paris",
    },
  },
  networks: {
    seimainnet: {
      url: 'https://evm-rpc.sei-apis.com',
      accounts: [process.env.PRIVATE_KEY!],
      chainId: 1329,
      gasPrice: 'auto'
    },
    sei: {
      url: process.env.SEI_RPC_URL,
      chainId: 1328,
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey: {
      seimainnet: process.env.SEI_EXPLORER_API_KEY,
      sei: process.env.SEI_EXPLORER_API_KEY,
    },
    customChains: [
      {
        network: "sei",
        chainId: 1328,
        urls: {
          apiURL: "https://seitrace.com/atlantic-2/api",
          browserURL: process.env.SEI_BROWSER_URL || "https://seitrace.com/atlantic-2/",
        },
      },
      {
        network: "sei",
        chainId: 1329,
        urls: {
          apiURL: "https://seitrace.com/pacific-1/api",
          browserURL: process.env.SEI_BROWSER_URL || "https://seitrace.com/pacific-1/",
        },
      },
    ],
  },
};

export default config;
