const hre = require("hardhat");

function toQualifiedName(contractName) {
  // If already fully qualified, return as is
  if (contractName && contractName.includes(":")) return contractName;
  // Otherwise, format as contracts/ContractName.sol:ContractName
  if (contractName) {
    return `contracts/${contractName}.sol:${contractName}`;
  }
  return undefined;
}

async function verify(address = '', contractName = '', constructorArguments = []) {
  const verifyParams = {
    address,
    constructorArguments,
  };
  const qualified = toQualifiedName(contractName);
  if (qualified) {
    verifyParams.contract = qualified;
  }
  try {
    await hre.run("verify:verify", verifyParams);
    console.log(`Verification submitted for ${qualified || contractName} at:`, address);
  } catch (error) {
    console.log(`Verification failed for ${qualified || contractName} at:`, address, error);
  }
}

module.exports = { verify };
