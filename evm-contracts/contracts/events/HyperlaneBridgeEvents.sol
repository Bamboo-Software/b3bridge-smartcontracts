// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HyperlaneBridgeEvents
 * @dev Library containing all events for HyperlaneBridge contract.
 */
library HyperlaneBridgeEvents {
    /// @notice Emitted when a token fee config is updated
    event TokenFeeConfigUpdated(address indexed tokenAddress, uint256 fixedFee, uint256 feeRate, uint8 decimals);

    /// @notice Emitted when a token price feed is updated
    event TokenPriceFeedUpdated(address indexed tokenAddress, address priceFeed);

    /// @notice Emitted when min/max bridge fee is updated
    event MinMaxFeeBridgeUpdated(uint256 minFee, uint256 maxFee);

    /// @notice Emitted when a domain is updated (enabled/disabled)
    event DomainHyperlaneUpdated(uint32 indexed domainId, bool supported);

    /// @notice Emitted when a token route is updated for a domain
    event TokenRouteHyperlaneUpdated(uint32 indexed destinationDomainId, address indexed tokenAddress, address indexed warpRouteAddress);

    /// @notice Emitted when a token is bridged via Hyperlane
    event TokenHyperlaneBridged(
        address indexed sender,
        address indexed tokenAddress,
        bytes32 indexed recipient,
        uint256 amount,
        bytes32 messageId,
        uint32 destinationDomainId
    );
}
