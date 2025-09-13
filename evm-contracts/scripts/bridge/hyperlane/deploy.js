const { deployBridge } = require("./deployBridge");
const { setupDomains } = require("./setupDomains");
const { setupRoutes } = require("./setupRoutes");
const { setupFees } = require("./setupFees");
const { setupPriceFeeds } = require("./setupPriceFeeds");
const { verify } = require("../../verify");
const hre = require("hardhat");
const { hyperlaneConfig } = require("../../../config/deploy_config");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const networkName = hre.network.name;
  console.log(`Deploying B3HyperlaneBridge on ${networkName} with account: ${deployer.address}`);

  const {
    HYPERLANE_MAILBOX_ADDR,
    ROUTE_CONFIGURATIONS,
    FEE_CONFIGURATIONS,
    NATIVE_PRICE_FEED,
    MIN_FEE_BRIDGE,
    MAX_FEE_BRIDGE
  } = hyperlaneConfig;


  // Deploy contract
  const hyperlaneBridge = await deployBridge(HYPERLANE_MAILBOX_ADDR, NATIVE_PRICE_FEED);
  const bridgeAddress = await hyperlaneBridge.getAddress();

  // Verify contract
  await verify(bridgeAddress, "B3HyperlaneBridge", [HYPERLANE_MAILBOX_ADDR, NATIVE_PRICE_FEED]);
  
  // Set min/max fee bridge
  if (MIN_FEE_BRIDGE && MAX_FEE_BRIDGE) {
    const tx = await hyperlaneBridge.setMinMaxFeeBridge(MIN_FEE_BRIDGE, MAX_FEE_BRIDGE);
    await tx.wait();
    console.log(`✅ Set min/max fee bridge:`, MIN_FEE_BRIDGE, MAX_FEE_BRIDGE);
  }

  // Setup domains
  await setupDomains(hyperlaneBridge, ROUTE_CONFIGURATIONS);

  // Setup routes
  await setupRoutes(hyperlaneBridge, ROUTE_CONFIGURATIONS);

  // Setup fees
  await setupFees(hyperlaneBridge, FEE_CONFIGURATIONS);

  // Setup price feeds
  await setupPriceFeeds(hyperlaneBridge, FEE_CONFIGURATIONS);


  console.log(`\n🎉 B3HyperlaneBridge deployment and setup completed!`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
