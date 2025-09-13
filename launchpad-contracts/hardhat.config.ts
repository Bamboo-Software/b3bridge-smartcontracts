// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import 'dotenv/config'

import 'hardhat-deploy'
import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
import '@layerzerolabs/toolbox-hardhat'
import { HardhatUserConfig } from 'hardhat/config'
import { HttpNetworkAccountsUserConfig } from 'hardhat/types'

import '@nomicfoundation/hardhat-verify'

import { EndpointId } from '@layerzerolabs/lz-definitions'

import './tasks/sendOFT'

// Extend HardhatUserConfig to include etherscan
declare module 'hardhat/config' {
    interface HardhatUserConfig {
        etherscan?: {
            apiKey?: Record<string, string>
            customChains?: Array<{
                network: string
                chainId: number
                urls: {
                    apiURL: string
                    browserURL: string
                }
            }>
        }
    }
}

// Set your preferred authentication method
//
// If you prefer using a mnemonic, set a MNEMONIC environment variable
// to a valid mnemonic
const MNEMONIC = process.env.MNEMONIC

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const PRIVATE_KEY = process.env.PRIVATE_KEY

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
    ? { mnemonic: MNEMONIC }
    : PRIVATE_KEY
      ? [PRIVATE_KEY]
      : undefined

if (accounts == null) {
    console.warn(
        'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}

const config: HardhatUserConfig = {
    paths: {
        cache: 'cache/hardhat',
    },
    solidity: {
        compilers: [
            {
                version: '0.8.22',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        eth: {
            eid: EndpointId.ETHEREUM_V2_MAINNET, // Endpoint ID cho Sepolia từ LayerZero
            url: process.env.RPC_URL_ETHEREUM || 'https://ethereum-rpc.publicnode.com',
            accounts,
            chainId: 1,
        },
        bsc: {
            eid: EndpointId.BSC_V2_MAINNET, // Endpoint ID cho Sepolia từ LayerZero
            url: process.env.RPC_URL_BSC || 'https://bsc-rpc.publicnode.com',
            accounts,
            chainId: 56,
        },
        avalanche: {
            eid: EndpointId.AVALANCHE_V2_MAINNET, // Endpoint ID cho Sepolia từ LayerZero
            url: process.env.RPC_URL_AVALANCHE || 'https://avalanche-c-chain-rpc.publicnode.com',
            accounts,
            chainId: 43114,
        },
        'eth-testnet': {
            eid: EndpointId.SEPOLIA_V2_TESTNET, // Endpoint ID cho Sepolia từ LayerZero
            url: process.env.RPC_URL_SEPOLIA || 'https://ethereum-sepolia-rpc.publicnode.com',
            accounts,
            chainId: 11155111,
        },
        'bsc-testnet': {
            eid: EndpointId.BSC_V2_TESTNET, // Endpoint ID cho Sepolia từ LayerZero
            url: process.env.RPC_URL_BSC_TESTNET || 'https://bsc-testnet-rpc.publicnode.com',
            accounts,
            chainId: 97,
        },
        'avalanche-testnet': {
            eid: EndpointId.AVALANCHE_V2_TESTNET, // Endpoint ID cho Sepolia từ LayerZero
            url: process.env.RPC_URL_AVALANCHE_TESTNET || 'https://avalanche-fuji-c-chain-rpc.publicnode.com',
            accounts,
        },
        hardhat: {
            // Need this for testing because TestHelperOz5.sol is exceeding the compiled contract size limit
            allowUnlimitedContractSize: true,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0, // wallet address of index[0], of the mnemonic in .env
        },
    },
    etherscan: {
        apiKey: {
            'eth-testnet': process.env.ETHERSCAN_API_KEY!,
        },
        customChains: [
            {
                network: 'eth-testnet',
                chainId: 11155111,
                urls: {
                    apiURL: 'https://api-sepolia.etherscan.io/api',
                    browserURL: 'https://sepolia.etherscan.io',
                },
            },
        ],
    },
}

export default config
