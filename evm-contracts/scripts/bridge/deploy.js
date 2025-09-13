

const hre = require("hardhat");
const { bridgeConfig } = require("../../config/deploy_config");
const { verify } = require("../verify");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deploying B3BridgeETH with account:`, deployer.address);

  const {
    CCIP_ROUTER,
    VALIDATORS,
    THRESHOLD,
    TOKEN_MAPPING,
    ETH_PRICE_ADDR,
    MIN_FEE,
  } = bridgeConfig;

  const NativeBridge = await hre.ethers.getContractFactory("B3BridgeETH");
  const nativeBridge = await NativeBridge.deploy(
    CCIP_ROUTER,
    VALIDATORS,
    THRESHOLD,
    ETH_PRICE_ADDR,
  );
  await nativeBridge.waitForDeployment();
  const bridgeAddress = await nativeBridge.getAddress();
  console.log(`✅ B3BridgeETH deployed to:`, bridgeAddress);

await verify(
    bridgeAddress,
    "B3BridgeETH",
    [CCIP_ROUTER, VALIDATORS, THRESHOLD, ETH_PRICE_ADDR]
  );
  // Setup Token Mappings and Fees
  console.log("\nConfiguring tokens and fees...");
  for (const { tokenId, tokenAddress, feeRate, fixedFee, decimals } of TOKEN_MAPPING) {
    const tx1 = await nativeBridge.setTokenAddressToId(tokenAddress, tokenId);
    await tx1.wait();
    console.log(`✅ Mapped token address ${tokenAddress} → tokenId ${tokenId}`);

    const tx2 = await nativeBridge.setTokenMapping(tokenId, tokenAddress);
    await tx2.wait();
    console.log(`✅ Mapped tokenId ${tokenId} → token address ${tokenAddress}`);

    if (feeRate !== undefined && fixedFee !== undefined && decimals !== undefined) {
      const tx3 = await nativeBridge.setFeeRate(tokenAddress, feeRate, fixedFee, decimals);
      await tx3.wait();
      console.log(`✅ Set fee rate: rate=${feeRate}, fixedFee=${fixedFee}, decimals=${decimals}`);
    }
  }

  // Set Minimum Fee
  if (MIN_FEE !== undefined) {
    const txMinFee = await nativeBridge.setMinFee(MIN_FEE);
    await txMinFee.wait();
    console.log(`✅ Set minFee: ${MIN_FEE}`);
  }

  // Verify Contract
  console.log("\n🎉 B3BridgeETH deployment and setup completed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
