async function setupFees(hyperlaneBridge, FEE_CONFIGURATIONS) {
  const feeTokenAddresses = FEE_CONFIGURATIONS.map(f => f.tokenAddress);
  const fixedFees = FEE_CONFIGURATIONS.map(f => f.fixedFee);
  const feeRates = FEE_CONFIGURATIONS.map(f => f.feeRate);
  const decimalsArray = FEE_CONFIGURATIONS.map(f => f.decimals);

  const txFees = await hyperlaneBridge.batchUpdateTokenFeeConfigs(
    feeTokenAddresses,
    fixedFees,
    feeRates,
    decimalsArray
  );
  await txFees.wait();
  console.log("✅ Batch set token fee configs");
}

module.exports = { setupFees };
