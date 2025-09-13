// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./CustomCoin.sol";
contract WUSDC is CustomCoin {
    constructor() CustomCoin("Wrapped USDC", "wUSDC", 6) {}
}
