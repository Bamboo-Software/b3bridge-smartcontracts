// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title ISeiOracle Interface
/// @notice Interface to get exchange rates from the Sei Oracle
interface ISeiOracle {
    /// @notice Struct representing an oracle exchange rate
    struct OracleExchangeRate {
        string exchangeRate;
        string lastUpdate;
        int64 lastUpdateTimestamp;
    }

    /// @notice Struct representing a pair of denom and its oracle exchange rate
    struct DenomOracleExchangeRatePair {
        string denom;
        OracleExchangeRate oracleExchangeRateVal;
    }

    /// @notice Gets all exchange rates
    /// @return An array of denom and their corresponding oracle exchange rates
    function getExchangeRates()
        external
        view
        returns (DenomOracleExchangeRatePair[] memory);
}
