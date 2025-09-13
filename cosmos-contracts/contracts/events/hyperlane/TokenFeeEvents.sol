// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library TokenFeeEvents {
    event TokenFeeConfigUpdated(address indexed tokenAddress, uint256 fixedFee, uint256 feeRate, uint8 decimals);
    event MinMaxFeeBridgeUpdated(uint256 minFee, uint256 maxFee);
}
