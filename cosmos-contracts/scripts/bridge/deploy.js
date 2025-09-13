const hre = require("hardhat");
const { bridgeConfig } = require("../../config/config.ts");
const {verify} = require("../verify");
const { setMinterBurnerRoles } = require("../customCoins/set_roles_token.js");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  const b3BridgeSei = await hre.ethers.getContractFactory("B3BridgeSei");
  const bridgeDest = await b3BridgeSei.deploy(
    bridgeConfig.CCIP_ROUTER,
    bridgeConfig.VALIDATORS,
    bridgeConfig.THRESHOLD
  );
  await bridgeDest.waitForDeployment();
  const bridgeDestAddress = await bridgeDest.getAddress();
  console.log("B3BridgeSei deployed to:", bridgeDestAddress);

  await verify(
    bridgeDestAddress,
    "B3BridgeSei",
    [bridgeConfig.CCIP_ROUTER, bridgeConfig.VALIDATORS, bridgeConfig.THRESHOLD]
  );

  for (const { tokenId, tokenAddress, feeRate, fixedFee, decimals } of bridgeConfig.TOKEN_MAPPING) {
    console.log({ tokenId, tokenAddress, feeRate, fixedFee, decimals }, "Mapping token to bridge destination");
    const tx1 = await bridgeDest.setTokenMapping(tokenId, tokenAddress);
    await tx1.wait();
    console.log(`✅ Mapped: address ${tokenAddress} ↔ tokenId ${tokenId}`, tx1.hash);

    if (feeRate !== undefined && fixedFee !== undefined && decimals !== undefined) {
      const tx3 = await bridgeDest.setFeeRate(tokenAddress, feeRate, fixedFee, decimals);
      await tx3.wait();
      console.log(`✅ Set fee rate: rate=${feeRate}, fixedFee=${fixedFee}, decimals=${decimals} (tx: ${tx3.hash})`);
    }
  }

  
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
