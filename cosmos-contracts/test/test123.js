describe("mintTokenVL", function () {
  let contract;
  let owner, validator1, validator2, user;
  let token;
  let txKey;
  let payload;

  beforeEach(async function () {
    [owner, validator1, validator2, user] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("MockToken");
    token = await Token.deploy();
    await token.deployed();

    const Bridge = await ethers.getContractFactory("YourBridgeContract");
    contract = await Bridge.deploy(/* constructor params */);
    await contract.deployed();

    // Thêm validators
    await contract.addValidator(validator1.address);
    await contract.addValidator(validator2.address);

    // Giả sử threshold = 2
    await contract.setThreshold(1);

    // Tạo payload
    txKey = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("tx-key"));
    payload = {
      txKey,
      from: validator1.address,
      to: user.address,
      tokenAddr: token.address,
      amount: ethers.utils.parseEther("1"),
      tokenType: 1,
      nonce: 1,
    };
  });

  it("Should allow valid signature and mint token after threshold", async function () {
    // Hash dữ liệu và ký
    const hash = await contract.hashMessage(payload);
    const signature1 = await validator1.signMessage(ethers.utils.arrayify(hash));
    const signature2 = await validator2.signMessage(ethers.utils.arrayify(hash));

    // Validator 1 ký
    await expect(contract.connect(validator1).mintTokenVL(signature1, payload))
      .to.emit(contract, "SignatureSubmitted").withArgs(txKey, validator1.address);

    // Validator 2 ký → vượt threshold → mint
    await expect(contract.connect(validator2).mintTokenVL(signature2, payload))
      .to.emit(contract, "MintedTokenVL").withArgs(user.address, token.address, payload.amount);

    // Kiểm tra số dư token
    expect(await token.balanceOf(user.address)).to.equal(payload.amount);
  });

  it("Should revert if non-validator tries to sign", async function () {
    const hash = await contract.hashMessage(payload);
    const signature = await user.signMessage(ethers.utils.arrayify(hash));

    await expect(contract.connect(user).mintTokenVL(signature, payload))
      .to.be.revertedWith("Not validator");
  });

  it("Should revert if nonce is invalid", async function () {
    const badPayload = { ...payload, nonce: 999 };
    const hash = await contract.hashMessage(badPayload);
    const signature = await validator1.signMessage(ethers.utils.arrayify(hash));

    await expect(contract.connect(validator1).mintTokenVL(signature, badPayload))
      .to.be.revertedWith("Invalid nonce");
  });

  it("Should revert on reused signature", async function () {
    const hash = await contract.hashMessage(payload);
    const signature1 = await validator1.signMessage(ethers.utils.arrayify(hash));

    await contract.connect(validator1).mintTokenVL(signature1, payload);

    await expect(contract.connect(validator1).mintTokenVL(signature1, payload))
      .to.be.revertedWith("Already signed");
  });

  it("Should revert if message already processed", async function () {
    const hash = await contract.hashMessage(payload);
    const signature1 = await validator1.signMessage(ethers.utils.arrayify(hash));
    const signature2 = await validator2.signMessage(ethers.utils.arrayify(hash));

    await contract.connect(validator1).mintTokenVL(signature1, payload);
    await contract.connect(validator2).mintTokenVL(signature2, payload);

    // Thử lại lần nữa → sẽ bị revert
    await expect(contract.connect(validator2).mintTokenVL(signature2, payload))
      .to.be.revertedWith("Message already processed");
  });
});
