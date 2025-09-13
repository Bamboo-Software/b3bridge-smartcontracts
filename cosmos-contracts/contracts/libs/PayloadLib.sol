// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library PayloadLib {
    function encode(
        address token,
        address recipient,
        uint256 amount,
        uint256 destinationChainId
    ) internal pure returns (bytes memory) {
        return abi.encode(token, recipient, amount, destinationChainId);
    }

    function decode(bytes memory payload)
        internal
        pure
        returns (
            address token,
            address recipient,
            uint256 amount,
            uint256 destinationChainId
        )
    {
        (token, recipient, amount, destinationChainId) = abi.decode(
            payload,
            (address, address, uint256, uint256)
        );
    }
}
