// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library RouteEvents {
    event TokenRouteHyperlaneUpdated(uint32 destinationDomainId, address tokenAddress, address warpRouteAddress);
    event DomainHyperlaneUpdated(uint32 domainId, bool supported);
}
