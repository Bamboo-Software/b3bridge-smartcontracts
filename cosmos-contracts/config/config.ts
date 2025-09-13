export const bridgeConfig = {
  CCIP_ROUTER: process.env.CCIP_ROUTER,
  VALIDATORS: process.env.VALIDATORS ? process.env.VALIDATORS.split(",") : [],
  THRESHOLD: Number(process.env.THRESHOLD),
  TOKEN_MAPPING: [
    {
      tokenId: process.env.WETH_TOKEN_ID,
      tokenAddress: process.env.WETH_TOKEN_ADDRESS,
      feeRate: Number(process.env.WETH_FEE_RATE),
      fixedFee: Number(process.env.WETH_FIXED_FEE),
      decimals: Number(process.env.WETH_DECIMALS),
    },
    {
      tokenId: process.env.WUSDC_TOKEN_ID,
      tokenAddress: process.env.WUSDC_TOKEN_ADDRESS,
      feeRate: Number(process.env.WUSDC_FEE_RATE),
      fixedFee: Number(process.env.WUSDC_FIXED_FEE),
      decimals: Number(process.env.WUSDC_DECIMALS),
    },
  ],
};

export const hyperlaneConfig = {
  MAILBOX: process.env.HYPERLANE_MAILBOX,
  ROUTE_CONFIGURATIONS: [
    // ETH/Sepolia configuration
    {
      warpRouteAddress: process.env.USDT_WARP_ROUTE,
      tokenAddress: process.env.USDT_TOKEN_ADDRESS,
      destinationDomain: Number(process.env.USDT_ETH_DEST_DOMAIN),
    },
    // BSC configuration
    {
      warpRouteAddress: process.env.USDT_WARP_ROUTE,
      tokenAddress: process.env.USDT_TOKEN_ADDRESS,
      destinationDomain: Number(process.env.USDT_BSC_DEST_DOMAIN),
    }
  ],
  FEE_CONFIGURATIONS: [
    {
      tokenAddress: process.env.USDT_TOKEN_ADDRESS,
      fixedFee: process.env.USDT_FIXED_FEE,
      feeRate: Number(process.env.USDT_FEE_RATE),
      decimals: Number(process.env.USDT_DECIMALS),
    }
  ],
  MIN_FEE_BRIDGE: process.env.HYPERLANE_MIN_FEE_BRIDGE,
  MAX_FEE_BRIDGE: process.env.HYPERLANE_MAX_FEE_BRIDGE,
};

export const wethConfig = {
  decimals: Number(process.env.WETH_DECIMALS),
  contractName: process.env.WETH_CONTRACT_NAME || "WETH",
};

export const wusdcConfig = {
  decimals: Number(process.env.WUSDC_DECIMALS),
  contractName: process.env.WUSDC_CONTRACT_NAME || "WUSDC",
};