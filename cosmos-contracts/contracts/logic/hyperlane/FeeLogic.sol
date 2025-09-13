// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import {ISeiOracle} from "../../interfaces/ISeiOracle.sol";
import {TokenFeeConfig} from "../../structs/hyperlane/TokenFeeConfig.sol";
import {TokenRouteHyperlane} from "../../structs/hyperlane/TokenRouteHyperlane.sol";
import {OracleUtils} from "../../libs/OracleUtils.sol";
import {IHypERC20} from "../../interfaces/IHypERC20.sol";

struct MinMaxFeeStorage {
    uint256 minFeeBridge;
    uint256 maxFeeBridge;
}

library FeeLogic {

    function getMyBridgeFee(
        mapping(address => TokenFeeConfig) storage tokenFeeConfigs,
        MinMaxFeeStorage storage minMaxFeeStorage,
        address tokenAddress,
        uint256 amount
    ) internal view returns (uint256) {
        TokenFeeConfig memory config = tokenFeeConfigs[tokenAddress];
        require(config.decimals > 0, "Token not configured");
        
        uint256 fixedFee = config.fixedFee;
        uint256 normalizedAmount = amount / (10 ** config.decimals);
        uint256 dynamicFee = (normalizedAmount * config.feeRate * (10 ** config.decimals)) / 10000;
        uint256 totalFeeETH = fixedFee + dynamicFee;

        (uint256 ethUsdPrice, ) = OracleUtils.getEthUsdPrice();
        require(ethUsdPrice > 0, "Invalid ETH/USD price");

        (uint256 seiUsdPrice, ) = OracleUtils.getSeiUsdPrice();
        require(seiUsdPrice > 0, "Invalid SEI/USD price");

        uint256 totalFeeUSD = (totalFeeETH * ethUsdPrice) / 1e18;
        uint256 totalFeeSEI = (totalFeeUSD * 1e18) / seiUsdPrice;

        if (minMaxFeeStorage.minFeeBridge > 0 && totalFeeSEI < minMaxFeeStorage.minFeeBridge) {
            totalFeeSEI = minMaxFeeStorage.minFeeBridge;
        } else if (minMaxFeeStorage.maxFeeBridge > 0 && totalFeeSEI > minMaxFeeStorage.maxFeeBridge) {
            totalFeeSEI = minMaxFeeStorage.maxFeeBridge;
        }

        return totalFeeSEI;
    }

    function checkBridgeFeeHyperlane(
        uint32 destinationDomainId,
        address warpRouteAddress
    ) internal view returns (uint256 fee) {
        require(warpRouteAddress != address(0), "Token route not found");
        IHypERC20 warpRoute = IHypERC20(warpRouteAddress);
        fee = warpRoute.quoteGasPayment(destinationDomainId);
    }

    function setTokenFeeConfig(
        mapping(address => TokenFeeConfig) storage tokenFeeConfigs,
        address tokenAddress,
        uint256 fixedFee,
        uint256 feeRate,
        uint8 decimals
    ) internal {
        require(tokenAddress != address(0), "Invalid token address");
        TokenFeeConfig storage config = tokenFeeConfigs[tokenAddress];
        config.fixedFee = fixedFee;
        config.feeRate = feeRate;
        config.decimals = decimals;
    }

    function setMinMaxFeeBridge(
        MinMaxFeeStorage storage minMaxFeeStorage,
        uint256 minFee,
        uint256 maxFee
    ) internal {
        require(maxFee > 0 && minFee > 0 && maxFee >= minFee, "Invalid fee range");
        minMaxFeeStorage.minFeeBridge = minFee;
        minMaxFeeStorage.maxFeeBridge = maxFee;
    }

    function batchUpdateTokenFeeConfigs(
        mapping(address => TokenFeeConfig) storage tokenFeeConfigs,
        address[] calldata tokenAddresses,
        uint256[] calldata fixedFees,
        uint256[] calldata feeRates,
        uint8[] calldata decimalsArray
    ) internal {
        require(
            tokenAddresses.length == fixedFees.length &&
            tokenAddresses.length == feeRates.length &&
            tokenAddresses.length == decimalsArray.length,
            "Array lengths mismatch"
        );

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            setTokenFeeConfig(
                tokenFeeConfigs,
                tokenAddresses[i],
                fixedFees[i],
                feeRates[i],
                decimalsArray[i]
            );
        }
    }
}
