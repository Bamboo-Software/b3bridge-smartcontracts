const { ethers } = require("hardhat");

async function main() {
  console.log("Checking NativeBridge functions...");
  
  const [owner] = await ethers.getSigners();
  
  // Deploy mock contracts
  const MockRouter = await ethers.getContractFactory("MockCCIPRouter");
  const mockRouter = await MockRouter.deploy();
  
  const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");
  const mockPriceFeed = await MockPriceFeed.deploy(8, 200000000000);
  
  // Deploy NativeBridge
  const NativeBridge = await ethers.getContractFactory("NativeBridge");
  const nativeBridge = await NativeBridge.deploy(
    mockRouter.target,
    [owner.address],
    1,
    mockPriceFeed.target
  );
  
  console.log("NativeBridge deployed at:", nativeBridge.target);
  
  // Check available functions
  console.log("Checking if getFeeBridge exists...");
  try {
    await nativeBridge.getFeeBridge.staticCall(ethers.ZeroAddress, ethers.parseEther("1"));
    console.log("✅ getFeeBridge function exists");
  } catch (error) {
    console.log("❌ getFeeBridge error:", error.message);
  }
  
  console.log("Checking price feed functions...");
  try {
    await nativeBridge.setFallbackPrice.staticCall(ethers.keccak256(ethers.toUtf8Bytes("TEST")), 100000000);
    console.log("✅ setFallbackPrice function exists");
  } catch (error) {
    console.log("❌ setFallbackPrice error:", error.message);
  }
}

main().catch(console.error);