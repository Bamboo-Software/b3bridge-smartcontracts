// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import {IHypERC20} from "./interfaces/IHypERC20.sol";

import {TokenRouteHyperlane, TokenFeeConfig} from "./structs/TokenRouteHyperlane.sol";
import {HyperlaneBridgeEvents} from "./events/HyperlaneBridgeEvents.sol";
import {FeeLogic} from "./logics/hyperlaneBridge/FeeLogic.sol";

contract B3HyperlaneBridge is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ STATE VARIABLES ============
    
    // Hyperlane Configuration
    address public hyperlaneMailbox;
    
    // Route Mappings
    mapping(bytes32 => TokenRouteHyperlane) public routesByDomainAndTokenHyperlane;
    mapping(address => bytes32) public warpRouteToKeyHyperlane;
    mapping(uint32 => address[]) public tokensByDomainHyperlane;
    mapping(uint32 => bool) public supportedDomainsHyperlane;

    // Fee Configuration
    uint256 public minFeeBridge;  // Minimum bridge fee in wei
    uint256 public maxFeeBridge;  // Maximum bridge fee in wei (0 = no max)
    mapping(address => TokenFeeConfig) public tokenFeeConfigs;
    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;


    // ============ CONSTRUCTOR ============
    
    constructor(address _hyperlaneMailbox, address _nativePriceFeed) Ownable() {
        require(_hyperlaneMailbox != address(0), "Invalid Hyperlane mailbox");
        require(_nativePriceFeed != address(0), "Invalid native price feed");
        hyperlaneMailbox = _hyperlaneMailbox;
        
        // Set native price feed
        tokenPriceFeeds[address(0)] = AggregatorV3Interface(_nativePriceFeed);
        emit HyperlaneBridgeEvents.TokenPriceFeedUpdated(address(0), _nativePriceFeed);
    }

    // ============ ROUTE MANAGEMENT FUNCTIONS ============
    
    /**
     * @dev Generate route key from domainId and token address
     */
    function getRouteKeyHyperlane(uint32 domainId, address tokenAddress) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(domainId, tokenAddress));
    }
    
    /**
     * @dev Add/Update supported domain
     */
    function updateSupportedDomainHyperlane(uint32 domainId, bool supported) external onlyOwner {
        supportedDomainsHyperlane[domainId] = supported;
        emit HyperlaneBridgeEvents.DomainHyperlaneUpdated(domainId, supported);
    }
    
    /**
     * @dev Update token route for specific domain
     */
    function updateTokenRouteHyperlane(
        uint32 destinationDomainId,
        address tokenAddress,
        address warpRouteAddress
    ) public onlyOwner {
        require(supportedDomainsHyperlane[destinationDomainId], "Domain not supported");
        require(tokenAddress != address(0), "Invalid token address");
        require(warpRouteAddress != address(0), "Invalid warp route address");
        
        bytes32 routeKey = getRouteKeyHyperlane(destinationDomainId, tokenAddress);
        
        // Remove old warp route mapping if exists
        if (routesByDomainAndTokenHyperlane[routeKey].warpRouteAddress != address(0)) {
            delete warpRouteToKeyHyperlane[routesByDomainAndTokenHyperlane[routeKey].warpRouteAddress];
        }
        
        // Update route mapping
        routesByDomainAndTokenHyperlane[routeKey] = TokenRouteHyperlane({
            warpRouteAddress: warpRouteAddress,
            tokenAddress: tokenAddress,
            destinationDomain: destinationDomainId
        });
        
        // Update reverse mapping
        warpRouteToKeyHyperlane[warpRouteAddress] = routeKey;
        
        // Add to tokens list for domain if not exists
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
        
        emit HyperlaneBridgeEvents.TokenRouteHyperlaneUpdated(destinationDomainId, tokenAddress, warpRouteAddress);
    }
    
    /**
     * @dev Remove token route
     */
    function removeTokenRouteHyperlane(uint32 destinationDomainId, address tokenAddress) external onlyOwner {
        bytes32 routeKey = getRouteKeyHyperlane(destinationDomainId, tokenAddress);
        TokenRouteHyperlane memory route = routesByDomainAndTokenHyperlane[routeKey];
        require(route.warpRouteAddress != address(0), "Token route not found");
        
        // Remove mappings
        delete warpRouteToKeyHyperlane[route.warpRouteAddress];
        delete routesByDomainAndTokenHyperlane[routeKey];
        
        // Remove from tokens list
        address[] storage tokens = tokensByDomainHyperlane[destinationDomainId];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenAddress) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
        
        emit HyperlaneBridgeEvents.TokenRouteHyperlaneUpdated(destinationDomainId, tokenAddress, address(0));
    }
    
    /**
     * @dev Batch update multiple routes
     */
    function batchUpdateTokenRouteHyperlanes(
        uint32[] calldata destinationDomainIds,
        address[] calldata tokenAddresses,
        address[] calldata warpRouteAddresses
    ) external onlyOwner {
        require(
            destinationDomainIds.length == tokenAddresses.length && 
            tokenAddresses.length == warpRouteAddresses.length,
            "Array lengths mismatch"
        );
        
        for (uint256 i = 0; i < destinationDomainIds.length; i++) {
            updateTokenRouteHyperlane(destinationDomainIds[i], tokenAddresses[i], warpRouteAddresses[i]);
        }
    }

    // ============ FEE MANAGEMENT FUNCTIONS ============

    /**
     * @dev Set token fee configuration (delegated to FeeLogic)
     */
    function setTokenFeeConfig(
        address tokenAddress,
        uint256 fixedFee,
        uint256 feeRate,
        uint8 decimals
    ) external onlyOwner {
        FeeLogic.setTokenFeeConfig(tokenFeeConfigs, tokenAddress, fixedFee, feeRate, decimals);
        emit HyperlaneBridgeEvents.TokenFeeConfigUpdated(tokenAddress, fixedFee, feeRate, decimals);
    }

    /**
     * @dev Set price feed for a token
     */
    function setTokenPriceFeed(address tokenAddress, address priceFeed) external onlyOwner {
        require(priceFeed != address(0), "Invalid price feed");
        tokenPriceFeeds[tokenAddress] = AggregatorV3Interface(priceFeed);
        emit HyperlaneBridgeEvents.TokenPriceFeedUpdated(tokenAddress, priceFeed);
    }

    /**
     * @dev Set minimum and maximum bridge fees
     */
    function setMinMaxFeeBridge(uint256 minFee, uint256 maxFee) external onlyOwner {
        require(maxFee == 0 || maxFee >= minFee, "Max fee must be >= min fee");
        minFeeBridge = minFee;
        maxFeeBridge = maxFee;
        emit HyperlaneBridgeEvents.MinMaxFeeBridgeUpdated(minFee, maxFee);
    }

    /**
     * @dev Remove price feed for a token
     */
    function removeTokenPriceFeed(address tokenAddress) external onlyOwner {
        delete tokenPriceFeeds[tokenAddress];
        emit HyperlaneBridgeEvents.TokenPriceFeedUpdated(tokenAddress, address(0));
    }

    /**
     * @dev Batch update multiple token fee configurations (delegated to FeeLogic)
     */
    function batchUpdateTokenFeeConfigs(
        address[] calldata tokenAddresses,
        uint256[] calldata fixedFees,
        uint256[] calldata feeRates,
        uint8[] calldata decimalsArray
    ) external onlyOwner {
        FeeLogic.batchUpdateTokenFeeConfigs(tokenFeeConfigs, tokenAddresses, fixedFees, feeRates, decimalsArray);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            emit HyperlaneBridgeEvents.TokenFeeConfigUpdated(tokenAddresses[i], fixedFees[i], feeRates[i], decimalsArray[i]);
        }
    }

    /**
     * @dev Batch set price feeds for multiple tokens
     */
    function batchSetTokenPriceFeeds(
        address[] calldata tokenAddresses,
        address[] calldata priceFeeds
    ) external onlyOwner {
        require(tokenAddresses.length == priceFeeds.length, "Array lengths mismatch");
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            require(priceFeeds[i] != address(0), "Invalid price feed");
            tokenPriceFeeds[tokenAddresses[i]] = AggregatorV3Interface(priceFeeds[i]);
            emit HyperlaneBridgeEvents.TokenPriceFeedUpdated(tokenAddresses[i], priceFeeds[i]);
        }
    }

    /**
     * @dev Complete batch setup for tokens (fee config + price feed, delegated to FeeLogic)
     */
    function batchCompleteTokenSetup(
        address[] calldata tokenAddresses,
        uint256[] calldata fixedFees,
        uint256[] calldata feeRates,
        uint8[] calldata decimalsArray,
        address[] calldata priceFeeds
    ) external onlyOwner {
        FeeLogic.batchCompleteTokenSetup(tokenFeeConfigs, tokenPriceFeeds, tokenAddresses, fixedFees, feeRates, decimalsArray, priceFeeds);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            emit HyperlaneBridgeEvents.TokenFeeConfigUpdated(tokenAddresses[i], fixedFees[i], feeRates[i], decimalsArray[i]);
            if (priceFeeds[i] != address(0)) {
                emit HyperlaneBridgeEvents.TokenPriceFeedUpdated(tokenAddresses[i], priceFeeds[i]);
            }
        }
    }

    // ============ PRICE & FEE CALCULATION FUNCTIONS ============

    /**
     * @dev Get token price in USD with 8 decimals (delegated to FeeLogic)
     */
    function getTokenPrice(address tokenAddress) public view returns (int256 price) {
        return FeeLogic.getTokenPrice(tokenAddress, tokenPriceFeeds);
    }

    /**
     * @dev Calculate my bridge fee (delegated to FeeLogic)
     */
    function getMyBridgeFee(
        address tokenAddress,
        uint256 amount
    ) internal view returns (uint256) {
        return FeeLogic.getMyBridgeFee(
            tokenFeeConfigs[tokenAddress],
            amount,
            tokenAddress,
            tokenPriceFeeds,
            minFeeBridge,
            maxFeeBridge
        );
    }

    /**
     * @dev Check Hyperlane bridge fee (internal function)
     */
    function checkBridgeFeeHyperlane(
        uint32 destinationDomainId,
        address tokenAddress
    ) internal view returns (uint256 fee) {
        bytes32 routeKey = getRouteKeyHyperlane(destinationDomainId, tokenAddress);
        TokenRouteHyperlane memory route = routesByDomainAndTokenHyperlane[routeKey];
        require(route.warpRouteAddress != address(0), "Token route not found");

        
        // Create message body for fee calculation
        IHypERC20 warpRoute = IHypERC20(route.warpRouteAddress);
        fee = warpRoute.quoteGasPayment(destinationDomainId);
    }

    /**
     * @dev Get total bridge fee (my bridge fee + Hyperlane fee) with breakdown
     */
    function getTotalBridgeFee(
        uint32 destinationDomainId,
        address tokenAddress,
        uint256 amount,
        address recipient
    ) external view returns (uint256) {
        // Get my bridge fee
        uint256 myFee = getMyBridgeFee(tokenAddress, amount);
        
        // Get Hyperlane bridge fee
        uint256 hyperlaneFee = checkBridgeFeeHyperlane(destinationDomainId, tokenAddress);
        
        // Return total fee
        return myFee + hyperlaneFee;
    }

    // ============ BRIDGE FUNCTIONS ============
    
    /**
     * @dev Bridge tokens to any supported domain
     */
    function bridgeTokenHyperlane(
        uint32 destinationDomainId,
        address tokenAddress,
        uint256 amount,
        address recipient
    ) external payable whenNotPaused nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(supportedDomainsHyperlane[destinationDomainId], "Destination domain not supported");
        
        bytes32 routeKey = getRouteKeyHyperlane(destinationDomainId, tokenAddress);
        TokenRouteHyperlane memory route = routesByDomainAndTokenHyperlane[routeKey];
        require(route.warpRouteAddress != address(0), "Token route not found");
        
        IHypERC20 warpRoute = IHypERC20(route.warpRouteAddress);
        
        // Check Hyperlane bridge fee
        uint256 hyperlaneRequiredFee = checkBridgeFeeHyperlane(destinationDomainId, tokenAddress);
        
        // Check my bridge fee
        uint256 myBridgeFee = getMyBridgeFee(tokenAddress, amount);
        
        uint256 totalRequiredFee = hyperlaneRequiredFee + myBridgeFee;
        require(msg.value >= totalRequiredFee, "Insufficient fee");
        
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(token.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");
            
        token.safeTransferFrom(msg.sender, address(this), amount);
        
        token.safeApprove(route.warpRouteAddress, amount);

        bytes32 recipientBytes32 = bytes32(uint256(uint160(recipient)));

        // Bridge tokens (only pay Hyperlane fee)
        bytes32 messageId = warpRoute.transferRemote{value: hyperlaneRequiredFee}(
            destinationDomainId,
            recipientBytes32,
            amount
        );
        
        emit HyperlaneBridgeEvents.TokenHyperlaneBridged(
            msg.sender,
            tokenAddress,
            recipientBytes32,
            amount,
            messageId,
            destinationDomainId
        );
        
        // Refund excess fee if any (after keeping my bridge fee)
        uint256 excessFee = msg.value - totalRequiredFee;
        if (excessFee > 0) {
            payable(msg.sender).transfer(excessFee);
        }
        
        // My bridge fee stays in the contract for owner to withdraw
    }

    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get route by domain and token
     */
    function getTokenRouteHyperlane(uint32 destinationDomainId, address tokenAddress) 
        external view returns (TokenRouteHyperlane memory) {
        bytes32 routeKey = getRouteKeyHyperlane(destinationDomainId, tokenAddress);
        return routesByDomainAndTokenHyperlane[routeKey];
    }
    
    /**
     * @dev Get route by warp route address
     */
    function getRouteByWarpAddressHyperlane(address warpRouteAddress) 
        external view returns (TokenRouteHyperlane memory) {
        bytes32 routeKey = warpRouteToKeyHyperlane[warpRouteAddress];
        return routesByDomainAndTokenHyperlane[routeKey];
    }
    
    /**
     * @dev Get all tokens for a domain
     */
    function getTokensForDomainHyperlane(uint32 domainId) external view returns (address[] memory) {
        return tokensByDomainHyperlane[domainId];
    }

    /**
     * @dev Get fee configuration for a token
     */
    function getTokenFeeConfig(address tokenAddress) external view returns (TokenFeeConfig memory) {
        return tokenFeeConfigs[tokenAddress];
    }

    /**
     * @dev Get price feed address for a token
     */
    function getTokenPriceFeed(address tokenAddress) external view returns (address) {
        return address(tokenPriceFeeds[tokenAddress]);
    }

    /**
     * @dev Check if token has price feed configured
     */
    function hasTokenPriceFeed(address tokenAddress) external view returns (bool) {
        return address(tokenPriceFeeds[tokenAddress]) != address(0);
    }

    /**
     * @dev Get current Hyperlane mailbox address
     */
    function getHyperlaneMailbox() external view returns (address) {
        return hyperlaneMailbox;
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @dev Set new Hyperlane mailbox address
     */
    function setHyperlaneMailbox(address newMailbox) external onlyOwner {
        require(newMailbox != address(0), "Invalid mailbox address");
        hyperlaneMailbox = newMailbox;
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ EMERGENCY FUNCTIONS ============
    
    /**
     * @dev Emergency withdraw token
     */
    function emergencyWithdrawToken(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.transfer(owner(), balance);
        }
    }
    
    /**
     * @dev Emergency withdraw Native
     */
    function emergencyWithdrawNativeToken() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // ============ RECEIVE FUNCTION ============
    
    receive() external payable {}
}