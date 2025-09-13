// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TokenRouteHyperlane
 * @dev Struct for storing route information for bridging tokens via Hyperlane.
 */
struct TokenRouteHyperlane {
    address warpRouteAddress; ///< Address of the warp route contract
    address tokenAddress;     ///< Token address
    uint32 destinationDomain; ///< Destination domain ID
}

/// @title TokenFeeConfig
/// @dev Struct for storing fee configuration for a token
struct TokenFeeConfig {
    uint256 fixedFee;      ///< Fixed fee in wei
    uint256 feeRate;       ///< Fee rate in basis points (10000 = 100%)
    uint8 decimals;        ///< Token decimals
    bool isSupported;      ///< Whether token is supported for fee calculation
}