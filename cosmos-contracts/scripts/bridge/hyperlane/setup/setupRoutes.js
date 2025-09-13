async function setupTokenRoutes(bridge, routeConfigs) {
  console.log("\n🛣️ Setting up token routes...");
  const destinationDomainIds = [];
  const tokenAddresses = [];
  const warpRouteAddresses = [];

  // Prepare arrays for batch update
  for (const config of routeConfigs) {
    const { warpRouteAddress, tokenAddress, destinationDomain } = config;
    if (!warpRouteAddress || !tokenAddress || !destinationDomain) {
      console.log("⚠️ Skipping route with missing config:", config);
      continue;
    }
    
    destinationDomainIds.push(destinationDomain);
    tokenAddresses.push(tokenAddress);
    warpRouteAddresses.push(warpRouteAddress);
  }

  console.log("Batch updating routes:", {
    domains: destinationDomainIds,
    tokens: tokenAddresses,
    routes: warpRouteAddresses
  });

  const txBatch = await bridge.batchUpdateTokenRouteHyperlanes(
    destinationDomainIds,
    tokenAddresses,
    warpRouteAddresses
  );
  await txBatch.wait();
  console.log(`✅ Routes configured in batch (tx: ${txBatch.hash})`);

  return {
    destinationDomainIds,
    tokenAddresses,
    warpRouteAddresses
  };
}

module.exports = {
  setupTokenRoutes
};
