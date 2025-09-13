// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title FeeLogic
 * @dev Library for fee calculation and token fee config management for HyperlaneBridge.
 */

import {TokenFeeConfig} from "../../structs/TokenRouteHyperlane.sol";

library FeeLogic {

    /**
     * @dev Set token fee configuration.
     */
    function setTokenFeeConfig(
        mapping(address => TokenFeeConfig) storage tokenFeeConfigs,
        address tokenAddress,
        uint256 fixedFee,
        uint256 feeRate,
        uint8 decimals
    ) internal {
        tokenFeeConfigs[tokenAddress] = TokenFeeConfig({
            fixedFee: fixedFee,
            feeRate: feeRate,
            decimals: decimals,
            isSupported: true
        });
    }

    /**
     * @dev Batch update multiple token fee configurations.
     */
    function batchUpdateTokenFeeConfigs(
        mapping(address => TokenFeeConfig) storage tokenFeeConfigs,
        address[] calldata tokenAddresses,
        uint256[] calldata fixedFees,
        uint256[] calldata feeRates,
        uint8[] calldata decimalsArray
    ) internal {
        require(
            tokenAddresses.length == fixedFees.length &&
            fixedFees.length == feeRates.length &&
            feeRates.length == decimalsArray.length,
            "Array lengths mismatch"
        );
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            setTokenFeeConfig(tokenFeeConfigs, tokenAddresses[i], fixedFees[i], feeRates[i], decimalsArray[i]);
        }
    }

    /**
     * @dev Complete batch setup for tokens (fee config + price feed).
     */
    function batchCompleteTokenSetup(
        mapping(address => TokenFeeConfig) storage tokenFeeConfigs,
        mapping(address => AggregatorV3Interface) storage tokenPriceFeeds,
        address[] calldata tokenAddresses,
        uint256[] calldata fixedFees,
        uint256[] calldata feeRates,
        uint8[] calldata decimalsArray,
        address[] calldata priceFeeds
    ) internal {
        require(
            tokenAddresses.length == fixedFees.length &&
            fixedFees.length == feeRates.length &&
            feeRates.length == decimalsArray.length &&
            decimalsArray.length == priceFeeds.length,
            "Array lengths mismatch"
        );
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            setTokenFeeConfig(tokenFeeConfigs, tokenAddresses[i], fixedFees[i], feeRates[i], decimalsArray[i]);
            if (priceFeeds[i] != address(0)) {
                tokenPriceFeeds[tokenAddresses[i]] = AggregatorV3Interface(priceFeeds[i]);
            }
        }
    }

    /**
     * @dev Get token price in USD with 8 decimals from Chainlink price feed.
     */
    function getTokenPrice(
        address tokenAddress,
        mapping(address => AggregatorV3Interface) storage tokenPriceFeeds
    ) internal view returns (int256 price) {
        if (address(tokenPriceFeeds[tokenAddress]) != address(0)) {
            ( , int256 feedPrice, , , ) = tokenPriceFeeds[tokenAddress].latestRoundData();
            require(feedPrice > 0, "Invalid token price from feed");
            return feedPrice;
        }
        revert("No price feed available for token");
    }

    /**
     * @dev Calculate bridge fee for a given token and amount.
     */
    function getMyBridgeFee(
        TokenFeeConfig memory config,
        uint256 amount,
        address tokenAddress,
        mapping(address => AggregatorV3Interface) storage tokenPriceFeeds,
        uint256 minFeeBridge,
        uint256 maxFeeBridge
    ) internal view returns (uint256) {
        require(config.isSupported, "Token not supported for fee calculation");
        uint256 dynamicFee;
        if (tokenAddress == address(0)) {
            dynamicFee = (amount * config.feeRate) / 10000;
        } else {
            int256 tokenPrice = getTokenPrice(tokenAddress, tokenPriceFeeds);
            int256 nativePrice = getTokenPrice(address(0), tokenPriceFeeds);
            require(tokenPrice > 0, "Invalid token price");
            require(nativePrice > 0, "Invalid native price");
            uint256 tokenUsdPrice = uint256(tokenPrice);
            uint256 nativeUsdPrice = uint256(nativePrice);
            uint256 tokenFeeAmount = (amount * config.feeRate) / 10000;
            uint256 feeValueUsd = (tokenFeeAmount * tokenUsdPrice) / (10 ** config.decimals);
            dynamicFee = (feeValueUsd * 1e18) / nativeUsdPrice;
        }
        uint256 totalFee = config.fixedFee + dynamicFee;
        if (minFeeBridge > 0 && totalFee < minFeeBridge) {
            totalFee = minFeeBridge;
        } else if (maxFeeBridge > 0 && totalFee > maxFeeBridge) {
            totalFee = maxFeeBridge;
        }
        return totalFee;
    }
}
