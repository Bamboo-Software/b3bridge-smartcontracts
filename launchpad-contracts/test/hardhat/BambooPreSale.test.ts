const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BambooPresale", function () {
  let BambooPresale, bambooPreSale: { waitForDeployment: () => any; target: any; targetAmount: () => any; softCap: () => any; startTime: () => any; endTime: () => any; totalTokens: () => any; minContribution: () => any; maxContribution: () => any; userWallet: () => any; systemWallet: () => any; useNativeToken: () => any; depositTokens: () => any; tokensDeposited: () => any; connect: (arg0: any) => { (): any; new(): any; depositTokens: { (): any; new(): any; }; contribute: { (arg0: any, arg1: { value: any; }): any; new(): any; }; claimTokens: { (): any; new(): any; }; }; contributions: (arg0: any) => any; contributionTimes: (arg0: any) => any; totalRaised: () => any; finalize: () => any; finalized: () => any; emergencyWithdrawTokens: () => any; emergencyWithdrawPaymentTokens: () => any; getContributors: () => any; }, MockToken, mockToken: { waitForDeployment: () => any; target: any; transfer: (arg0: any, arg1: any) => any; balanceOf: (arg0: any) => any; }, PaymentToken, paymentToken;
  let owner, userWallet: { address: any; }, systemWallet: { address: any; }, contributor1: { address: any; }, contributor2: { address: any; };
  let targetAmount = ethers.parseEther("100");
  let softCap = ethers.parseEther("50");
  let totalTokens = ethers.parseEther("1000");
  let minContribution = ethers.parseEther("1");
  let maxContribution = ethers.parseEther("10");
  let startTime: number, endTime: number;

  beforeEach(async function () {
    [owner, userWallet, systemWallet, contributor1, contributor2] = await ethers.getSigners();

    // Deploy MockToken
    MockToken = await ethers.getContractFactory("MockToken");
    mockToken = await MockToken.deploy("Bamboo Token", "BAM", totalTokens);
    await mockToken.waitForDeployment();

    // Deploy PaymentToken (for ERC20 payment)
    PaymentToken = await ethers.getContractFactory("MockToken");
    paymentToken = await PaymentToken.deploy("USDT", "USDT", ethers.parseEther("10000"));
    await paymentToken.waitForDeployment();

    // Set start and end time
    startTime = Math.floor(Date.now() / 1000) + 60; // Start in 60 seconds
    endTime = startTime + 86400; // End after 1 day

    // Deploy BambooPresale
    BambooPresale = await ethers.getContractFactory("BambooPresale");
    bambooPreSale = await BambooPresale.deploy(
      mockToken.target,
      ethers.ZeroAddress, // Use native token (ETH)
      targetAmount,
      softCap,
      startTime,
      endTime,
      totalTokens,
      minContribution,
      maxContribution,
      userWallet.address,
      systemWallet.address,
      owner.address
    );
    await bambooPreSale.waitForDeployment();

    // Transfer tokens to contract for presale
    await mockToken.transfer(bambooPreSale.target, totalTokens);
  });

  describe("Deployment", function () {
    it("should set correct initial parameters", async function () {
      expect(await bambooPreSale.targetAmount()).to.equal(targetAmount);
      expect(await bambooPreSale.softCap()).to.equal(softCap);
      expect(await bambooPreSale.startTime()).to.equal(startTime);
      expect(await bambooPreSale.endTime()).to.equal(endTime);
      expect(await bambooPreSale.totalTokens()).to.equal(totalTokens);
      expect(await bambooPreSale.minContribution()).to.equal(minContribution);
      expect(await bambooPreSale.maxContribution()).to.equal(maxContribution);
      expect(await bambooPreSale.userWallet()).to.equal(userWallet.address);
      expect(await bambooPreSale.systemWallet()).to.equal(systemWallet.address);
      expect(await bambooPreSale.useNativeToken()).to.be.true;
    });
  });

  describe("Deposit Tokens", function () {
    it("should allow owner to deposit tokens", async function () {
      await bambooPreSale.depositTokens();
      expect(await bambooPreSale.tokensDeposited()).to.be.true;
      expect(await mockToken.balanceOf(bambooPreSale.target)).to.equal(totalTokens);
    });

    it("should revert if non-owner tries to deposit tokens", async function () {
      await expect(bambooPreSale.connect(contributor1).depositTokens()).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });
  });

  describe("Contribute", function () {
    beforeEach(async function () {
      await bambooPreSale.depositTokens();
      // Fast forward time to start of presale
      await ethers.provider.send("evm_setNextBlockTimestamp", [startTime]);
      await ethers.provider.send("evm_mine");
    });

    it("should allow contribution within limits", async function () {
      const contribution = ethers.parseEther("5");
      await bambooPreSale.connect(contributor1).contribute(contribution, { value: contribution });
      expect(await bambooPreSale.contributions(contributor1.address)).to.equal(contribution);
      expect(await bambooPreSale.contributionTimes(contributor1.address)).to.be.greaterThan(0);
      expect(await bambooPreSale.totalRaised()).to.equal(contribution);
    });

    it("should revert if contribution is below minimum", async function () {
      await expect(
        bambooPreSale.connect(contributor1).contribute(ethers.parseEther("0.5"), { value: ethers.parseEther("0.5") })
      ).to.be.revertedWith("Contribution below minimum");
    });

    it("should revert if contributor tries to contribute twice", async function () {
      const contribution = ethers.parseEther("5");
      await bambooPreSale.connect(contributor1).contribute(contribution, { value: contribution });
      await expect(
        bambooPreSale.connect(contributor1).contribute(contribution, { value: contribution })
      ).to.be.revertedWith("Contributor has already participated");
    });
  });

  describe("Finalize", function () {
    beforeEach(async function () {
      await bambooPreSale.depositTokens();
      await ethers.provider.send("evm_setNextBlockTimestamp", [startTime]);
      await ethers.provider.send("evm_mine");
      const contribution = ethers.parseEther("60");
      await bambooPreSale.connect(contributor1).contribute(contribution, { value: contribution });
    });

    it("should finalize and distribute funds if softCap is reached", async function () {
      await ethers.provider.send("evm_setNextBlockTimestamp", [endTime + 1]);
      await ethers.provider.send("evm_mine");

      const initialSystemBalance = await ethers.provider.getBalance(systemWallet.address);
      const initialUserBalance = await ethers.provider.getBalance(userWallet.address);

      await bambooPreSale.finalize();

      const systemFee = ethers.parseEther("60") * 2n / 100n;
      const ownerAmount = ethers.parseEther("60") - systemFee;

      expect(await bambooPreSale.finalized()).to.be.true;
      expect(await ethers.provider.getBalance(systemWallet.address)).to.equal(
        initialSystemBalance + systemFee
      );
      expect(await ethers.provider.getBalance(userWallet.address)).to.equal(
        initialUserBalance + ownerAmount
      );
    });

    it("should refund if softCap is not reached", async function () {
      await bambooPreSale.connect(contributor2).contribute(ethers.parseEther("5"), { value: ethers.parseEther("5") });
      await ethers.provider.send("evm_setNextBlockTimestamp", [endTime + 1]);
      await ethers.provider.send("evm_mine");

      const initialBalance = await ethers.provider.getBalance(contributor1.address);
      await bambooPreSale.finalize();

      expect(await bambooPreSale.contributions(contributor1.address)).to.equal(0);
      expect(await bambooPreSale.contributionTimes(contributor1.address)).to.equal(0);
      expect(await ethers.provider.getBalance(contributor1.address)).to.be.closeTo(
        initialBalance + ethers.parseEther("60"),
        ethers.parseEther("0.01") // Allow for gas costs
      );
    });
  });

  describe("Claim Tokens", function () {
    beforeEach(async function () {
      await bambooPreSale.depositTokens();
      await ethers.provider.send("evm_setNextBlockTimestamp", [startTime]);
      await ethers.provider.send("evm_mine");
      await bambooPreSale.connect(contributor1).contribute(ethers.parseEther("60"), { value: ethers.parseEther("60") });
      await ethers.provider.send("evm_setNextBlockTimestamp", [endTime + 1]);
      await ethers.provider.send("evm_mine");
      await bambooPreSale.finalize();
    });

    it("should allow contributors to claim tokens", async function () {
      const expectedTokens = (ethers.parseEther("60") * totalTokens) / targetAmount;
      await bambooPreSale.connect(contributor1).claimTokens();
      expect(await mockToken.balanceOf(contributor1.address)).to.equal(expectedTokens);
      expect(await bambooPreSale.contributions(contributor1.address)).to.equal(0);
      expect(await bambooPreSale.contributionTimes(contributor1.address)).to.equal(0);
    });
  });

  describe("Emergency Withdraw", function () {
    beforeEach(async function () {
      await bambooPreSale.depositTokens();
    });

    it("should allow owner to emergency withdraw tokens to systemWallet", async function () {
      const initialBalance = await mockToken.balanceOf(systemWallet.address);
      await bambooPreSale.emergencyWithdrawTokens();
      expect(await mockToken.balanceOf(systemWallet.address)).to.equal(initialBalance + totalTokens);
      expect(await mockToken.balanceOf(bambooPreSale.target)).to.equal(0);
    });

    it("should allow owner to emergency withdraw payment tokens to systemWallet", async function () {
      await ethers.provider.send("evm_setNextBlockTimestamp", [startTime]);
      await ethers.provider.send("evm_mine");
      await bambooPreSale.connect(contributor1).contribute(ethers.parseEther("5"), { value: ethers.parseEther("5") });

      const initialBalance = await ethers.provider.getBalance(systemWallet.address);
      await bambooPreSale.emergencyWithdrawPaymentTokens();
      expect(await ethers.provider.getBalance(systemWallet.address)).to.be.closeTo(
        initialBalance + ethers.parseEther("5"),
        ethers.parseEther("0.01") // Allow for gas costs
      );
    });
  });

  describe("Get Contributors", function () {
    beforeEach(async function () {
      await bambooPreSale.depositTokens();
      await ethers.provider.send("evm_setNextBlockTimestamp", [startTime]);
      await ethers.provider.send("evm_mine");
      await bambooPreSale.connect(contributor1).contribute(ethers.parseEther("5"), { value: ethers.parseEther("5") });
      await bambooPreSale.connect(contributor2).contribute(ethers.parseEther("10"), { value: ethers.parseEther("10") });
    });

    it("should return correct contributor information", async function () {
      const contributors = await bambooPreSale.getContributors();
      expect(contributors.length).to.equal(2);
      expect(contributors[0].wallet).to.equal(contributor1.address);
      expect(contributors[0].amount).to.equal(ethers.parseEther("5"));
      expect(contributors[0].timestamp).to.be.greaterThan(0);
      expect(contributors[1].wallet).to.equal(contributor2.address);
      expect(contributors[1].amount).to.equal(ethers.parseEther("10"));
      expect(contributors[1].timestamp).to.be.greaterThan(0);
    });
  });
});