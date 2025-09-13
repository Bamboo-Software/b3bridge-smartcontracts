// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// contract Events {
//     event DebugTokenAddress(bytes32 tokenId, address tokenAddress);
//     event MintTokenCCIP(address receiver, bytes32 tokenId, uint256 amount);
//     event BurnTokenVL(address indexed sender, uint256 amount, address indexed sourceBridge, address wTokenAddress, address destWalletAddress);
//     event MintedTokenVL(address recipientAddr, address token, uint256 amount);
//     event DebugMsg(string message);
//     event DebugFee(uint256 fee);
//     event BurnTokenCCIP(bytes32 indexed messageId, address indexed user, bytes32 tokenId, uint256 amount, uint256 amountAfterFee);
//     event ThresholdUpdated(uint256 newThreshold);
//     event ValidatorAdded(address validator);
//     event ValidatorRemoved(address validator);
//     event SignatureSubmitted(bytes32 indexed messageHash, address indexed signer);
//     event Executed(bytes32 indexed messageHash);
//     event FeeDistributed(address indexed validator, address token, uint256 amount);
//     event FeeCollected(address indexed sender, address token, uint256 totalFee, uint256 ownerFee, uint256 validatorFee);
// }