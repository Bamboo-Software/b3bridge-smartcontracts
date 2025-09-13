// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// import "../structs/Structs.sol";
// import "../libs/SignatureLib.sol";
// import "../interfaces/ICustomCoin.sol";

// library ValidatorLogic {
//     // Kiểm tra validator
//     function isValidator(address addr, address[] storage validators) internal view returns (bool) {
//         for (uint256 i = 0; i < validators.length; i++) {
//             if (validators[i] == addr) return true;
//         }
//         return false;
//     }

//     // Thêm validator, trả về true nếu thành công
//     function addValidator(address validator, address[] storage validators) internal returns (bool) {
//         require(validator != address(0), "Invalid validator address");
//         require(!isValidator(validator, validators), "Validator already exists");
//         require(validators.length < type(uint256).max, "Validator list full");
//         validators.push(validator);
//         return true;
//     }

//     // Xóa validator, trả về true nếu thành công
//     function removeValidator(address validator, address[] storage validators) internal returns (bool) {
//         for (uint256 i = 0; i < validators.length; i++) {
//             if (validators[i] == validator) {
//                 validators[i] = validators[validators.length - 1];
//                 validators.pop();
//                 return true;
//             }
//         }
//         return false;
//     }

//     // Tính threshold mặc định (2/3 + 1)
//     function calcThreshold(address[] storage validators) internal view returns (uint256) {
//         return (validators.length * 2 + 2) / 3;
//     }

//     // Xử lý ký và thực thi mint nếu đủ threshold
//     function processSignature(
//         address sender,
//         bytes memory signature,
//         Payload memory payload,
//         address[] storage validators,
//         uint256 threshold,
//         mapping(bytes32 => mapping(address => bool)) storage signatures,
//         mapping(bytes32 => uint256) storage signatureCount,
//         mapping(bytes32 => Payload) storage payloadData,
//         mapping(bytes32 => bool) storage processedMessages
//     ) internal returns (bool executed, address recipient, address token, uint256 amount) {
//         require(isValidator(sender, validators), "Not validator");
//         require(!signatures[payload.txKey][sender], "Already signed");
//         require(SignatureLib.verifySignature(payload.txKey, signature, sender), "Invalid signature");

//         if (signatureCount[payload.txKey] == 0) {
//             require(payload.to != address(0), "Invalid recipient address");
//             require(payload.amount > 0, "Amount must be > 0");
//             if (payload.tokenType == 1) {
//                 require(payload.tokenAddr != address(0), "Invalid token address");
//             } else if (payload.tokenType != 0) {
//                 revert("Unsupported token type");
//             }
//             payloadData[payload.txKey] = payload;
//         } else {
//             Payload memory stored = payloadData[payload.txKey];
//             require(
//                 stored.txKey == payload.txKey &&
//                 stored.from == payload.from &&
//                 stored.to == payload.to &&
//                 stored.tokenAddr == payload.tokenAddr &&
//                 stored.amount == payload.amount,
//                 "Data mismatch"
//             );
//         }

//         signatures[payload.txKey][sender] = true;
//         signatureCount[payload.txKey]++;

//         // Nếu đủ threshold thì thực thi mint
//         if (signatureCount[payload.txKey] >= threshold && !processedMessages[payload.txKey]) {
//             processedMessages[payload.txKey] = true;
//             Payload memory data = payloadData[payload.txKey];
//             require(data.amount > 0, "Invalid amount");
//             require(data.to != address(0), "Invalid recipient address");
//             require(data.tokenAddr != address(0), "Invalid token address");
//             // Mint token
//             ICustomCoin(data.tokenAddr).mint(data.to, data.amount);

//             // Cleanup
//             delete payloadData[payload.txKey];
//             delete signatureCount[payload.txKey];

//             executed = true;
//             recipient = data.to;
//             token = data.tokenAddr;
//             amount = data.amount;
//         }
//     }
// }