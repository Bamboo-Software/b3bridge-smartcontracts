async function setupPriceFeeds(hyperlaneBridge, FEE_CONFIGURATIONS) {
  if (FEE_CONFIGURATIONS.some(f => f.priceFeedAddress)) {
    const priceFeedTokenAddresses = FEE_CONFIGURATIONS.map(f => f.tokenAddress);
    const priceFeedAddresses = FEE_CONFIGURATIONS.map(f => f.priceFeedAddress || "0x0000000000000000000000000000000000000000");
    const txPriceFeeds = await hyperlaneBridge.batchSetTokenPriceFeeds(
      priceFeedTokenAddresses,
      priceFeedAddresses
    );
    await txPriceFeeds.wait();
    console.log("✅ Batch set token price feeds");
  }
}

module.exports = { setupPriceFeeds };
