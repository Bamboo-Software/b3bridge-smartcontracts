const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Unified Pricing System Test", function () {
  let owner;
  let nativeBridge;
  let mockRouter;
  let mockEthPriceFeed, mockBtcPriceFeed;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    
    // Deploy mock price feeds
    const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");
    mockEthPriceFeed = await MockPriceFeed.deploy(8, 200000000000); // $2000 ETH
    mockBtcPriceFeed = await MockPriceFeed.deploy(8, 3000000000000); // $30000 BTC
    
    // Deploy mock router
    const MockRouter = await ethers.getContractFactory("MockCCIPRouter");
    mockRouter = await MockRouter.deploy();
    
    // Deploy NativeBridge with unified pricing
    const NativeBridge = await ethers.getContractFactory("NativeBridge");
    nativeBridge = await NativeBridge.deploy(
      mockRouter.target,
      [owner.address],
      1,
      mockEthPriceFeed.target
    );
    
    console.log("✅ Deployed NativeBridge with unified pricing system");
  });

  describe("Architecture Improvements", function () {
    
    it("Should automatically setup ETH in unified system", async function () {
      const ethTokenId = await nativeBridge.ETH_TOKEN_ID();
      
      // Check ETH is mapped to address(0)
      const ethMapping = await nativeBridge.tokenAddressToId(ethers.ZeroAddress);
      expect(ethMapping).to.equal(ethTokenId);
      
      // Check ETH has price feed
      const ethPriceFeed = await nativeBridge.getTokenPriceFeed(ethTokenId);
      expect(ethPriceFeed).to.equal(mockEthPriceFeed.target);
      
      console.log("✅ ETH automatically configured in unified system");
      console.log(`  - ETH Token ID: ${ethTokenId}`);
      console.log(`  - ETH Price Feed: ${ethPriceFeed}`);
    });
    
    it("Should get ETH price via unified getTokenPrice", async function () {
      const ethTokenId = await nativeBridge.ETH_TOKEN_ID();
      const price = await nativeBridge.getTokenPrice(ethTokenId);
      
      expect(price).to.equal(200000000000); // $2000 with 8 decimals
      console.log(`✅ ETH price via unified system: $${Number(price) / 1e8}`);
    });
    
    it("Legacy getLatestPrice should delegate to unified system", async function () {
      const legacyPrice = await nativeBridge.getLatestPrice();
      const ethTokenId = await nativeBridge.ETH_TOKEN_ID();
      const unifiedPrice = await nativeBridge.getTokenPrice(ethTokenId);
      
      expect(legacyPrice).to.equal(unifiedPrice);
      console.log("✅ getLatestPrice correctly delegates to getTokenPrice(ETH_TOKEN_ID)");
      console.log(`  - Legacy: $${Number(legacyPrice) / 1e8}`);
      console.log(`  - Unified: $${Number(unifiedPrice) / 1e8}`);
    });
    
    it("Should manage token price feeds via unified system", async function () {
      const btcTokenId = ethers.keccak256(ethers.toUtf8Bytes("WBTC"));
      
      // Set BTC price feed
      await nativeBridge.setTokenPriceFeed(btcTokenId, mockBtcPriceFeed.target);
      
      // Verify it's set
      const btcPriceFeed = await nativeBridge.getTokenPriceFeed(btcTokenId);
      expect(btcPriceFeed).to.equal(mockBtcPriceFeed.target);
      
      // Get BTC price
      const btcPrice = await nativeBridge.getTokenPrice(btcTokenId);
      expect(btcPrice).to.equal(3000000000000); // $30000
      
      console.log("✅ BTC price feed managed via unified system");
      console.log(`  - BTC Price: $${Number(btcPrice) / 1e8}`);
    });
    
    it("Should handle fallback prices in unified system", async function () {
      const usdcTokenId = ethers.keccak256(ethers.toUtf8Bytes("USDC"));
      
      // Set fallback price for USDC
      await nativeBridge.setFallbackPrice(usdcTokenId, 100000000); // $1.00
      
      // Get USDC price (should use fallback)
      const usdcPrice = await nativeBridge.getTokenPrice(usdcTokenId);
      expect(usdcPrice).to.equal(100000000);
      
      console.log("✅ USDC fallback price works in unified system");
      console.log(`  - USDC Price (fallback): $${Number(usdcPrice) / 1e8}`);
    });
    
    it("Should prioritize oracle feeds over fallback prices", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      // Set both oracle and fallback
      await nativeBridge.setTokenPriceFeed(testTokenId, mockBtcPriceFeed.target); // $30000
      await nativeBridge.setFallbackPrice(testTokenId, 50000000); // $0.50
      
      // Should use oracle price, not fallback
      const price = await nativeBridge.getTokenPrice(testTokenId);
      expect(price).to.equal(3000000000000); // $30000 from oracle
      
      console.log("✅ Oracle feed correctly prioritized over fallback");
      console.log(`  - Oracle: $${Number(price) / 1e8}`);
      console.log(`  - Fallback would be: $0.50`);
    });
  });

  describe("Error Handling", function () {
    
    it("Should revert for tokens with no price data", async function () {
      const nopriceTokenId = ethers.keccak256(ethers.toUtf8Bytes("NOPRICE"));
      
      await expect(
        nativeBridge.getTokenPrice(nopriceTokenId)
      ).to.be.revertedWith("No price available for token");
      
      console.log("✅ Correctly reverts for tokens with no price data");
    });
    
    it("Should validate price feed management", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      // Test invalid price feed address
      await expect(
        nativeBridge.setTokenPriceFeed(testTokenId, ethers.ZeroAddress)
      ).to.be.revertedWith("Invalid price feed address");
      
      // Test invalid fallback price
      await expect(
        nativeBridge.setFallbackPrice(testTokenId, 0)
      ).to.be.revertedWith("Invalid price");
      
      console.log("✅ Price feed management validation works correctly");
    });
  });

  describe("Events & Administration", function () {
    
    it("Should emit events for price feed management", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      // Test TokenPriceFeedSet event
      await expect(
        nativeBridge.setTokenPriceFeed(testTokenId, mockBtcPriceFeed.target)
      ).to.emit(nativeBridge, "TokenPriceFeedSet")
       .withArgs(testTokenId, mockBtcPriceFeed.target);
      
      // Test FallbackPriceSet event
      await expect(
        nativeBridge.setFallbackPrice(testTokenId, 100000000)
      ).to.emit(nativeBridge, "FallbackPriceSet")
       .withArgs(testTokenId, 100000000);
      
      console.log("✅ Price management events emitted correctly");
    });
    
    it("Should remove price feeds and fallback prices", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      // Set then remove price feed
      await nativeBridge.setTokenPriceFeed(testTokenId, mockBtcPriceFeed.target);
      await nativeBridge.removeTokenPriceFeed(testTokenId);
      
      const feedAddress = await nativeBridge.getTokenPriceFeed(testTokenId);
      expect(feedAddress).to.equal(ethers.ZeroAddress);
      
      // Set then remove fallback price
      await nativeBridge.setFallbackPrice(testTokenId, 100000000);
      await nativeBridge.removeFallbackPrice(testTokenId);
      
      const fallbackPrice = await nativeBridge.getFallbackPrice(testTokenId);
      expect(fallbackPrice).to.equal(0);
      
      console.log("✅ Price feed and fallback removal works correctly");
    });
  });

  describe("System Benefits", function () {
    
    it("Demonstrates unified pricing system benefits", async function () {
      console.log("\\n🎯 UNIFIED PRICING SYSTEM BENEFITS:");
      console.log("=====================================");
      
      // 1. Consistent API
      const ethTokenId = await nativeBridge.ETH_TOKEN_ID();
      const ethPrice = await nativeBridge.getTokenPrice(ethTokenId);
      console.log(`1. Consistent API: getTokenPrice(ETH) = $${Number(ethPrice) / 1e8}`);
      
      // 2. Automatic ETH setup
      const ethMapping = await nativeBridge.tokenAddressToId(ethers.ZeroAddress);
      console.log(`2. Auto ETH setup: address(0) → ${ethMapping}`);
      
      // 3. Legacy compatibility
      const legacyPrice = await nativeBridge.getLatestPrice();
      console.log(`3. Legacy compat: getLatestPrice() = $${Number(legacyPrice) / 1e8}`);
      
      // 4. Flexible price sources
      const btcTokenId = ethers.keccak256(ethers.toUtf8Bytes("WBTC"));
      await nativeBridge.setTokenPriceFeed(btcTokenId, mockBtcPriceFeed.target);
      const btcPrice = await nativeBridge.getTokenPrice(btcTokenId);
      console.log(`4. Oracle feeds: getTokenPrice(WBTC) = $${Number(btcPrice) / 1e8}`);
      
      const usdcTokenId = ethers.keccak256(ethers.toUtf8Bytes("USDC"));
      await nativeBridge.setFallbackPrice(usdcTokenId, 100000000);
      const usdcPrice = await nativeBridge.getTokenPrice(usdcTokenId);
      console.log(`5. Fallback prices: getTokenPrice(USDC) = $${Number(usdcPrice) / 1e8}`);
      
      console.log("\\n✅ ALL IMPROVEMENTS VERIFIED!");
    });
  });
});