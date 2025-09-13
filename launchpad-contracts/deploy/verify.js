const hre = require("hardhat");

async function main() {
  const contractAddress = process.env.CONTRACT_ADDRESS;
  const constructorArgs = JSON.parse(process.env.CONSTRUCTOR_ARGS || "[]");

  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: constructorArgs,
    });
    console.log("Verify successed");
  } catch (e) {
    console.error("Verify failed:", e.message);
    process.exit(1);
  }
}

main();
