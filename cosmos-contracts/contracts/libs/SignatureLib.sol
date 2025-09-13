// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// library SignatureLib {
//     function recoverSigner(bytes32 message, bytes memory signature) internal pure returns (address) {
//         require(signature.length == 65, "Invalid signature length");

//         bytes32 r;
//         bytes32 s;
//         uint8 v;

//         assembly {
//             r := mload(add(signature, 32))
//             s := mload(add(signature, 64))
//             v := byte(0, mload(add(signature, 96)))
//         }

//         if (v < 27) {
//             v += 27;
//         }

//         require(v == 27 || v == 28, "Invalid v value");

//         bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
//         return ecrecover(ethSignedMessageHash, v, r, s);
//     }

//     function verifySignature(bytes32 txKey, bytes memory signature, address signer) internal pure returns (bool) {
//         return recoverSigner(txKey, signature) == signer;
//     }

//     function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
//         require(sig.length == 65, "Invalid signature length");
//         assembly {
//             r := mload(add(sig, 32))
//             s := mload(add(sig, 64))
//             v := byte(0, mload(add(sig, 96)))
//         }
//     }
// }