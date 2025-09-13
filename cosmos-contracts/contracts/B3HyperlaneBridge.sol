// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import {IHypERC20} from "./interfaces/IHypERC20.sol";
import {TokenRouteHyperlane} from "./structs/hyperlane/TokenRouteHyperlane.sol";
import {TokenFeeConfig} from "./structs/hyperlane/TokenFeeConfig.sol";
import {HyperlaneBridgeEvents} from "./events/hyperlane/HyperlaneBridgeEvents.sol";
import {FeeLogic} from "./logic/hyperlane/FeeLogic.sol";
import {RouteLogic} from "./logic/hyperlane/RouteLogic.sol";
import {StringNumberUtils} from "./libs/StringNumberUtils.sol";
import {ISeiOracle} from "./interfaces/ISeiOracle.sol";
import {MinMaxFeeStorage} from "./logic/hyperlane/FeeLogic.sol";

contract B3HyperlaneBridge is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;


    // ============ STATE VARIABLES ============

    // Hyperlane configuration
    address public hyperlaneMailbox;

    // Route mappings
    mapping(bytes32 => TokenRouteHyperlane) public routesByDomainAndTokenHyperlane;
    mapping(address => bytes32) public warpRouteToKeyHyperlane;
    mapping(uint32 => address[]) public tokensByDomainHyperlane;
    mapping(uint32 => bool) public supportedDomainsHyperlane;

    // Fee configuration
    MinMaxFeeStorage internal minMaxFeeStorage;
    mapping(address => TokenFeeConfig) public tokenFeeConfigs;

    // ============ EVENTS ============
    
    event TokenFeeConfigUpdated(address indexed tokenAddress, uint256 fixedFee, uint256 feeRate, uint8 decimals);
    event MinMaxFeeBridgeUpdated(uint256 minFee, uint256 maxFee);

    // ============ CONSTRUCTOR ============

    constructor(address _hyperlaneMailbox) Ownable(msg.sender) {
        require(_hyperlaneMailbox != address(0), "Invalid Hyperlane mailbox");
        hyperlaneMailbox = _hyperlaneMailbox;
    }

    // ============ ROUTE MANAGEMENT FUNCTIONS ============

    /**
     * @dev Generate a route key from domainId and token address
     */
    function getRouteKeyHyperlane(uint32 domainId, address tokenAddress) public pure returns (bytes32) {
        // Use RouteLogic library function
        return RouteLogic.getRouteKeyHyperlane(domainId, tokenAddress);
    }
    
    /**
     * @dev Add/Update supported domain
     */
    function updateSupportedDomainHyperlane(uint32 domainId, bool supported) external onlyOwner {
        // Use RouteLogic library function with storage mappings
        RouteLogic.updateSupportedDomainHyperlane(
            supportedDomainsHyperlane,
            domainId,
            supported,
            owner(),
            msg.sender
        );
        
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
        // Use RouteLogic library function with all storage mappings
        RouteLogic.updateTokenRouteHyperlane(
            routesByDomainAndTokenHyperlane,
            warpRouteToKeyHyperlane,
            tokensByDomainHyperlane,
            supportedDomainsHyperlane,
            destinationDomainId,
            tokenAddress,
            warpRouteAddress,
            owner(),
            msg.sender
        );
        
        emit HyperlaneBridgeEvents.TokenRouteHyperlaneUpdated(destinationDomainId, tokenAddress, warpRouteAddress);
    }
    
    /**
     * @dev Remove token route
     */
    function removeTokenRouteHyperlane(uint32 destinationDomainId, address tokenAddress) external onlyOwner {
        // Use RouteLogic library function with required storage mappings
        RouteLogic.removeTokenRouteHyperlane(
            routesByDomainAndTokenHyperlane,
            warpRouteToKeyHyperlane,
            tokensByDomainHyperlane,
            destinationDomainId,
            tokenAddress,
            owner(),
            msg.sender
        );
        
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
        // Use RouteLogic library function with all required mappings
        RouteLogic.batchUpdateTokenRouteHyperlanes(
            routesByDomainAndTokenHyperlane,
            warpRouteToKeyHyperlane,
            tokensByDomainHyperlane,
            supportedDomainsHyperlane,
            destinationDomainIds,
            tokenAddresses,
            warpRouteAddresses,
            owner(),
            msg.sender
        );
        // Emit events here for each update
        for (uint256 i = 0; i < destinationDomainIds.length; i++) {
            emit HyperlaneBridgeEvents.TokenRouteHyperlaneUpdated(
                destinationDomainIds[i], 
                tokenAddresses[i], 
                warpRouteAddresses[i]
            );
        }
    }


    // ============ FEE MANAGEMENT FUNCTIONS ============

    /// @dev Set token fee configuration (calls FeeLogic)
    function setTokenFeeConfig(
        address tokenAddress,
        uint256 fixedFee,
        uint256 feeRate,
        uint8 decimals
    ) external onlyOwner {
        FeeLogic.setTokenFeeConfig(tokenFeeConfigs, tokenAddress, fixedFee, feeRate, decimals);
    }


    /// @dev Set minimum and maximum bridge fees (calls FeeLogic)
    function setMinMaxFeeBridge(uint256 minFee, uint256 maxFee) external onlyOwner {
        FeeLogic.setMinMaxFeeBridge(minMaxFeeStorage, minFee, maxFee);
        emit MinMaxFeeBridgeUpdated(minFee, maxFee);
    }


    /// @dev Batch update multiple token fee configurations (calls FeeLogic)
    function batchUpdateTokenFeeConfigs(
        address[] calldata tokenAddresses,
        uint256[] calldata fixedFees,
        uint256[] calldata feeRates,
        uint8[] calldata decimalsArray
    ) external onlyOwner {
        FeeLogic.batchUpdateTokenFeeConfigs(tokenFeeConfigs, tokenAddresses, fixedFees, feeRates, decimalsArray);
    }




    // ============ PRICE & FEE CALCULATION FUNCTIONS ============

    /**
     * @dev Calculate the protocol bridge fee for a given token and amount
     * Fee will be calculated in ETH first, then converted to SEI through USD rates
     */
    function getMyBridgeFee(
        address tokenAddress,
        uint256 amount
    ) internal view returns (uint256) {
        return FeeLogic.getMyBridgeFee(
            tokenFeeConfigs,
            minMaxFeeStorage,
            tokenAddress,
            amount
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
        
        return FeeLogic.checkBridgeFeeHyperlane(
            destinationDomainId,
            route.warpRouteAddress
        );
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
        // Get my bridge fee (use SEI-based calculation by default)
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
        uint256 senderBalance = token.balanceOf(msg.sender);
                require(senderBalance >= amount, string(abi.encodePacked("Insufficient balance: balance=", StringNumberUtils.toString(senderBalance), ", amount=", StringNumberUtils.toString(amount))));
        
        // Transfer tokens to this contract and approve warp route
        require(token.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");
        token.transferFrom(msg.sender, address(this), amount);
        token.approve(route.warpRouteAddress, amount);
        
        // Convert recipient to bytes32
        bytes32 recipientBytes32 = bytes32(uint256(uint160(recipient)));
        
        // Bridge tokens via Hyperlane Warp Route (only pay Hyperlane fee)
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
        external view returns (TokenRouteHyperlane memory)
    {
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
     * @dev Emergency withdraw ETH/SEI
     */
    function emergencyWithdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // ============ RECEIVE FUNCTION ============
    
    receive() external payable {}
}