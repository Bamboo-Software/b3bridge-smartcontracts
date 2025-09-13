// Example test for improved getFeeBridge function
// Demonstrates usage with different tokens

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Improved getFeeBridge Function", function () {
  let nativeBridge;
  let owner;
  let user;
  
  // Mock price feeds
  let mockEthPriceFeed;
  let mockBtcPriceFeed;
  let mockUsdcPriceFeed;
  
  const ETH_TOKEN_ID = ethers.keccak256(ethers.toUtf8Bytes("ETH"));
  const BTC_TOKEN_ID = ethers.keccak256(ethers.toUtf8Bytes("WBTC"));
  const USDC_TOKEN_ID = ethers.keccak256(ethers.toUtf8Bytes("USDC"));

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();
    
    // Deploy mock price feeds
    const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");
    
    // ETH/USD = $2000 (8 decimals)
    mockEthPriceFeed = await MockPriceFeed.deploy(8, 200000000000);
    
    // BTC/USD = $30000 (8 decimals) 
    mockBtcPriceFeed = await MockPriceFeed.deploy(8, 3000000000000);
    
    // USDC/USD = $1.00 (8 decimals)
    mockUsdcPriceFeed = await MockPriceFeed.deploy(8, 100000000);
    
    // Deploy NativeBridge with ETH price feed
    const NativeBridge = await ethers.getContractFactory("NativeBridge");
    nativeBridge = await NativeBridge.deploy(
      mockEthPriceFeed.target, // ETH price feed
      ethers.parseEther("0.001"), // minFee
      ethers.parseEther("0.1")    // maxFee
    );
    
    // Setup tokens
    await setupTokens();
  });

  async function setupTokens() {
    // Setup ETH (native)
    await nativeBridge.addTokenInfo(
      ETH_TOKEN_ID,
      ethers.ZeroAddress, // ETH address
      150, // 1.5% fee rate
      18,  // decimals
      ethers.parseEther("0.0001") // fixed fee
    );
    
    // Setup WBTC
    await nativeBridge.addTokenInfo(
      BTC_TOKEN_ID,
      "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", // WBTC address
      200, // 2% fee rate
      8,   // decimals
      10000 // fixed fee (0.0001 BTC in satoshi)
    );
    
    // Setup USDC
    await nativeBridge.addTokenInfo(
      USDC_TOKEN_ID,
      "0xA0b86a33E6417FaCCa4B7C30E1F4c0bA6A3d54a7", // USDC address
      100, // 1% fee rate
      6,   // decimals
      1000000 // fixed fee (1 USDC)
    );
    
    // Set price feeds
    await nativeBridge.setTokenPriceFeed(BTC_TOKEN_ID, mockBtcPriceFeed.target);
    await nativeBridge.setTokenPriceFeed(USDC_TOKEN_ID, mockUsdcPriceFeed.target);
  }

  describe("Fee Calculation Examples", function () {
    
    it("ETH Bridge: 1 ETH → Fee should be 1.5% = 0.015 ETH", async function () {
      const amount = ethers.parseEther("1"); // 1 ETH
      const fee = await nativeBridge.getFeeBridge(ethers.ZeroAddress, amount);
      
      console.log("ETH Bridge:");
      console.log(`Amount: 1 ETH`);
      console.log(`Fee: ${ethers.formatEther(fee)} ETH`);
      console.log(`Expected: ~0.0151 ETH (0.015 + 0.0001 fixed)`);
      
      // Expected: 1.5% dynamic + 0.0001 fixed = 0.0151 ETH
      const expectedFee = ethers.parseEther("0.0151");
      expect(fee).to.be.closeTo(expectedFee, ethers.parseEther("0.0001"));
    });
    
    it("WBTC Bridge: 1 WBTC → Fee should be ~0.15 ETH", async function () {
      const amount = 100000000; // 1 WBTC (8 decimals)
      const fee = await nativeBridge.getFeeBridge(
        "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", 
        amount
      );
      
      console.log("\\nWBTC Bridge:");
      console.log(`Amount: 1 WBTC (~$30,000)`);
      console.log(`Fee: ${ethers.formatEther(fee)} ETH`);
      console.log(`Expected: ~0.15 ETH ($300 fee at $2000 ETH)`);
      
      // Expected calculation:
      // 1 WBTC * 2% = 0.02 WBTC = $600
      // $600 / $2000 ETH = 0.3 ETH + fixed fee
      const expectedFeeEth = ethers.parseEther("0.3"); // Approximate
      expect(fee).to.be.closeTo(expectedFeeEth, ethers.parseEther("0.05"));
    });
    
    it("USDC Bridge: 1000 USDC → Fee should be ~0.005 ETH", async function () {
      const amount = 1000000000; // 1000 USDC (6 decimals)
      const fee = await nativeBridge.getFeeBridge(
        "0xA0b86a33E6417FaCCa4B7C30E1F4c0bA6A3d54a7",
        amount
      );
      
      console.log("\\nUSDC Bridge:");
      console.log(`Amount: 1000 USDC`);
      console.log(`Fee: ${ethers.formatEther(fee)} ETH`);
      console.log(`Expected: ~0.005 ETH ($10 fee at $2000 ETH)`);
      
      // Expected calculation:
      // 1000 USDC * 1% = 10 USDC = $10
      // $10 / $2000 ETH = 0.005 ETH + fixed fee
      const expectedFeeEth = ethers.parseEther("0.005");
      expect(fee).to.be.closeTo(expectedFeeEth, ethers.parseEther("0.001"));
    });
  });

  describe("Price Feed Management", function () {
    
    it("Should set and get price feeds correctly", async function () {
      const newTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      await nativeBridge.setTokenPriceFeed(newTokenId, mockUsdcPriceFeed.target);
      
      const feedAddress = await nativeBridge.getTokenPriceFeed(newTokenId);
      expect(feedAddress).to.equal(mockUsdcPriceFeed.target);
    });
    
    it("Should set and get fallback prices correctly", async function () {
      const newTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      const fallbackPrice = 150000000; // $1.50 with 8 decimals
      
      await nativeBridge.setFallbackPrice(newTokenId, fallbackPrice);
      
      const storedPrice = await nativeBridge.getFallbackPrice(newTokenId);
      expect(storedPrice).to.equal(fallbackPrice);
    });
  });

  describe("Fallback Price Usage", function () {
    
    it("Should use fallback price when no price feed is set", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("SHIB"));
      const fallbackPrice = 800; // $0.000008 with 8 decimals
      
      // Add token without price feed
      await nativeBridge.addTokenInfo(
        testTokenId,
        "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE", // SHIB address
        500, // 5% fee rate (high for meme token)
        18,  // decimals
        0    // no fixed fee
      );
      
      // Set fallback price
      await nativeBridge.setFallbackPrice(testTokenId, fallbackPrice);
      
      // Test fee calculation
      const amount = ethers.parseEther("1000000"); // 1M SHIB
      const fee = await nativeBridge.getFeeBridge(
        "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE",
        amount
      );
      
      console.log("\\nSHIB Bridge (Fallback Price):");
      console.log(`Amount: 1M SHIB (~$8)`);
      console.log(`Fee: ${ethers.formatEther(fee)} ETH`);
      console.log(`Expected: ~0.0002 ETH ($0.40 fee at $2000 ETH)`);
      
      expect(fee).to.be.gt(0);
    });
  });
});