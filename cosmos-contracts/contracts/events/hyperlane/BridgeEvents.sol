// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library BridgeEvents {
    event TokenHyperlaneBridged(
        address indexed sender,
        address indexed tokenAddress,
        bytes32 recipient,
        uint256 amount,
        bytes32 messageId,
        uint32 destinationDomainId
    );
}
