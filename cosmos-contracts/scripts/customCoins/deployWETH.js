const hre = require("hardhat");
const { wethConfig } = require("../../config/config");
const { verify } = require("../verify");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer address:", deployer.address);

  // Deploy WETH
  const WETH = await hre.ethers.getContractFactory("WETH");
  const weth = await WETH.deploy();
  await weth.waitForDeployment();
  
  const wethAddress = await weth.getAddress();
  console.log("WETH contract deployed at:", wethAddress);

  // Mint 1 token for testing
  await weth.mint(deployer.address, "1000000000000000000"); // 1 WETH
  console.log("Minted 1 token to", deployer.address);

  // Verify contract
  await verify(wethAddress, "WETH", []);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
