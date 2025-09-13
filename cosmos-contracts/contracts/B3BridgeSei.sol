// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISeiOracle} from "./interfaces/ISeiOracle.sol";
import {ICustomCoin} from "./interfaces/ICustomCoin.sol";

contract B3BridgeSei is CCIPReceiver, Ownable, ReentrancyGuard {
    ISeiOracle internal oracle =
        ISeiOracle(0x0000000000000000000000000000000000001008);
    using ECDSA for bytes32;
    mapping(bytes32 => address) public tokenMapping;
    mapping(address => bytes32) public tokenAddressToId;
    mapping(bytes32 => bool) public usedTxKeys;
    mapping(bytes32 => bytes[]) public signaturesOfValidator;
    struct TokenInfo {
        bytes32 id;
        uint256 feeRate;
        uint256 nativeFeePerUnit;
        address tokenAddress;
        uint8 decimals;
    }
    mapping(address => TokenInfo) public tokenMap;
    // address[] public verifiedValidators;
    address[] public validators;
    uint256 public threshold;
    mapping(bytes32 => mapping(address => bool)) public signatures;
    mapping(bytes32 => uint256) public signatureCount;
    mapping(bytes32 => Payload) public payloadData;
    mapping(bytes32 => bool) public processedMessages;
    struct Payload {
        bytes32 txKey; // key transaction
        address from; // ví nguồn
        address to; // ví nhận
        address tokenAddr; // token address
        uint256 amount; // số lượng token
        uint256 fee; // phí
        uint256 chainId;
    }
    uint64 public minFee;
    uint64 public maxFee;

    event DebugTokenAddress(bytes32 tokenId, address tokenAddress);
    event MintTokenCCIP(address receiver, bytes32 tokenId, uint256 amount, bytes32 messageId);
    event BurnTokenVL(
        address indexed sender,
        address destWalletAddress,
        uint256 amount,
        uint256 fee,
        address indexed sourceBridge,
        address wTokenAddress,
        uint256 chainId
    );

    event MintedTokenVL(address recipientAddr, address token, uint256 amount, bytes32 txKey);
    event FeeCCIP(uint256 fee);
    event FeeBridge(uint256 fee);
    event BurnTokenCCIP(
        bytes32 indexed messageId,
        address indexed user,
        bytes32 tokenId,
        uint256 amount
    );

    event MinFeeUpdated(uint64 newMinFee);
    event MaxFeeUpdated(uint64 newMaxFee);

    event ThresholdUpdated(uint256 newThreshold);
    event ValidatorAdded(address validator);
    event ValidatorRemoved(address validator);
    event SignatureSubmitted(
        bytes32 indexed messageHash,
        address indexed signer
    );
    // event Executed(bytes32 indexed messageHash);
    event FeeDistributed(
        address indexed validator,
        address token,
        uint256 amount
    );
    event FeeCollected(
        address indexed sender,
        address token,
        uint256 totalFee,
        uint256 ownerFee,
        uint256 validatorFee
    );
    event InterchainCall(
        uint256 chainId,
        string methodName,
        bytes32 indexed txKey,
        bytes[] signatures,
        uint256 fee
    );

    event FeeForValidator(
        address indexed validator,
        uint256 amount,
        bytes32 indexed txKey
    );

    constructor(
        address router,
        address[] memory _validators,
        uint256 _threshold
    ) CCIPReceiver(router) Ownable(msg.sender) {
        require(_validators.length > 0, "Validator list cannot be empty");
        require(
            _threshold > 0 && _threshold <= _validators.length,
            "Invalid threshold"
        );

        validators = _validators;
        threshold = _threshold;
    }

    function setMinFee(uint64 newMinFee) external onlyOwner {
        require(newMinFee > 0, "Minimum fee must be > 0");
        if (maxFee > 0) {
            require(newMinFee <= maxFee, "Minimum fee exceeds max fee");
        }

        minFee = newMinFee;
        emit MinFeeUpdated(newMinFee);
    }

    function setMaxFee(uint64 newMaxFee) external onlyOwner {
        require(newMaxFee > 0, "Maximum fee must be > 0");

        if (minFee > 0) {
            require(newMaxFee >= minFee, "Maximum fee less than min fee");
        }

        maxFee = newMaxFee;
        emit MaxFeeUpdated(newMaxFee);
    }

    function getMinFee() external view returns (uint64) {
        return minFee;
    }

    function getMaxFee() external view returns (uint64) {
        return maxFee;
    }

    function setFeeRate(
        address tokenAddress,
        uint256 newRate,
        uint256 newNativeFeePerUnit,
        uint8 newDecimals
    ) external onlyOwner {
        bytes32 tokenId = tokenAddressToId[tokenAddress];
        tokenMap[tokenAddress].id = tokenId;
        tokenMap[tokenAddress].feeRate = newRate;
        tokenMap[tokenAddress].nativeFeePerUnit = newNativeFeePerUnit;
        tokenMap[tokenAddress].decimals = newDecimals;
    }

    function getSeiUsdPrice()
        public
        view
        returns (uint256 price, int64 timestamp)
    {
        try oracle.getExchangeRates() returns (
            ISeiOracle.DenomOracleExchangeRatePair[] memory rates
        ) {
            if (rates.length == 0) {
                revert("Oracle returned empty rates");
            }
            for (uint256 i = 0; i < rates.length; i++) {
                if (
                    keccak256(abi.encodePacked(rates[i].denom)) ==
                    keccak256(abi.encodePacked("usei"))
                ) {
                    // Check if price data is recent
                    require(
                        uint64(
                            rates[i].oracleExchangeRateVal.lastUpdateTimestamp
                        ) >= block.timestamp - 1 hours,
                        "Price data is too old"
                    );

                    // Convert string exchangeRate to uint256
                    string memory exchangeRateStr = rates[i]
                        .oracleExchangeRateVal
                        .exchangeRate;
                    uint256 priceValue = stringToUint256(exchangeRateStr); // Custom function to convert string to uint256

                    return (
                        priceValue,
                        rates[i].oracleExchangeRateVal.lastUpdateTimestamp
                    );
                }
            }
            revert("SEI/USD price not found");
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Oracle error: ", reason)));
        } catch {
            revert("Oracle call failed");
        }
    }

    function stringToUint256(string memory s) internal pure returns (uint256) {
        // Parse the string, assuming format like "123.456789000000000000" (18 decimals)
        bytes memory b = bytes(s);
        uint256 result = 0;
        uint256 decimals = 18; // Adjust based on oracle's decimal precision
        bool decimalFound = false;
        uint256 decimalCount = 0;

        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ".") {
                decimalFound = true;
                continue;
            }
            if (!decimalFound) {
                result = result * 10 + uint256(uint8(b[i]) - 48); // Convert char to digit
            } else {
                if (decimalCount < decimals) {
                    result = result * 10 + uint256(uint8(b[i]) - 48);
                    decimalCount++;
                }
            }
        }

        // Adjust for remaining decimal places
        while (decimalCount < decimals) {
            result = result * 10;
            decimalCount++;
        }

        return result;
    }

    // function getFeeBridge(
    //     address tokenAddress,
    //     uint256 amount
    // ) external view returns (uint256) {
    //     TokenInfo memory tokenInfo = tokenMap[tokenAddress];

    //     uint256 fixedFee = tokenInfo.nativeFeePerUnit;

    //     (uint256 price, ) = getSeiUsdPrice();

    //     require(price > 0, "Invalid price");
    //     uint256 seiUsdPrice = uint256(price);

    //     uint256 dynamicFee = (amount * tokenInfo.feeRate * 1e30) /
    //         (seiUsdPrice * 10000);

    //     uint256 totalFee = fixedFee + dynamicFee;

    //     // if (minFee > 0 && totalFee < minFee) {
    //     //     totalFee = minFee;
    //     // } else if (maxFee > 0 && totalFee > maxFee) {
    //     //     totalFee = maxFee;
    //     // }

    //     return totalFee; // in wei
    // }

    function getFeeBridge(
        address tokenAddress,
        uint256 amount
    ) external view returns (uint256) {
        TokenInfo memory tokenInfo = tokenMap[tokenAddress];

        // // Kiểm tra
        // require(tokenInfo.decimals > 0, "Invalid decimals");
        // require(tokenInfo.feeRate > 0, "Invalid fee rate");
        // require(amount > 0, "Invalid amount");

        // Phí cố định
        uint256 fixedFee = tokenInfo.nativeFeePerUnit;

        // Lấy giá SEI/USD (đơn vị: USD * 10^18)
        (uint256 price, ) = getSeiUsdPrice();
        require(price > 0, "Price must be greater than 0");
        uint256 seiUsdPrice = price; // giá SEI tính theo USD * 10^18

        // Phí động:
        // Normalize amount về đơn vị gốc
        uint256 normalizedAmount = amount / (10 ** tokenInfo.decimals); // e.g., 1 USDC = 10^6 => normalized 1
        // DynamicFee = normalizedAmount * feeRate / 10000 (basis point) => vẫn ở đơn vị token gốc
        uint256 dynamicFee = ((normalizedAmount * tokenInfo.feeRate*(10 ** tokenInfo.decimals))) / 10000;
        // dynamicFee = dynamicFee * (10 ** tokenInfo.decimals); // chuyển lại về decimal của token / 200.000 wei

        // Tổng phí = cố định + động
        uint256 totalFee = (fixedFee + dynamicFee);

        // Tổng phí (token) -> SEI
        // Giả sử 1 SEI = $0.3 => price = 0.3 * 10^18
        // totalFee * 10^18 / seiUsdPrice => ra SEI có đơn vị 10^18 (wei)
        //  uint256 feex = totalFee * (10 ** 18);
        uint256 totalFeeInSei = (totalFee * (10 ** 18)) / seiUsdPrice;



        // // Debug log
        // emit DebugParams(amount, tokenInfo.decimals, tokenInfo.feeRate);
        // emit Debug(totalFee, dynamicFee, normalizedAmount, fixedFee, feex);
        // emit PriceSei(seiUsdPrice);
        // emit FeeBridge(totalFeeInSei);

        return totalFeeInSei; // trả về giá trị dạng wei, tức là 18 số thập phân
    }

    // Hàm thêm hoặc cập nhật mapping token
    function setTokenMapping(
        bytes32 tokenId,
        address tokenAddress
    ) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        tokenMapping[tokenId] = tokenAddress;
        tokenAddressToId[tokenAddress] = tokenId;
    }

    function getFeeCCIP(
        IERC20 token,
        uint256 amount,
        bytes32 tokenId,
        address sourceBridge,
        uint64 sourceChainSelector
    ) external view returns (uint256) {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(sourceBridge),
            data: abi.encode(msg.sender, tokenId, amount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });
        uint256 bridgeFee = this.getFeeBridge(address(token), amount);

        uint256 ccipFee = IRouterClient(getRouter()).getFee(
            sourceChainSelector,
            message
        );

        return ccipFee + bridgeFee;
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        // Decode dữ liệu từ message: (receiver, tokenId, amount)
        (address receiver, bytes32 tokenId, uint256 amount) = abi.decode(
            message.data,
            (address, bytes32, uint256)
        );

        address tokenAddress = tokenMapping[tokenId];

        ICustomCoin(tokenAddress).mint(receiver, amount);

        emit MintTokenCCIP(receiver, tokenId, amount, message.messageId);
    }

    function burnTokenCCIP(
        bytes32 tokenId,
        uint256 amount,
        address sourceBridge,
        uint64 sourceChainSelector
    ) external payable returns (bytes32 messageId) {
        require(amount > 0, "Amount must be greater than 0");

        address tokenAddress = tokenMapping[tokenId];
        emit DebugTokenAddress(tokenId, tokenAddress);
        require(tokenAddress != address(0), "Unsupported token");

        uint256 allowance = ICustomCoin(tokenAddress).allowance(
            msg.sender,
            address(this)
        );
        require(allowance >= amount, "Insufficient allowance");

        uint256 userBalance = ICustomCoin(tokenAddress).balanceOf(msg.sender);
        require(userBalance >= amount, "Insufficient user balance");

        bool success = ICustomCoin(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "transferFrom failed");

        uint256 contractBalance = ICustomCoin(tokenAddress).balanceOf(
            address(this)
        );
        require(
            contractBalance >= amount,
            "Contract balance too low after transferFrom"
        );

        ICustomCoin(tokenAddress).burn(address(this), amount);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(sourceBridge),
            data: abi.encode(msg.sender, tokenId, amount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        IRouterClient router = IRouterClient(getRouter());
        uint256 ccipFee = router.getFee(sourceChainSelector, message);
        uint256 bridgeFee = this.getFeeBridge(tokenAddress, amount);
        uint256 totalFee = ccipFee + bridgeFee;
        emit FeeCCIP(ccipFee);
        emit FeeBridge(bridgeFee);

        require(msg.value >= totalFee, "Insufficient fee sent");

        messageId = router.ccipSend{value: ccipFee}(
            sourceChainSelector,
            message
        );

        emit BurnTokenCCIP(messageId, msg.sender, tokenId, amount);

        // Refund leftover fee nếu có
        if (msg.value > totalFee) {
            uint256 refund = msg.value - totalFee;
            (bool sentUser, ) = payable(msg.sender).call{value: refund}("");

            (bool sentSystem, ) = payable(address(this)).call{value: bridgeFee}(
                ""
            );
            require(sentUser, "Refund failed");
            require(sentSystem, "Refund failed");
        }
        return messageId;
    }
    function getEthUsdPrice()
        public
        view
        returns (uint256 ethPrice, int64 timestamp)
    {
        try oracle.getExchangeRates() returns (
            ISeiOracle.DenomOracleExchangeRatePair[] memory rates
        ) {
            if (rates.length == 0) {
                revert("Oracle returned empty rates");
            }
            for (uint256 i = 0; i < rates.length; i++) {
                if (
                    keccak256(abi.encodePacked(rates[i].denom)) ==
                    keccak256(abi.encodePacked("ueth")) //usei
                ) {
                    // Check if price data is recent
                    require(
                        uint64(
                            rates[i].oracleExchangeRateVal.lastUpdateTimestamp
                        ) >= block.timestamp - 1 hours,
                        "Price data is too old"
                    );

                    // Convert string exchangeRate to uint256
                    string memory exchangeRateStr = rates[i]
                        .oracleExchangeRateVal
                        .exchangeRate;
                    uint256 priceValue = stringToUint256(exchangeRateStr); // Custom function to convert string to uint256

                    return (
                        priceValue,
                        rates[i].oracleExchangeRateVal.lastUpdateTimestamp
                    );
                }
            }
            revert("SEI/USD price not found");
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Oracle error: ", reason)));
        } catch {
            revert("Oracle call failed");
        }
    }
    function getFeeEthBridge(
        address tokenAddress,
        uint256 amount
    ) external view returns (uint256) {
        TokenInfo memory tokenInfo = tokenMap[tokenAddress];
        require(tokenInfo.feeRate > 0, "Invalid fee rate");

        // Phí cố định và động (đơn vị: wei, ETH)
        uint256 fixedFee = tokenInfo.nativeFeePerUnit; // ví dụ: 1000000000000000 (0.001 ETH)
        uint256 dynamicFee = (amount * tokenInfo.feeRate) / 10000; // 2% => 200 / 10000

        uint256 totalFeeETH = fixedFee + dynamicFee;

        // Lấy giá ETH/USD và SEI/USD (đều * 1e18)
        (uint256 ethUsdPrice, ) = getEthUsdPrice();
        require(ethUsdPrice > 0, "Invalid ETH/USD price");

        (uint256 seiUsdPrice, ) = getSeiUsdPrice();
        require(seiUsdPrice > 0, "Invalid SEI/USD price");

        // Đổi phí ETH → USD: (ETH * USD) / 1e18
        uint256 totalFeeUSD = (totalFeeETH * ethUsdPrice) / 1e18;

        // Đổi USD → SEI: (USD * 1e18) / seiUsdPrice
        uint256 totalFeeSEI = (totalFeeUSD * 1e18) / seiUsdPrice;

        return totalFeeSEI; // đơn vị: wei (SEI)
    }
    function burnTokenVL(
        uint256 amount,
        address wTokenAddress,
        address destAddress,
        address destWalletAddress
    ) external payable nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(
            msg.value > this.getFeeEthBridge(wTokenAddress, amount),
            "The amount of native token sent must be greater than the calculated bridge fee."
        );

        uint256 bridgeFee = this.getFeeEthBridge(wTokenAddress, amount);
        

        // Kiểm tra allowance và balance
        uint256 allowance = ICustomCoin(wTokenAddress).allowance(
            msg.sender,
            address(this)
        );
        require(allowance >= amount, "Insufficient allowance");

        uint256 userBalance = ICustomCoin(wTokenAddress).balanceOf(msg.sender);
        require(userBalance >= amount, "Insufficient user balance");

        // Chuyển token từ người dùng sang contract
        bool success = ICustomCoin(wTokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "transferFrom failed");

        // Kiểm tra balance của contract sau transfer
        uint256 contractBalance = ICustomCoin(wTokenAddress).balanceOf(
            address(this)
        );
        require(
            contractBalance >= amount,
            "Contract balance too low after transferFrom"
        );

        // Burn token
        ICustomCoin(wTokenAddress).burn(address(this), amount);

        // Phát sự kiện BurnTokenVL
        emit BurnTokenVL(
            msg.sender,
            destWalletAddress,
            amount,// CHỖ NÀY PHẢI LÀ MSG.VALUE -- CẦN /2 CHO CHỦ SC - 50% thì gửi cho Validators
            bridgeFee,
            destAddress,
            wTokenAddress,
            block.chainid
        );

        // Hoàn phí dư nếu có
        if (msg.value > bridgeFee) {
            uint256 refund = msg.value - bridgeFee;
            (bool sent, ) = payable(msg.sender).call{value: refund}("");
            require(sent, "Refund failed");
        }
    }

    function interchainCall(
        bytes32 txKey,
        bytes[] calldata signs,
        uint256 fee
    ) external {
        require(!usedTxKeys[txKey], "Already distributed");
        require(signs.length > 0, "No signatures");
        require(fee > 0, "No fee to distribute");
        require(address(this).balance >= fee, "Insufficient fee balance");

        uint256 totalSigners = 0;
        uint256 feePerValidator = fee / signs.length;

        address[] memory paidValidators = new address[](signs.length); // để tránh duplicate

        for (uint i = 0; i < signs.length; i++) {
            address signer = recoverSigner(txKey, signs[i]);

            // Bỏ qua nếu không phải validator
            if (!_isValidator(signer)) continue;

            // Kiểm tra signer có bị trùng trong vòng này không
            bool alreadyPaid = false;
            for (uint j = 0; j < totalSigners; j++) {
                if (paidValidators[j] == signer) {
                    alreadyPaid = true;
                    break;
                }
            }
            if (alreadyPaid) continue;

            // Trả tiền từ balance contract (đã giữ sẵn)
            paidValidators[totalSigners] = signer;
            totalSigners++;
            (bool success, ) = payable(signer).call{value: feePerValidator}("");
            require(success, "Fee transfer failed");
            emit FeeForValidator(signer, feePerValidator, txKey);
        }

        require(totalSigners > 0, "No valid validators signed");
        usedTxKeys[txKey] = true;
    }

    function setThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold > 0, "Threshold must be > 0");
        require(
            newThreshold <= validators.length,
            "Threshold exceeds validator count"
        );
        require(
            newThreshold >= (validators.length * 2 + 2) / 3,
            "Threshold too low"
        );

        threshold = newThreshold;
        emit ThresholdUpdated(newThreshold);
    }

    function _updateThreshold() internal {
        if (validators.length == 0) {
            threshold = 0;
        } else {
            threshold = (validators.length * 2 + 2) / 3;
        }
        emit ThresholdUpdated(threshold);
    }

    function _isValidator(address addr) internal view returns (bool) {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == addr) return true;
        }
        return false;
    }

    // Khi thêm validator thì update luôn threshold
    function addValidator(address validator) external onlyOwner {
        require(validator != address(0), "Invalid validator address");
        require(!_isValidator(validator), "Validator already exists");
        require(validators.length < type(uint256).max, "Validator list full");

        validators.push(validator);

        _updateThreshold();

        emit ValidatorAdded(validator);
    }

    function removeValidator(address validator) external onlyOwner {
        require(_isValidator(validator), "Validator not found");

        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == validator) {
                validators[i] = validators[validators.length - 1];
                validators.pop();

                _updateThreshold();
                emit ValidatorRemoved(validator);
                break;
            }
        }
    }

    function getValidators() external view returns (address[] memory) {
        return validators;
    }

    function mintTokenVL(
        bytes memory signature,
        Payload calldata payload
    ) public {
        require(_isValidator(msg.sender), "Not validator");
        require(!signatures[payload.txKey][msg.sender], "Already signed");
        require(!processedMessages[payload.txKey], "Transaction already processed");

        // Xác thực chữ ký theo chuẩn eth-signed-message
        require(
            _verifySignature(payload.txKey, signature, msg.sender),
            "Invalid signature"
        );

        if (signatureCount[payload.txKey] == 0) {
            // Chữ ký đầu tiên, lưu dữ liệu message
            require(payload.to != address(0), "Invalid recipient address");
            require(payload.amount > 0, "Amount must be > 0");

            payloadData[payload.txKey] = payload;
        } else {
            // Đã có chữ ký trước đó → kiểm tra dữ liệu khớp
            Payload memory stored = payloadData[payload.txKey];
            require(
                stored.txKey == payload.txKey &&
                    stored.from == payload.from &&
                    stored.to == payload.to &&
                    stored.tokenAddr == payload.tokenAddr &&
                    stored.amount == payload.amount &&
                    stored.fee == payload.fee &&
                    stored.chainId == payload.chainId,
                "Data mismatch"
            );
        }

        if (!signatures[payload.txKey][msg.sender]) {
            signatures[payload.txKey][msg.sender] = true;
            signatureCount[payload.txKey] += 1;

            // verifiedValidators.push(msg.sender);
            signaturesOfValidator[payload.txKey].push(signature);
        }

        emit SignatureSubmitted(payload.txKey, msg.sender);

        // Nếu đủ threshold → thực thi hành động
        if (signatureCount[payload.txKey] >= threshold) {
            _execute(payload.txKey);
        }
    }

    function _execute(bytes32 txKey) internal {
        require(!processedMessages[txKey], "Message already processed");
        Payload memory data = payloadData[txKey];
        require(data.amount > 0, "Invalid amount");
        require(data.to != address(0), "Invalid recipient address");
        require(data.tokenAddr != address(0), "Invalid token address");

        processedMessages[txKey] = true;

        // Mint token (wrapped ERC20) cho người nhận
        ICustomCoin(data.tokenAddr).mint(data.to, data.amount);

        emit MintedTokenVL(data.to, data.tokenAddr, data.amount, txKey);
        emit InterchainCall(
            payloadData[txKey].chainId,
            "distributeFee",
            txKey,
            signaturesOfValidator[txKey],
            data.fee
        );
        // Cleanup
        delete signaturesOfValidator[txKey];
        delete payloadData[txKey];
        delete signatureCount[txKey];
        for (uint256 i = 0; i < validators.length; i++) {
            delete signatures[txKey][validators[i]];
        }
    }

    function distributeFee(
        bytes32 txKey,
        bytes[] calldata signs,
        uint256 fee
    ) external {
        require(!usedTxKeys[txKey], "Already distributed");
        require(signs.length > 0, "No signatures");
        require(fee > 0, "No fee to distribute");
        require(address(this).balance >= fee, "Insufficient fee balance");

        uint256 totalSigners = 0;
        uint256 feePerValidator = fee / signs.length;

        address[] memory paidValidators = new address[](signs.length); // để tránh duplicate

        for (uint i = 0; i < signs.length; i++) {
            address signer = recoverSigner(txKey, signs[i]);

            // Bỏ qua nếu không phải validator
            if (!_isValidator(signer)) continue;

            // Kiểm tra signer có bị trùng trong vòng này không
            bool alreadyPaid = false;
            for (uint j = 0; j < totalSigners; j++) {
                if (paidValidators[j] == signer) {
                    alreadyPaid = true;
                    break;
                }
            }
            if (alreadyPaid) continue;

            // Trả tiền từ balance contract (đã giữ sẵn)
            paidValidators[totalSigners] = signer;
            totalSigners++;
            (bool success, ) = payable(signer).call{value: feePerValidator}("");
            require(success, "Fee transfer failed");
            emit FeeForValidator(signer, feePerValidator, txKey);
        }

        require(totalSigners > 0, "No valid validators signed");
        usedTxKeys[txKey] = true;
    }

    function test() external {
        require(_isValidator(msg.sender), "Not validator");

        bytes[] memory sigs = new bytes[](1);
        sigs[
            0
        ] = hex"1c0e38df861efe0997c4714bf06fb67bf5da30ffb53251e4607a2606815adc5e312ed3bb05fda2d47af4850404c368975c69778a5d0175dfde376afc6a97eb4e1c";

        emit InterchainCall(9999, "distributeFee", "111", sigs, 200);
    }

    function recoverSigner(
        bytes32 message,
        bytes memory signature
    ) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        // v must be 27 or 28
        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "Invalid v value");

        // Add Ethereum signed message prefix
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );

        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    function _verifySignature(
        bytes32 txKey,
        bytes memory signature,
        address signer
    ) internal pure returns (bool) {
        return recoverSigner(txKey, signature) == signer;
    }

    function _splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function transferTokenOwnership(
        address newOwner,
        bytes32 tokenId
    ) public virtual onlyOwner {
        require(newOwner != address(0), "New owner is zero address");

        address tokenAddress = tokenMapping[tokenId];
        require(tokenAddress != address(0), "Unsupported token");

        require(
            ICustomCoin(tokenAddress).owner() == address(this),
            "Bridge is not token owner"
        );

        ICustomCoin(tokenAddress).transferOwnership(newOwner);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }

    // Hàm để nhận native token (nếu cần)
    receive() external payable {}
}
