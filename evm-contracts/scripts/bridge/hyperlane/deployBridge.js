const hre = require("hardhat");

async function deployBridge(mailbox, nativePriceFeed) {
  console.log("Deploying B3HyperlaneBridge with mailbox:", mailbox, "and native price feed:", nativePriceFeed);
  const B3HyperlaneBridge = await hre.ethers.getContractFactory("B3HyperlaneBridge");
  const b3HyperlaneBridge = await B3HyperlaneBridge.deploy(mailbox, nativePriceFeed);
  await b3HyperlaneBridge.waitForDeployment();
  const bridgeAddress = await b3HyperlaneBridge.getAddress();
  console.log(`✅ B3HyperlaneBridge deployed to:`, bridgeAddress);
  return b3HyperlaneBridge;
}

module.exports = { deployBridge };
