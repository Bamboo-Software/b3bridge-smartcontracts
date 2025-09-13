const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("getFeeBridge Simple Test", function () {
  let owner;
  let nativeBridge;
  let mockRouter;
  let mockPriceFeed;
  
  const ETH_TOKEN_ID = ethers.keccak256(ethers.toUtf8Bytes("ETH"));

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    
    // Deploy mock contracts
    const MockRouter = await ethers.getContractFactory("MockCCIPRouter");
    mockRouter = await MockRouter.deploy();
    
    const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");
    mockPriceFeed = await MockPriceFeed.deploy(8, 200000000000); // $2000
    
    // Deploy NativeBridge
    const NativeBridge = await ethers.getContractFactory("NativeBridge");
    nativeBridge = await NativeBridge.deploy(
      mockRouter.target,
      [owner.address],
      1,
      mockPriceFeed.target
    );
    
    // Setup ETH token using direct storage manipulation if needed
    // For now, test only the price feed functions
  });

  describe("Price Feed Management", function () {
    
    it("Should set and get fallback price correctly", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      const fallbackPrice = 150000000; // $1.50 with 8 decimals
      
      await nativeBridge.setFallbackPrice(testTokenId, fallbackPrice);
      
      const storedPrice = await nativeBridge.getFallbackPrice(testTokenId);
      expect(storedPrice).to.equal(fallbackPrice);
      
      console.log(`✅ Set fallback price: $${fallbackPrice / 1e8}`);
    });
    
    it("Should set and get token price feed correctly", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("BTC"));
      
      await nativeBridge.setTokenPriceFeed(testTokenId, mockPriceFeed.target);
      
      const feedAddress = await nativeBridge.getTokenPriceFeed(testTokenId);
      expect(feedAddress).to.equal(mockPriceFeed.target);
      
      console.log(`✅ Set price feed for BTC token`);
    });
    
    it("Should get token price from price feed", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("BTC"));
      
      // Set price feed
      await nativeBridge.setTokenPriceFeed(testTokenId, mockPriceFeed.target);
      
      // Get price
      const price = await nativeBridge.getTokenPrice(testTokenId);
      expect(price).to.equal(200000000000); // $2000 with 8 decimals
      
      console.log(`✅ Got BTC price from feed: $${Number(price) / 1e8}`);
    });
    
    it("Should get token price from fallback when no feed", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("USDC"));
      const fallbackPrice = 100000000; // $1.00 with 8 decimals
      
      // Set only fallback price
      await nativeBridge.setFallbackPrice(testTokenId, fallbackPrice);
      
      // Get price
      const price = await nativeBridge.getTokenPrice(testTokenId);
      expect(price).to.equal(fallbackPrice);
      
      console.log(`✅ Got USDC price from fallback: $${Number(price) / 1e8}`);
    });
    
    it("Should revert when no price available", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("NOPRICE"));
      
      await expect(
        nativeBridge.getTokenPrice(testTokenId)
      ).to.be.revertedWith("No price available for token");
      
      console.log(`✅ Correctly reverted for token with no price`);
    });
    
    it("Should revert for invalid price feed parameters", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      // Test invalid price feed address
      await expect(
        nativeBridge.setTokenPriceFeed(testTokenId, ethers.ZeroAddress)
      ).to.be.revertedWith("Invalid price feed address");
      
      // Test invalid fallback price
      await expect(
        nativeBridge.setFallbackPrice(testTokenId, 0)
      ).to.be.revertedWith("Invalid price");
      
      console.log(`✅ Correctly validated invalid parameters`);
    });
  });

  describe("Admin Functions", function () {
    
    it("Should remove price feed correctly", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      // Set then remove price feed
      await nativeBridge.setTokenPriceFeed(testTokenId, mockPriceFeed.target);
      await nativeBridge.removeTokenPriceFeed(testTokenId);
      
      const feedAddress = await nativeBridge.getTokenPriceFeed(testTokenId);
      expect(feedAddress).to.equal(ethers.ZeroAddress);
      
      console.log(`✅ Removed price feed correctly`);
    });
    
    it("Should remove fallback price correctly", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      // Set then remove fallback price
      await nativeBridge.setFallbackPrice(testTokenId, 100000000);
      await nativeBridge.removeFallbackPrice(testTokenId);
      
      const price = await nativeBridge.getFallbackPrice(testTokenId);
      expect(price).to.equal(0);
      
      console.log(`✅ Removed fallback price correctly`);
    });
  });

  describe("Edge Cases", function () {
    
    it("Should handle price feed priority over fallback", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      // Set both price feed and fallback
      await nativeBridge.setTokenPriceFeed(testTokenId, mockPriceFeed.target);
      await nativeBridge.setFallbackPrice(testTokenId, 50000000); // $0.50
      
      // Should use price feed ($2000), not fallback ($0.50)
      const price = await nativeBridge.getTokenPrice(testTokenId);
      expect(price).to.equal(200000000000); // $2000 from feed
      
      console.log(`✅ Price feed has priority over fallback`);
    });
  });

  describe("Events", function () {
    
    it("Should emit events for price management", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      // Test TokenPriceFeedSet event
      await expect(
        nativeBridge.setTokenPriceFeed(testTokenId, mockPriceFeed.target)
      ).to.emit(nativeBridge, "TokenPriceFeedSet")
       .withArgs(testTokenId, mockPriceFeed.target);
      
      // Test FallbackPriceSet event
      await expect(
        nativeBridge.setFallbackPrice(testTokenId, 100000000)
      ).to.emit(nativeBridge, "FallbackPriceSet")
       .withArgs(testTokenId, 100000000);
      
      console.log(`✅ Events emitted correctly`);
    });
  });
});