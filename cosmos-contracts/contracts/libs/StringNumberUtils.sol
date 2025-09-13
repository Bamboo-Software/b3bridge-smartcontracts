// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library StringNumberUtils {
    /**
     * @dev Convert a uint256 to its decimal string representation
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Convert a decimal string to uint256, handling decimals
     * @param s The string to convert, e.g. "123.456789"
     * @return The converted uint256 value with 18 decimals of precision
     */
    function stringToUint256(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        uint256 decimals = 18;
        bool decimalFound = false;
        uint256 decimalCount = 0;

        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ".") {
                decimalFound = true;
                continue;
            }
            if (!decimalFound) {
                result = result * 10 + uint256(uint8(b[i]) - 48);
            } else {
                if (decimalCount < decimals) {
                    result = result * 10 + uint256(uint8(b[i]) - 48);
                    decimalCount++;
                }
            }
        }

        while (decimalCount < decimals) {
            result = result * 10;
            decimalCount++;
        }

        return result;
    }
}
