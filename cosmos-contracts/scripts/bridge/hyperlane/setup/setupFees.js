async function setupTokenFees(bridge, feeConfigs) {
  console.log("\n📊 Setting up token fees...");

  // Prepare arrays for batch update
  const tokenAddresses = [];
  const fixedFees = [];
  const feeRates = [];
  const decimalsArray = [];

  // Extract fee configurations
  for (const config of feeConfigs) {
    const { tokenAddress, fixedFee, feeRate, decimals } = config;
    if (!tokenAddress) {
      console.log("⚠️ Skipping fee config with missing token address");
      continue;
    }
    
    tokenAddresses.push(tokenAddress);
    fixedFees.push(fixedFee || 0);
    feeRates.push(feeRate || 0);
    decimalsArray.push(decimals || 18);
  }

  console.log(`Setting fees for ${tokenAddresses.length} tokens:`, {
    tokens: tokenAddresses,
    fixedFees,
    feeRates,
    decimals: decimalsArray
  });

  const tx = await bridge.batchUpdateTokenFeeConfigs(
    tokenAddresses,
    fixedFees,
    feeRates,
    decimalsArray
  );
  await tx.wait();
  console.log(`✅ Token fees configured (tx: ${tx.hash})`);

  return {
    tokenCount: tokenAddresses.length
  };
}

module.exports = {
  setupTokenFees
};
