// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Cấu hình phí cho từng token
struct TokenFeeConfig {
    uint256 fixedFee;      // Fixed fee in wei
    uint256 feeRate;       // Fee rate in basis points (10000 = 100%)
    uint8 decimals;        // Token decimals
}
