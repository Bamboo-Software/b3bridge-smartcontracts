// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISeiOracle} from "../interfaces/ISeiOracle.sol";
import {StringNumberUtils} from "./StringNumberUtils.sol";

library OracleUtils {
    ISeiOracle internal constant ORACLE = ISeiOracle(0x0000000000000000000000000000000000001008);

    /**
     * @dev Helper function to get ETH/USD price from oracle
     */
    function getEthUsdPrice() internal view returns (uint256 price, int64 timestamp) {
        try ORACLE.getExchangeRates() returns (ISeiOracle.DenomOracleExchangeRatePair[] memory rates) {
            for (uint256 i = 0; i < rates.length; i++) {
                if (keccak256(abi.encodePacked(rates[i].denom)) == keccak256(abi.encodePacked("ueth"))) {
                    require(
                        uint64(rates[i].oracleExchangeRateVal.lastUpdateTimestamp) >= block.timestamp - 1 hours,
                        "ETH price data too old"
                    );
                    return (
                        StringNumberUtils.stringToUint256(rates[i].oracleExchangeRateVal.exchangeRate),
                        rates[i].oracleExchangeRateVal.lastUpdateTimestamp
                    );
                }
            }
            revert("ETH/USD price not found");
        } catch {
            revert("Oracle call failed for ETH");
        }
    }

    /**
     * @dev Helper function to get SEI/USD price from oracle
     */
    function getSeiUsdPrice() internal view returns (uint256 price, int64 timestamp) {
        try ORACLE.getExchangeRates() returns (ISeiOracle.DenomOracleExchangeRatePair[] memory rates) {
            for (uint256 i = 0; i < rates.length; i++) {
                if (keccak256(abi.encodePacked(rates[i].denom)) == keccak256(abi.encodePacked("usei"))) {
                    require(
                        uint64(rates[i].oracleExchangeRateVal.lastUpdateTimestamp) >= block.timestamp - 1 hours,
                        "SEI price data too old"
                    );
                    return (
                        StringNumberUtils.stringToUint256(rates[i].oracleExchangeRateVal.exchangeRate),
                        rates[i].oracleExchangeRateVal.lastUpdateTimestamp
                    );
                }
            }
            revert("SEI/USD price not found");
        } catch {
            revert("Oracle call failed for SEI");
        }
    }
}
