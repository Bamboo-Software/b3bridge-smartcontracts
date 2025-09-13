// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
// import "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
// import "../interfaces/ICustomCoin.sol";

// library CCIPLogic {
//     event MintTokenCCIP(address receiver, bytes32 tokenId, uint256 amount);
//     event BurnTokenCCIP(bytes32 indexed messageId, address indexed user, bytes32 tokenId, uint256 amount);
//     event DebugTokenAddress(bytes32 tokenId, address tokenAddress);
//     event DebugMsg(string message);
//     event DebugFee(uint256 fee);

//     function ccipReceive(
//         Client.Any2EVMMessage memory message,
//         mapping(bytes32 => address) storage tokenMapping
//     ) internal {
//         (address receiver, bytes32 tokenId, uint256 amount) = abi.decode(
//             message.data,
//             (address, bytes32, uint256)
//         );
//         address tokenAddress = tokenMapping[tokenId];
//         ICustomCoin(tokenAddress).mint(receiver, amount);
//         emit MintTokenCCIP(receiver, tokenId, amount);
//     }

//     function burnTokenCCIP(
//         address sender,
//         bytes32 tokenId,
//         uint256 amount,
//         uint256 msgValue,
//         address router,
//         address sourceBridge,
//         uint64 sourceChainSelector,
//         mapping(bytes32 => address) storage tokenMapping,
//         address owner
//     ) internal returns (bytes32) {
//         require(amount > 0, "Amount must be greater than 0");
//         address tokenAddress = tokenMapping[tokenId];
//         emit DebugTokenAddress(tokenId, tokenAddress);
//         require(tokenAddress != address(0), "Unsupported token");

//         emit DebugMsg("Start burnTokenCCIP");

//         uint256 allowance = ICustomCoin(tokenAddress).allowance(sender, address(this));
//         require(allowance >= amount, "Insufficient allowance");

//         uint256 userBalance = ICustomCoin(tokenAddress).balanceOf(sender);
//         require(userBalance >= amount, "Insufficient user balance");
//         emit DebugMsg("User balance OK");

//         bool success = ICustomCoin(tokenAddress).transferFrom(sender, address(this), amount);
//         require(success, "transferFrom failed");
//         emit DebugMsg("transferFrom success");

//         uint256 contractBalance = ICustomCoin(tokenAddress).balanceOf(address(this));
//         require(contractBalance >= amount, "Contract balance too low after transferFrom");

       
       
//         // ICustomCoin(tokenAddress).transfer(owner, totalFee);
//         ICustomCoin(tokenAddress).burn(address(this), amount);
//         emit DebugMsg("Token burned");

//         Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
//             receiver: abi.encode(sourceBridge),
//             data: abi.encode(sender, tokenId, amount),
//             tokenAmounts: new Client.EVMTokenAmount[](0),
//             extraArgs: Client._argsToBytes(Client.GenericExtraArgsV2({gasLimit: 300_000, allowOutOfOrderExecution: true})),
//             feeToken: address(0)
//         });

//         IRouterClient routerContract = IRouterClient(router);
//         uint256 fee = routerContract.getFee(sourceChainSelector, message);
//         emit DebugFee(fee);
//         require(msgValue >= fee, "Insufficient fee sent");

//         bytes32 messageId = routerContract.ccipSend{value: msgValue}(sourceChainSelector, message);
//         emit BurnTokenCCIP(messageId, sender, tokenId, amount);

//         if (msgValue > fee) {
//             uint256 refund = msgValue - fee;
//             (bool sent, ) = payable(sender).call{value: refund}("");
//             if (sent) {
//                 emit DebugMsg("Refund succeeded");
//             } else {
//                 emit DebugMsg("Refund failed");
//             }
//         }

//         emit DebugMsg("End burnTokenCCIP");
//         return messageId;
//     }

//     function getFeeCCIP(
//         uint256 amount,
//         bytes32 tokenId,
//         address sender,
//         address sourceBridge,
//         uint64 sourceChainSelector,
//         address router
//     ) internal view returns (uint256) {
//         Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
//             receiver: abi.encode(sourceBridge),
//             data: abi.encode(sender, tokenId, amount),
//             tokenAmounts: new Client.EVMTokenAmount[](0),
//             extraArgs: Client._argsToBytes(Client.GenericExtraArgsV2({gasLimit: 300_000, allowOutOfOrderExecution: true})),
//             feeToken: address(0)
//         });
//         return IRouterClient(router).getFee(sourceChainSelector, message);
//     }
// }