async function setupDomains(hyperlaneBridge, ROUTE_CONFIGURATIONS) {
  // Filter out only valid domain configurations
  const validConfigurations = ROUTE_CONFIGURATIONS.filter(
    config => config.destinationDomain && config.warpRouteAddress && config.tokenAddress
  );
  
  const uniqueDomains = [...new Set(validConfigurations.map(r => r.destinationDomain))];
  console.log("Batch enabling domains:", uniqueDomains);
  
  for (const domain of uniqueDomains) {
    try {
      console.log(`Enabling domain: ${domain}...`);
      const tx = await hyperlaneBridge.updateSupportedDomainHyperlane(domain, true);
      console.log(`Transaction sent, waiting for confirmation...`);
      await tx.wait();
      console.log(`✅ Enabled domain: ${domain}`);
      await new Promise(resolve => setTimeout(resolve, 5000));
    } catch (error) {
      console.error(`Error enabling domain ${domain}:`, error.message);
    }
  }
}

module.exports = { setupDomains };
