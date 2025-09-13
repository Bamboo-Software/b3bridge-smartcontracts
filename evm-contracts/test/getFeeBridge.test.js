const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("getFeeBridge Function Test", function () {
  let owner, user;
  let nativeBridge;
  let mockRouter;
  let mockPriceFeed;
  
  const ETH_TOKEN_ID = ethers.keccak256(ethers.toUtf8Bytes("ETH"));
  const USDC_TOKEN_ID = ethers.keccak256(ethers.toUtf8Bytes("USDC"));

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();
    
    // Deploy mock router
    const MockRouterFactory = await ethers.getContractFactory("MockCCIPRouter");
    mockRouter = await MockRouterFactory.deploy();
    await mockRouter.waitForDeployment();
    
    // Deploy mock price feed - ETH/USD = $2000
    const MockPriceFeedFactory = await ethers.getContractFactory("MockV3Aggregator");
    mockPriceFeed = await MockPriceFeedFactory.deploy(8, 200000000000); // $2000 with 8 decimals
    await mockPriceFeed.waitForDeployment();
    
    // Deploy NativeBridge
    const NativeBridgeFactory = await ethers.getContractFactory("NativeBridge");
    nativeBridge = await NativeBridgeFactory.deploy(
      mockRouter.target,          // _ccipRouter
      [owner.address],           // _validators
      1,                         // _threshold
      mockPriceFeed.target       // _chainlinkEthUsdFeed
    );
    await nativeBridge.waitForDeployment();
    
    // Setup tokens manually in tokenMap
    await nativeBridge.setTokenMapping(ETH_TOKEN_ID, ethers.ZeroAddress);
    await nativeBridge.updateTokenInfo(
      ETH_TOKEN_ID,
      150, // 1.5% fee rate
      ethers.parseEther("0.0001"), // fixed fee
      18   // decimals
    );
    
    await nativeBridge.setTokenMapping(USDC_TOKEN_ID, "0xA0b86a33E6417FaCCa4B7C30E1F4c0bA6A3d54a7");
    await nativeBridge.updateTokenInfo(
      USDC_TOKEN_ID,
      100, // 1% fee rate
      1000000, // fixed fee (1 USDC with 6 decimals)
      6   // decimals
    );
    
    // Set fallback price for USDC = $1.00
    await nativeBridge.setFallbackPrice(USDC_TOKEN_ID, 100000000); // $1.00 with 8 decimals
  });

  describe("Basic Fee Calculation", function () {
    
    it("Should calculate ETH bridge fee correctly", async function () {
      const amount = ethers.parseEther("1"); // 1 ETH
      const fee = await nativeBridge.getFeeBridge(ethers.ZeroAddress, amount);
      
      console.log(`ETH Bridge Fee for 1 ETH: ${ethers.formatEther(fee)} ETH`);
      
      // Expected: 1 ETH * 1.5% + 0.0001 ETH fixed = 0.0151 ETH
      const expectedDynamicFee = amount * 150n / 10000n; // 0.015 ETH
      const expectedFixedFee = ethers.parseEther("0.0001");
      const expectedTotalFee = expectedDynamicFee + expectedFixedFee;
      
      expect(fee).to.equal(expectedTotalFee);
    });
    
    it("Should calculate USDC bridge fee correctly using fallback price", async function () {
      const amount = 1000000000; // 1000 USDC (6 decimals)
      const fee = await nativeBridge.getFeeBridge(
        "0xA0b86a33E6417FaCCa4B7C30E1F4c0bA6A3d54a7",
        amount
      );
      
      console.log(`USDC Bridge Fee for 1000 USDC: ${ethers.formatEther(fee)} ETH`);
      
      // Expected calculation:
      // 1000 USDC * 1% = 10 USDC dynamic fee
      // 10 USDC * $1 = $10 USD value
      // $10 / $2000 ETH = 0.005 ETH
      // Plus 1 USDC fixed fee = $1 / $2000 = 0.0005 ETH
      // Total = 0.0055 ETH
      
      expect(fee).to.be.gt(0);
      expect(fee).to.be.lt(ethers.parseEther("0.01")); // Should be reasonable
    });
  });

  describe("Price Feed Management", function () {
    
    it("Should set token price feed correctly", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      await nativeBridge.setTokenPriceFeed(testTokenId, mockPriceFeed.target);
      
      const feedAddress = await nativeBridge.getTokenPriceFeed(testTokenId);
      expect(feedAddress).to.equal(mockPriceFeed.target);
    });
    
    it("Should set fallback price correctly", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      const fallbackPrice = 150000000; // $1.50 with 8 decimals
      
      await nativeBridge.setFallbackPrice(testTokenId, fallbackPrice);
      
      const storedPrice = await nativeBridge.getFallbackPrice(testTokenId);
      expect(storedPrice).to.equal(fallbackPrice);
    });
    
    it("Should revert when setting invalid price feed", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      await expect(
        nativeBridge.setTokenPriceFeed(testTokenId, ethers.ZeroAddress)
      ).to.be.revertedWith("Invalid price feed address");
    });
    
    it("Should revert when setting zero fallback price", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("TEST"));
      
      await expect(
        nativeBridge.setFallbackPrice(testTokenId, 0)
      ).to.be.revertedWith("Invalid price");
    });
  });

  describe("Error Handling", function () {
    
    it("Should revert for unsupported token", async function () {
      const amount = ethers.parseEther("1");
      const unsupportedToken = "0x1234567890123456789012345678901234567890";
      
      await expect(
        nativeBridge.getFeeBridge(unsupportedToken, amount)
      ).to.be.revertedWith("Unsupported token");
    });
    
    it("Should revert when no price available for token", async function () {
      const testTokenId = ethers.keccak256(ethers.toUtf8Bytes("NOPRICE"));
      const testTokenAddress = "0x1111111111111111111111111111111111111111";
      
      // Add token without price feed or fallback price
      await nativeBridge.addTokenInfo(
        testTokenId,
        testTokenAddress,
        100, // 1% fee rate
        18,  // decimals
        0    // no fixed fee
      );
      
      await expect(
        nativeBridge.getFeeBridge(testTokenAddress, ethers.parseEther("100"))
      ).to.be.revertedWith("No price available for token");
    });
  });

  describe("Fee Bounds", function () {
    
    it("Should apply minimum fee when calculated fee is too low", async function () {
      const smallAmount = 1000; // Very small USDC amount
      const fee = await nativeBridge.getFeeBridge(
        "0xA0b86a33E6417FaCCa4B7C30E1F4c0bA6A3d54a7",
        smallAmount
      );
      
      const minFee = await nativeBridge.minCCIPFee();
      expect(fee).to.equal(minFee);
    });
    
    it("Should apply maximum fee when calculated fee is too high", async function () {
      const largeAmount = ethers.parseEther("1000"); // 1000 ETH
      const fee = await nativeBridge.getFeeBridge(ethers.ZeroAddress, largeAmount);
      
      const maxFee = await nativeBridge.maxCCIPFee();
      expect(fee).to.equal(maxFee);
    });
  });
});