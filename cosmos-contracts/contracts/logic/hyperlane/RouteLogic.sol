// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../structs/hyperlane/TokenRouteHyperlane.sol";
import "../../events/hyperlane/RouteEvents.sol";

library RouteLogic {
    /**
     * @dev Generate a route key from domainId and token address
     */
    function getRouteKeyHyperlane(uint32 domainId, address tokenAddress) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(domainId, tokenAddress));
    }

    /**
     * @dev Add/Update supported domain
     */
    function updateSupportedDomainHyperlane(mapping(uint32 => bool) storage supportedDomainsHyperlane, uint32 domainId, bool supported, address owner, address sender) internal {
        require(sender == owner, "Only owner");
        supportedDomainsHyperlane[domainId] = supported;
    }

    /**
     * @dev Update token route for specific domain
     */
    function updateTokenRouteHyperlane(
        mapping(bytes32 => TokenRouteHyperlane) storage routesByDomainAndTokenHyperlane,
        mapping(address => bytes32) storage warpRouteToKeyHyperlane,
        mapping(uint32 => address[]) storage tokensByDomainHyperlane,
        mapping(uint32 => bool) storage supportedDomainsHyperlane,
        uint32 destinationDomainId,
        address tokenAddress,
        address warpRouteAddress,
        address owner,
        address sender
    ) internal {
        require(sender == owner, "Only owner");
        require(supportedDomainsHyperlane[destinationDomainId], "Domain not supported");
        require(tokenAddress != address(0), "Invalid token address");
        require(warpRouteAddress != address(0), "Invalid warp route address");
        bytes32 routeKey = getRouteKeyHyperlane(destinationDomainId, tokenAddress);
        if (routesByDomainAndTokenHyperlane[routeKey].warpRouteAddress != address(0)) {
            delete warpRouteToKeyHyperlane[routesByDomainAndTokenHyperlane[routeKey].warpRouteAddress];
        }
        routesByDomainAndTokenHyperlane[routeKey] = TokenRouteHyperlane({
            warpRouteAddress: warpRouteAddress,
            tokenAddress: tokenAddress,
            destinationDomain: destinationDomainId
        });
        warpRouteToKeyHyperlane[warpRouteAddress] = routeKey;
        bool tokenExists = false;
        address[] storage tokens = tokensByDomainHyperlane[destinationDomainId];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenAddress) {
                tokenExists = true;
                break;
            }
        }
        if (!tokenExists) {
            tokensByDomainHyperlane[destinationDomainId].push(tokenAddress);
        }
    }

    /**
     * @dev Remove token route
     */
    function removeTokenRouteHyperlane(
        mapping(bytes32 => TokenRouteHyperlane) storage routesByDomainAndTokenHyperlane,
        mapping(address => bytes32) storage warpRouteToKeyHyperlane,
        mapping(uint32 => address[]) storage tokensByDomainHyperlane,
        uint32 destinationDomainId,
        address tokenAddress,
        address owner,
        address sender
    ) internal {
        require(sender == owner, "Only owner");
        bytes32 routeKey = getRouteKeyHyperlane(destinationDomainId, tokenAddress);
        TokenRouteHyperlane memory route = routesByDomainAndTokenHyperlane[routeKey];
        require(route.warpRouteAddress != address(0), "Token route not found");
        delete warpRouteToKeyHyperlane[route.warpRouteAddress];
        delete routesByDomainAndTokenHyperlane[routeKey];
        address[] storage tokens = tokensByDomainHyperlane[destinationDomainId];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenAddress) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }

    /**
     * @dev Batch update multiple routes
     */
    function batchUpdateTokenRouteHyperlanes(
        mapping(bytes32 => TokenRouteHyperlane) storage routesByDomainAndTokenHyperlane,
        mapping(address => bytes32) storage warpRouteToKeyHyperlane,
        mapping(uint32 => address[]) storage tokensByDomainHyperlane,
        mapping(uint32 => bool) storage supportedDomainsHyperlane,
        uint32[] calldata destinationDomainIds,
        address[] calldata tokenAddresses,
        address[] calldata warpRouteAddresses,
        address owner,
        address sender
    ) internal {
        require(sender == owner, "Only owner");
        require(
            destinationDomainIds.length == tokenAddresses.length && 
            tokenAddresses.length == warpRouteAddresses.length,
            "Array lengths mismatch"
        );
        for (uint256 i = 0; i < destinationDomainIds.length; i++) {
            updateTokenRouteHyperlane(
                routesByDomainAndTokenHyperlane,
                warpRouteToKeyHyperlane,
                tokensByDomainHyperlane,
                supportedDomainsHyperlane,
                destinationDomainIds[i],
                tokenAddresses[i],
                warpRouteAddresses[i],
                owner,
                sender
            );
        }
    }
}
