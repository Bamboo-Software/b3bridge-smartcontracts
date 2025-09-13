const hre = require("hardhat");

async function setMinterBurnerRoles(roles, address) {
  for (const { tokenAddress } of roles) {
    if (!tokenAddress) continue;
    const CustomCoin = await hre.ethers.getContractAt("CustomCoin", tokenAddress);
    // Grant minter role
    const tx1 = await CustomCoin.grantMinterRole(address);
    await tx1.wait();
    console.log(`✅ Granted MINTER_ROLE for ${tokenAddress}`);
    // Grant burner role
    const tx2 = await CustomCoin.grantBurnerRole(address);
    await tx2.wait();
    console.log(`✅ Granted BURNER_ROLE for ${tokenAddress}`);
  }
}

module.exports = { setMinterBurnerRoles };
