// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Thông tin route Hyperlane cho token
struct TokenRouteHyperlane {
    address warpRouteAddress;
    address tokenAddress;
    uint32 destinationDomain;
}
