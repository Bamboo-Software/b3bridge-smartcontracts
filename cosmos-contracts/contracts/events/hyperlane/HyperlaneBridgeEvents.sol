// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library HyperlaneBridgeEvents {
    event TokenFeeConfigUpdated(address indexed tokenAddress, uint256 fixedFee, uint256 feeRate, uint8 decimals);
    event TokenPriceFeedUpdated(address indexed tokenAddress, address priceFeed);
    event MinMaxFeeBridgeUpdated(uint256 minFee, uint256 maxFee);
    event TokenRouteHyperlaneUpdated(uint32 destinationDomainId, address tokenAddress, address warpRouteAddress);
    event DomainHyperlaneUpdated(uint32 domainId, bool supported);
    event TokenHyperlaneBridged(
        address indexed sender,
        address indexed tokenAddress,
        bytes32 recipient,
        uint256 amount,
        bytes32 messageId,
        uint32 destinationDomainId
    );
}
