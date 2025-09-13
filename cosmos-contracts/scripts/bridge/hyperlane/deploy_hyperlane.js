const hre = require("hardhat");
const { hyperlaneConfig } = require("../../../config/config");
const { verify } = require("../../verify");
const { setupSupportedDomains } = require("./setup/setupDomains");
const { setupTokenRoutes } = require("./setup/setupRoutes"); 
const { setupTokenFees } = require("./setup/setupFees");
const { setupMinMaxFee } = require("./setup/setupMinMaxFee");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deploying B3HyperlaneBridge with account:`, deployer.address);

  const { MAILBOX, ROUTE_CONFIGURATIONS, FEE_CONFIGURATIONS, MIN_FEE_BRIDGE, MAX_FEE_BRIDGE } = hyperlaneConfig;

  // Validate config
  console.log("🔍 Validating config...");
  console.log("Mailbox:", MAILBOX);
  console.log("Routes:", ROUTE_CONFIGURATIONS.length);
  console.log("Fee configs:", FEE_CONFIGURATIONS.length);
  console.log("Min fee:", MIN_FEE_BRIDGE);
  console.log("Max fee:", MAX_FEE_BRIDGE);

  if (!MAILBOX) {
    throw new Error("MAILBOX address is required");
  }

  // Deploy B3HyperlaneBridge contract
  console.log("\n📄 Deploying B3HyperlaneBridge contract...");
  const HyperlaneBridge = await hre.ethers.getContractFactory("B3HyperlaneBridge");
  const hyperlaneBridge = await HyperlaneBridge.deploy(MAILBOX);
  await hyperlaneBridge.waitForDeployment();
  
  const bridgeAddress = await hyperlaneBridge.getAddress();
  console.log(`✅ B3HyperlaneBridge deployed to:`, bridgeAddress);

  // Verify contract
  await verify(bridgeAddress, "B3HyperlaneBridge", [MAILBOX]);

  // Enable domains
  const uniqueDomains = [...new Set(ROUTE_CONFIGURATIONS.map(r => r.destinationDomain))];
  await setupSupportedDomains(hyperlaneBridge, uniqueDomains);

  // Setup token routes
  const routes = await setupTokenRoutes(hyperlaneBridge, ROUTE_CONFIGURATIONS);

  // Setup token fees
  const fees = await setupTokenFees(hyperlaneBridge, FEE_CONFIGURATIONS);

  // Setup min/max fees
  const minMaxFees = await setupMinMaxFee(hyperlaneBridge, MIN_FEE_BRIDGE, MAX_FEE_BRIDGE);

  // Summary
  console.log(`\n🎉 B3HyperlaneBridge setup completed!`);
  console.log(`📋 Summary:`);
  console.log(`   - Contract: ${bridgeAddress}`);
  console.log(`   - Network: ${hre.network.name}`);
  console.log(`   - Domains enabled: ${uniqueDomains.join(", ")}`);
  console.log(`   - Routes configured: ${routes.destinationDomainIds.length}`);
  console.log(`   - Fees configured: ${fees.tokenCount} tokens`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});