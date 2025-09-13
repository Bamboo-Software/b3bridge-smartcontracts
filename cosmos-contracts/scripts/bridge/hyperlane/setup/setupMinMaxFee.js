async function setupMinMaxFee(bridge, minFee, maxFee) {
  console.log("\n💰 Setting min/max bridge fees...");
  console.log({
    minFee,
    maxFee
  });

  if (!minFee && !maxFee) {
    console.log("Skipping min/max fee setup as no values provided");
    return {
      minFee: 0,
      maxFee: 0
    };
  }

  const tx = await bridge.setMinMaxFeeBridge(minFee || 0, maxFee || 0);
  await tx.wait();
  console.log(`✅ Min/max fees configured (tx: ${tx.hash})`);

  return {
    minFee: minFee || 0,
    maxFee: maxFee || 0
  };
}

module.exports = {
  setupMinMaxFee
};
