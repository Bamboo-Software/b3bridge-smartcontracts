
import * as dotenv from "dotenv";
dotenv.config();


export const bridgeConfig = {
  ETH_PRICE_ADDR: process.env.ETH_PRICE_ADDR,
  CCIP_ROUTER: process.env.CCIP_ROUTER,
  VALIDATORS: process.env.VALIDATORS ? process.env.VALIDATORS.split(",") : [],
  THRESHOLD: Number(process.env.THRESHOLD),
  HYPPERLANE_MAILBOX_ADDR: process.env.HYPERLANE_MAILBOX,
  TOKEN_MAPPING: [
    {
      tokenId: process.env.ETH_TOKEN_ID,
      tokenAddress: process.env.ETH_TOKEN_ADDRESS,
      feeRate: Number(process.env.ETH_FEE_RATE),
      fixedFee: Number(process.env.ETH_FIXED_FEE),
      decimals: Number(process.env.ETH_DECIMALS),
    },
    {
      tokenId: process.env.USDC_TOKEN_ID,
      tokenAddress: process.env.USDC_TOKEN_ADDRESS,
      feeRate: Number(process.env.USDC_FEE_RATE),
      fixedFee: Number(process.env.USDC_FIXED_FEE),
      decimals: Number(process.env.USDC_DECIMALS),
    },
  ],
  MIN_FEE: Number(process.env.USDC_FIXED_FEE),
};

export const hyperlaneConfig = {
  HYPERLANE_MAILBOX_ADDR: process.env.HYPERLANE_MAILBOX,
  ROUTE_CONFIGURATIONS: [
    // SEI Chain Route Configuration
    {
      warpRouteAddress: process.env.USDT_WARP_ROUTE,
      tokenAddress: process.env.USDT_TOKEN_ADDRESS,
      destinationDomain: Number(process.env.USDT_SEI_DEST_DOMAIN),
    },
    // BSC Chain Route Configuration
    {
      warpRouteAddress: process.env.USDT_WARP_ROUTE,
      tokenAddress: process.env.USDT_TOKEN_ADDRESS,
      destinationDomain: Number(process.env.USDT_BSC_DEST_DOMAIN),
    },
    // ETH Chain Route Configuration
    {
      warpRouteAddress: process.env.USDT_WARP_ROUTE,
      tokenAddress: process.env.USDT_TOKEN_ADDRESS,
      destinationDomain: Number(process.env.USDT_ETH_DEST_DOMAIN),
    },
  ],
  FEE_CONFIGURATIONS: [
    {
      tokenAddress: process.env.USDT_TOKEN_ADDRESS,
      fixedFee: process.env.USDT_FIXED_FEE,
      feeRate: Number(process.env.USDT_FEE_RATE),
      decimals: Number(process.env.USDT_DECIMALS),
      priceFeedAddress: process.env.USDT_PRICE_ADDR,
    },
  ],
  NATIVE_PRICE_FEED: process.env.NATIVE_PRICE_ADDR,
  MIN_FEE_BRIDGE: process.env.HYPERLANE_MIN_FEE_BRIDGE,
  MAX_FEE_BRIDGE: process.env.HYPERLANE_MAX_FEE_BRIDGE,
};