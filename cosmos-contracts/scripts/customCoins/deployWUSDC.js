const hre = require("hardhat");
const { wusdcConfig } = require("../../config/config");
const { verify } = require("../verify");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer address:", deployer.address);

  // Deploy WUSDC
  const WUSDC = await hre.ethers.getContractFactory("WUSDC");
  const wusdc = await WUSDC.deploy();
  await wusdc.waitForDeployment();
  
  const wusdcAddress = await wusdc.getAddress();
  console.log("WUSDC contract deployed at:", wusdcAddress);

  // Mint 1 token for testing
  await wusdc.mint(deployer.address, "1000000"); // 1 WUSDC (6 decimals)
  console.log("Minted 1 token to", deployer.address);

  // Verify contract
  await verify(wusdcAddress, "WUSDC", []);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
