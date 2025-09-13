const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Improved getFeeBridge Test - Unified System", function () {
  let owner;
  let nativeBridge;
  let mockRouter;
  let mockEthPriceFeed, mockBtcPriceFeed, mockUsdcPriceFeed;
  
  const ETH_TOKEN_ID = ethers.keccak256(ethers.toUtf8Bytes("ETH"));
  const BTC_TOKEN_ID = ethers.keccak256(ethers.toUtf8Bytes("WBTC"));
  const USDC_TOKEN_ID = ethers.keccak256(ethers.toUtf8Bytes("USDC"));

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    
    // Deploy mock price feeds
    const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");
    mockEthPriceFeed = await MockPriceFeed.deploy(8, 200000000000); // $2000 ETH
    mockBtcPriceFeed = await MockPriceFeed.deploy(8, 3000000000000); // $30000 BTC  
    mockUsdcPriceFeed = await MockPriceFeed.deploy(8, 100000000); // $1 USDC
    
    // Deploy mock router
    const MockRouter = await ethers.getContractFactory("MockCCIPRouter");
    mockRouter = await MockRouter.deploy();
    
    // Deploy NativeBridge - ETH price feed is set up automatically
    const NativeBridge = await ethers.getContractFactory("NativeBridge");
    nativeBridge = await NativeBridge.deploy(
      mockRouter.target,
      [owner.address],
      1,
      mockEthPriceFeed.target // This automatically sets up ETH in tokenPriceFeeds
    );
    
    console.log("✅ NativeBridge deployed with unified pricing system");
  });

  describe("Unified Price System Verification", function () {
    
    it("Should have ETH automatically configured in unified system", async function () {
      // ETH should be set up automatically in constructor
      const ethTokenId = await nativeBridge.ETH_TOKEN_ID();
      const ethPriceFeed = await nativeBridge.getTokenPriceFeed(ethTokenId);
      const ethMapping = await nativeBridge.tokenAddressToId(ethers.ZeroAddress);
      
      expect(ethPriceFeed).to.equal(mockEthPriceFeed.target);
      expect(ethMapping).to.equal(ethTokenId);
      
      console.log("✅ ETH automatically configured in unified system");
    });
    
    it("Should get ETH price via unified getTokenPrice", async function () {
      const ethTokenId = await nativeBridge.ETH_TOKEN_ID();
      const price = await nativeBridge.getTokenPrice(ethTokenId);
      
      expect(price).to.equal(200000000000); // $2000
      console.log(`✅ ETH price via unified system: $${Number(price) / 1e8}`);
    });
    
    it("getLatestPrice should delegate to unified system", async function () {
      const legacyPrice = await nativeBridge.getLatestPrice();
      const ethTokenId = await nativeBridge.ETH_TOKEN_ID();
      const unifiedPrice = await nativeBridge.getTokenPrice(ethTokenId);
      
      expect(legacyPrice).to.equal(unifiedPrice);
      console.log("✅ getLatestPrice correctly delegates to unified system");
    });
  });

  describe("Multi-Token Setup", function () {
    
    beforeEach(async function () {
      // Setup BTC token
      await nativeBridge.setTokenMapping(BTC_TOKEN_ID, "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599");
      await nativeBridge.updateTokenInfo(BTC_TOKEN_ID, 200, 10000, 8); // 2% fee, 0.0001 BTC fixed
      await nativeBridge.setTokenPriceFeed(BTC_TOKEN_ID, mockBtcPriceFeed.target);
      
      // Setup USDC token
      await nativeBridge.setTokenMapping(USDC_TOKEN_ID, "0xA0b86a33E6417FaCCa4B7C30E1F4c0bA6A3d54a7");
      await nativeBridge.updateTokenInfo(USDC_TOKEN_ID, 100, 1000000, 6); // 1% fee, 1 USDC fixed
      await nativeBridge.setTokenPriceFeed(USDC_TOKEN_ID, mockUsdcPriceFeed.target);
      
      // Setup ETH token info (mapping already done in constructor)
      await nativeBridge.updateTokenInfo(ETH_TOKEN_ID, 150, ethers.parseEther("0.0001"), 18); // 1.5% fee
      
      console.log("✅ All tokens configured in unified system");
    });
    
    it("Should calculate ETH fee using unified system", async function () {
      const amount = ethers.parseEther("1"); // 1 ETH
      const fee = await nativeBridge.getFeeBridge(ethers.ZeroAddress, amount);
      
      // Expected: 1 ETH * 1.5% + 0.0001 ETH fixed = 0.0151 ETH
      const expectedDynamicFee = amount * 150n / 10000n; // 0.015 ETH
      const expectedFixedFee = ethers.parseEther("0.0001");
      const expectedTotalFee = expectedDynamicFee + expectedFixedFee;
      
      expect(fee).to.equal(expectedTotalFee);
      console.log(`✅ ETH bridge fee: ${ethers.formatEther(fee)} ETH`);
    });
    
    it("Should calculate BTC fee using unified system", async function () {
      const amount = 100000000; // 1 BTC (8 decimals)
      const fee = await nativeBridge.getFeeBridge(
        "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
        amount
      );
      
      console.log(`✅ BTC bridge fee: ${ethers.formatEther(fee)} ETH`);
      
      // Calculation verification:
      // 1 BTC * 2% = 0.02 BTC fee = $600 (at $30k BTC)
      // $600 / $2000 ETH = 0.3 ETH + fixed fee
      expect(fee).to.be.gt(ethers.parseEther("0.29")); // Should be ~0.3 ETH
      expect(fee).to.be.lt(ethers.parseEther("0.31"));
    });
    
    it("Should calculate USDC fee using unified system", async function () {
      const amount = 1000000000; // 1000 USDC (6 decimals)
      const fee = await nativeBridge.getFeeBridge(
        "0xA0b86a33E6417FaCCa4B7C30E1F4c0bA6A3d54a7",
        amount
      );
      
      console.log(`✅ USDC bridge fee: ${ethers.formatEther(fee)} ETH`);
      
      // Calculation verification:
      // 1000 USDC * 1% = 10 USDC fee = $10
      // $10 / $2000 ETH = 0.005 ETH + fixed fee (1 USDC = $1 / $2000 = 0.0005 ETH)
      // Total = 0.0055 ETH
      expect(fee).to.be.gt(ethers.parseEther("0.005"));
      expect(fee).to.be.lt(ethers.parseEther("0.006"));
    });
  });

  describe("Edge Cases & Consistency", function () {
    
    it("Should handle tokens with only fallback prices", async function () {
      const shiba_id = ethers.keccak256(ethers.toUtf8Bytes("SHIB"));
      
      // Setup SHIB with only fallback price
      await nativeBridge.setTokenMapping(shiba_id, "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE");
      await nativeBridge.updateTokenInfo(shiba_id, 500, 0, 18); // 5% fee, no fixed fee
      await nativeBridge.setFallbackPrice(shiba_id, 800); // $0.000008 with 8 decimals
      
      const amount = ethers.parseEther("1000000"); // 1M SHIB
      const fee = await nativeBridge.getFeeBridge(
        "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE",
        amount
      );
      
      console.log(`✅ SHIB bridge fee: ${ethers.formatEther(fee)} ETH`);
      expect(fee).to.be.gt(0);
    });
    
    it("Should prioritize oracle feeds over fallback", async function () {
      const test_id = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      // Setup token with both oracle and fallback
      await nativeBridge.setTokenMapping(test_id, "0x1111111111111111111111111111111111111111");
      await nativeBridge.updateTokenInfo(test_id, 100, 0, 18);
      await nativeBridge.setTokenPriceFeed(test_id, mockUsdcPriceFeed.target); // $1 from oracle
      await nativeBridge.setFallbackPrice(test_id, 50000000); // $0.50 from fallback
      
      const price = await nativeBridge.getTokenPrice(test_id);
      expect(price).to.equal(100000000); // Should use oracle ($1), not fallback ($0.50)
      
      console.log("✅ Oracle price correctly prioritized over fallback");
    });
    
    it("Should handle all prices consistently", async function () {
      // Test that all tokens can get prices via unified system
      const ethPrice = await nativeBridge.getTokenPrice(ETH_TOKEN_ID);
      console.log(`ETH: $${Number(ethPrice) / 1e8}`);
      
      // Setup and test BTC
      await nativeBridge.setTokenMapping(BTC_TOKEN_ID, "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599");
      await nativeBridge.setTokenPriceFeed(BTC_TOKEN_ID, mockBtcPriceFeed.target);
      const btcPrice = await nativeBridge.getTokenPrice(BTC_TOKEN_ID);
      console.log(`BTC: $${Number(btcPrice) / 1e8}`);
      
      // All should be positive
      expect(ethPrice).to.be.gt(0);
      expect(btcPrice).to.be.gt(0);
      
      console.log("✅ All token prices accessible via unified system");
    });
  });

  describe("Legacy Compatibility", function () {
    
    it("Should maintain backward compatibility with getLatestPrice", async function () {
      const legacyPrice = await nativeBridge.getLatestPrice();
      const modernPrice = await nativeBridge.getTokenPrice(ETH_TOKEN_ID);
      
      expect(legacyPrice).to.equal(modernPrice);
      console.log("✅ Legacy getLatestPrice maintains compatibility");
    });
  });
});