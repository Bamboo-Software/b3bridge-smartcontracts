async function setupRoutes(hyperlaneBridge, ROUTE_CONFIGURATIONS) {
  // Filter out only valid route configurations
  const validConfigurations = ROUTE_CONFIGURATIONS.filter(
    config => config.destinationDomain && config.warpRouteAddress && config.tokenAddress
  );
  
  if (validConfigurations.length === 0) {
    console.log("No valid route configurations found");
    return;
  }
  
  const domains = validConfigurations.map(r => r.destinationDomain);
  const tokenAddresses = validConfigurations.map(r => r.tokenAddress);
  const warpRouteAddresses = validConfigurations.map(r => r.warpRouteAddress);

  console.log("Setting up routes for domains:", domains);
  
  const txRoutes = await hyperlaneBridge.batchUpdateTokenRouteHyperlanes(
    domains,
    tokenAddresses,
    warpRouteAddresses
  );
  await txRoutes.wait();
  console.log("✅ Batch set token routes");
}

module.exports = { setupRoutes };
