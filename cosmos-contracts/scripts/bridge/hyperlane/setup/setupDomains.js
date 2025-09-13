async function setupSupportedDomains(bridge, domains) {
  console.log("\n🌍 Enabling domains:", domains);
  
  for (const domainId of domains) {
    const txDomain = await bridge.updateSupportedDomainHyperlane(domainId, true);
    await txDomain.wait();
    console.log(`✅ Domain ${domainId} enabled (tx: ${txDomain.hash})`);
  }
}

module.exports = {
  setupSupportedDomains
};
