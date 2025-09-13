// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./CustomCoin.sol";
contract WETH is CustomCoin {
    constructor() CustomCoin("Wrapped ETH", "wETH", 18) {}
}
