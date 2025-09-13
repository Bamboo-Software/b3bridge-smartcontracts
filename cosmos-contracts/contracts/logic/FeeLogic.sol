// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// import "../interfaces/ICustomCoin.sol";

// library FeeLogic {
//     event FeeDistributed(address indexed validator, address token, uint256 amount);

//     function distributeFee(
//         address token,
//         address[] storage validators,
//         mapping(address => uint256) storage validatorFeeNative,
//         mapping(address => mapping(address => uint256)) storage validatorFeeERC20
//     ) internal {
//         uint256 validatorCount = validators.length;
//         require(validatorCount > 0, "No validators");

//         if (token == address(0)) {
//             uint256 totalFee;
//             for (uint256 i = 0; i < validatorCount; i++) {
//                 totalFee += validatorFeeNative[validators[i]];
//             }
//             require(address(this).balance >= totalFee, "Insufficient contract ETH balance");

//             for (uint256 i = 0; i < validatorCount; i++) {
//                 address validator = validators[i];
//                 uint256 fee = validatorFeeNative[validator];
//                 if (fee > 0) {
//                     validatorFeeNative[validator] = 0;
//                     (bool sent, ) = payable(validator).call{value: fee}("");
//                     require(sent, "Failed to send native token to validator");
//                     emit FeeDistributed(validator, address(0), fee);
//                 }
//             }
//         } else {
//             uint256 totalFee;
//             for (uint256 i = 0; i < validatorCount; i++) {
//                 totalFee += validatorFeeERC20[token][validators[i]];
//             }
//             require(ICustomCoin(token).balanceOf(address(this)) >= totalFee, "Insufficient contract token balance");

//             for (uint256 i = 0; i < validatorCount; i++) {
//                 address validator = validators[i];
//                 uint256 fee = validatorFeeERC20[token][validator];
//                 if (fee > 0) {
//                     validatorFeeERC20[token][validator] = 0;
//                     ICustomCoin(token).transfer(validator, fee);
//                     emit FeeDistributed(validator, token, fee);
//                 }
//             }
//         }
//     }

//     function getValidatorFees(
//         address token,
//         address[] storage validators,
//         mapping(address => uint256) storage validatorFeeNative,
//         mapping(address => mapping(address => uint256)) storage validatorFeeERC20
//     ) internal view returns (
//         uint256 totalFee,
//         address[] memory validatorsList,
//         uint256[] memory fees,
//         uint256 contractBalance
//     ) {
//         uint256 validatorCount = validators.length;
//         validatorsList = new address[](validatorCount);
//         fees = new uint256[](validatorCount);
//         totalFee = 0;

//         contractBalance = token == address(0)
//             ? address(this).balance
//             : ICustomCoin(token).balanceOf(address(this));

//         if (validatorCount == 0) {
//             return (totalFee, validatorsList, fees, contractBalance);
//         }

//         for (uint256 i = 0; i < validatorCount; i++) {
//             address validator = validators[i];
//             uint256 fee = token == address(0)
//                 ? validatorFeeNative[validator]
//                 : validatorFeeERC20[token][validator];
//             validatorsList[i] = validator;
//             fees[i] = fee;
//             totalFee += fee;
//         }

//         return (totalFee, validatorsList, fees, contractBalance);
//     }
// }