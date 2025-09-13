// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/interfaces/ICommonOFT.sol";
import "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract B3BridgeETH is CCIPReceiver, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    address[] public validators;
    uint256 public threshold;

    // Bridge fee variables
    bytes32 public constant TOKEN_ID_USDC = keccak256(abi.encodePacked("USDC"));
    bytes32 public constant ETH_TOKEN_ID = keccak256("ETH");

    uint64 public minFee;
    uint64 public maxFee;

    // Danh sách validators đã xác thực giao dịch
    // address[] public verifiedValidators;
    mapping(bytes32 => bytes[]) public signaturesOfValidator;
    mapping(bytes32 => bool) public usedTxKeys;
    struct TokenInfo {
        address tokenAddress;
        bytes32 id;
        uint256 feeRate; // (1% = 100)
        uint8 decimals; // USDC = 6 ETH = 18
        uint256 fixedFee; // 1 USDC = 1.000.000 || ETH = 1e13 wei = 0.00001 ETH
    }
    // token ID => token metadata
    mapping(bytes32 => TokenInfo) public tokenMap;
    AggregatorV3Interface internal priceFeed;
    
    // Token price feeds mapping for individual tokens
    mapping(bytes32 => AggregatorV3Interface) public tokenPriceFeeds;
    
    // Fallback prices for tokens without oracle (USD with 8 decimals)
    mapping(bytes32 => uint256) public fallbackPrices;

    mapping(address => bytes32) public tokenAddressToId;
    mapping(bytes32 => address) public tokenMapping;
    mapping(bytes32 => mapping(address => bool)) public signatures;
    mapping(bytes32 => uint256) public signatureCount;
    mapping(bytes32 => Payload) public payloadData;
    mapping(bytes32 => bool) public processedMessages;
    mapping(address => uint256) public lockedTokenVL;

    event LockedTokenVL(
        address sender,
        address receiverAddress,
        address tokenAddr,
        uint256 amount,
        uint256 fee,
        address destAddress,
        uint256 chainId
    );
    event MessageReceived(
        address indexed user,
        bytes32 indexed tokenId,
        address tokenAddr,
        uint256 amount,
        bytes32 messageId
    );
    event RescueTokenCCIP(address token, uint256 amount);
    event RescueTokenVL(uint256 amount);
    event UnlockedTokenVL(address indexed recipientAddr, uint256 amount, bytes32 indexed txKey);
    event UnlockedTokenERC20VL(
        address indexed recipientAddr,
        address tokenAddr,
        uint256 amount
    );

    event SignatureSubmitted(bytes32 indexed txKey, address indexed signer);
    event Executed(bytes32 indexed txKey);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event ThresholdUpdated(uint256 newThreshold);
    
    // Events for price management
    event TokenPriceFeedSet(bytes32 indexed tokenId, address priceFeed);
    event FallbackPriceSet(bytes32 indexed tokenId, uint256 price);
    event DebugAllowance(uint256 allowance);
    event DebugBalance(uint256 balance);
    event DebugTokenMapping(bytes32 tokenId, address tokenAddr);
    event DebugMsg(string message);
    event DebugFee(uint256 fee);
    event MessageSent(bytes32 indexed messageId);
    event TokenCCIPLocked(
        address indexed sender,
        address indexed token,
        uint256 amount
    );
    event DebugUnlockTokenVL(
        address user,
        uint256 amount,
        uint256 balanceBefore,
        uint256 balanceAfter
    );
    event UnlockTokenCCIP(
        address user,
        address token,
        uint256 amount,
        uint256 balanceBefore,
        uint256 balanceAfter,
        bytes32 indexed messageId
    );

    event FeeForValidator(
        address indexed validator,
        uint256 amount,
        bytes32 indexed txKey
    );

    error AmountZero();
    error InsufficientFeeSent(uint256 sent, uint256 required);
    error InvalidDestChainSelector();
    error DestAddressZero();
    error DesWalletAddressZero();
    error AmountToBridgeZero();
    event LockedTokenCCIP(
        address indexed sender,
        address indexed token,
        uint256 amount,
        uint64 destChainSelector,
        address indexed destAddress,
        address desWalletAddress
    );
    event CompareFee(uint256 sent, uint256 fee);
    error AlreadyProcessed();
    error InvalidAmount();
    error UnsupportedToken();
    error InsufficientBalance();

    // Bridge fee event
    event MinFeeUpdated(uint64 newMinFee);
    event MaxFeeUpdated(uint64 newMaxFee);
    struct Payload {
        bytes32 txKey; // key transaction
        address from; // ví nguồn
        address to; // ví nhận
        address tokenAddr; // token address
        uint256 amount; // số lượng token
        uint256 fee; // phí
        uint256 chainId;
    }
    event InterchainCall(
        uint256 chainId,
        string methodName,
        bytes32 indexed txKey,
        bytes[] signatures,
        uint256 fee
    );

    constructor(
        address _ccipRouter,
        address[] memory _validators,
        uint256 _threshold,
        address _chainlinkEthUsdFeed
    ) CCIPReceiver(_ccipRouter) Ownable() {
        require(_validators.length > 0, "Validator list cannot be empty");
        require(
            _threshold > 0 && _threshold <= _validators.length,
            "Invalid threshold"
        );

        validators = _validators;
        threshold = _threshold;

        // Setup ETH price feed in unified system
        priceFeed = AggregatorV3Interface(_chainlinkEthUsdFeed);
        tokenPriceFeeds[ETH_TOKEN_ID] = AggregatorV3Interface(_chainlinkEthUsdFeed);
        
        // Setup ETH token mapping
        tokenAddressToId[address(0)] = ETH_TOKEN_ID;
        tokenMapping[ETH_TOKEN_ID] = address(0);
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

    // Khi thêm validator thì update luôn threshold
    function addValidator(address validator) external onlyOwner {
        require(validator != address(0), "Invalid validator address");
        require(!_isValidator(validator), "Validator already exists");
        require(validators.length < type(uint256).max, "Validator list full");

        uint256 expectedValidatorCount = validators.length + 1;
        require(minFee >= expectedValidatorCount, "minFee too small for validator count");

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

        // If minFee is already set, validate upper bound
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

    function getValidators() external view returns (address[] memory) {
        return validators;
    }

    function setFeeRate(
        address tokenAddress,
        uint256 newRate,
        uint256 newFixedFee,
        uint8 newDecimals
    ) external onlyOwner {
        bytes32 tokenId = tokenAddressToId[tokenAddress];
        require(tokenId != bytes32(0), "Token not registered");

        tokenMap[tokenId].feeRate = newRate;
        tokenMap[tokenId].fixedFee = newFixedFee;
        tokenMap[tokenId].decimals = newDecimals;
    }

    /**
     * @dev DEPRECATED: Use getTokenPrice(ETH_TOKEN_ID) instead
     * @dev Get ETH/USD price from legacy price feed
     * @return price ETH price in USD (8 decimals)
     */
    function getLatestPrice() public view returns (int256) {
        // Delegate to unified system
        return getTokenPrice(ETH_TOKEN_ID);
    }
    
    /**
     * @dev Get token price in USD with 8 decimals
     * @param tokenId The token ID to get price for
     * @return price Token price in USD (8 decimals)
     */
    function getTokenPrice(bytes32 tokenId) public view returns (int256 price) {
        // Check if token has dedicated price feed
        if (address(tokenPriceFeeds[tokenId]) != address(0)) {
            (
                ,
                int256 feedPrice,
                ,
                ,
            ) = tokenPriceFeeds[tokenId].latestRoundData();
            require(feedPrice > 0, "Invalid token price from feed");
            return feedPrice;
        }
        
        // Use fallback price if available
        uint256 fallbackPrice = fallbackPrices[tokenId];
        require(fallbackPrice > 0, "No price available for token");
        return int256(fallbackPrice);
    }

    function getChainId() public view returns (uint256) {
        return block.chainid;
    }

    /**
     * @dev Calculate bridge fee for any token using unified pricing system
     * @param tokenAddress Token contract address (address(0) for ETH)
     * @param amount Amount to bridge in token's decimals
     * @return totalFee Fee amount in ETH (wei)
     */
    function getFeeBridge(
        address tokenAddress,
        uint256 amount
    ) external view returns (uint256) {
        bytes32 tokenId = tokenAddressToId[tokenAddress];
        require(tokenId != bytes32(0), "Unsupported token");

        TokenInfo memory tokenInfo = tokenMap[tokenId];
        
        uint256 dynamicFee;

        if (tokenAddress == address(0)) {
            // ETH case: fee calculated directly in ETH, no conversion needed
            dynamicFee = (amount * tokenInfo.feeRate) / 10000;
        } else {
            // ERC20 case: convert token fee to ETH via USD
            
            // Get both token and ETH prices in USD using unified system
            int256 tokenPrice = getTokenPrice(tokenId);
            int256 ethPrice = getTokenPrice(ETH_TOKEN_ID);
            
            require(tokenPrice > 0, "Invalid token price");
            require(ethPrice > 0, "Invalid ETH price");
            
            uint256 tokenUsdPrice = uint256(tokenPrice);
            uint256 ethUsdPrice = uint256(ethPrice);
            
            // Calculate fee amount in token units
            uint256 tokenFeeAmount = (amount * tokenInfo.feeRate) / 10000;
            
            // Convert token fee to USD value
            uint256 feeValueUsd = (tokenFeeAmount * tokenUsdPrice) / (10 ** tokenInfo.decimals);
            
            // Convert USD value to ETH
            dynamicFee = (feeValueUsd * 1e18) / ethUsdPrice;
        }

        uint256 totalFee = tokenInfo.fixedFee + dynamicFee;

        // Apply min/max fee bounds
        if (minFee > 0 && totalFee < minFee) {
            totalFee = minFee;
        } else if (maxFee > 0 && totalFee > maxFee) {
            totalFee = maxFee;
        }

        return totalFee; // in wei
    }

    function unLockTokenVL(
        bytes memory signature,
        Payload calldata payload
    ) public {
        require(_isValidator(msg.sender), "Not validator");
        require(!signatures[payload.txKey][msg.sender], "Already signed");

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
            // Đưa những validator vào danh sách để trả fee giao dịch
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

        address recipientAddr = data.to;

        processedMessages[txKey] = true;

        require(
            address(this).balance >= data.amount,
            "Insufficient native token balance"
        );
        (bool sent, ) = payable(recipientAddr).call{value: data.amount}("");
        require(sent, "Failed to send native token");

        emit UnlockedTokenVL(recipientAddr, data.amount, txKey);
        // Gửi thông tin cho BE lắng nghe
        emit InterchainCall
        (
            payloadData[txKey].chainId,
            "distributeFee",
            txKey,
            signaturesOfValidator[txKey],
            data.fee
        );
        // Dọn dẹp lại mảng ds các validator đã xác thực giao dịch
        // Dọn dẹp dữ liệu để tránh tái xử lý
        delete signaturesOfValidator[txKey];
        delete payloadData[txKey];
        delete signatureCount[txKey];
        for (uint256 i = 0; i < validators.length; i++) {
            delete signatures[txKey][validators[i]];
        }
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
        // bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
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

    function _isValidator(address addr) internal view returns (bool) {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == addr) return true;
        }
        return false;
    }

    // hàm phân phố fee cho validators
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

    function setTokenAddressToId(
        address tokenAddress,
        bytes32 tokenId
    ) external onlyOwner {
        tokenAddressToId[tokenAddress] = tokenId;
    }

    function setTokenMapping(
        bytes32 tokenId,
        address tokenAddress
    ) external onlyOwner {
        tokenMapping[tokenId] = tokenAddress;
        tokenAddressToId[tokenAddress] = tokenId;
    }

    // hàm lock token native
    function lockTokenVL(
        address destAddress,
        address receiverAddress
    ) external payable whenNotPaused nonReentrant {
        if (msg.value == 0) {
            revert AmountZero();
        }
        // TokenInfo memory tokenInfo = tokenMap[TOKEN_ID_ETH];
        require(msg.value > this.getFeeBridge(address(0), msg.value), "Amount sent is too small");
        // Tính phí bridge dựa trên token và amount
        uint256 bridgeFee = this.getFeeBridge(address(0), msg.value);
        // Tính số lượng thực tế sẽ bị khóa
        uint256 lockAmount = msg.value - bridgeFee; 

        // Ghi nhận số lượng bị lock cho người gửi
        lockedTokenVL[msg.sender] += lockAmount;

        emit LockedTokenVL(
            msg.sender,
            receiverAddress,
            address(0),
            lockAmount,
            bridgeFee,
            destAddress,
            block.chainid
        );
    }

    // hàm lock token ERC20
    function lockTokenCCIP(
        IERC20 token,
        uint64 destChainSelector,
        address destAddress,
        address desWalletAddress,
        uint256 amountToBridge
    ) external payable whenNotPaused nonReentrant returns (bytes32 messageId) {
        if (destChainSelector == 0) {
            revert InvalidDestChainSelector();
        }
        if (destAddress == address(0)) {
            revert DestAddressZero();
        }
        if (desWalletAddress == address(0)) {
            revert DesWalletAddressZero();
        }
        if (amountToBridge == 0) {
            revert AmountToBridgeZero();
        }
        require(amountToBridge > 0, "Amount must be > 0");

        // Look up tokenId
        bytes32 tokenId = tokenAddressToId[address(token)];
        require(tokenId != bytes32(0), "Unsupported token");
        emit DebugMsg("TokenId mapped");

        token.transferFrom(msg.sender, address(this), amountToBridge);

        emit TokenCCIPLocked(msg.sender, address(token), amountToBridge);
        emit DebugMsg("Token locked");

        // Build message
        Client.EVM2AnyMessage memory evmMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(destAddress),
            data: abi.encode(desWalletAddress, tokenId, amountToBridge),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 ccipFee = IRouterClient(getRouter()).getFee(
            destChainSelector,
            evmMessage
        );
        uint256 bridgeFee = this.getFeeBridge(address(token), amountToBridge);

        uint256 totalFee = ccipFee + bridgeFee;
        emit DebugFee(totalFee);

        if (msg.value < totalFee) {
            revert InsufficientFeeSent(msg.value, totalFee);
        }

        // Send message
        messageId = IRouterClient(getRouter()).ccipSend{value: ccipFee}(
            destChainSelector,
            evmMessage
        );
        emit MessageSent(messageId);
        emit CompareFee(msg.value, ccipFee);

        emit LockedTokenCCIP(
            msg.sender,
            address(token),
            amountToBridge,
            destChainSelector,
            destAddress,
            desWalletAddress
        );

        // Refund fee if needed
        if (msg.value > totalFee) {
            uint256 refund = msg.value - totalFee;
            (bool sentUser, ) = payable(msg.sender).call{value: refund}("");

            (bool sentSystem, ) = payable(address(this)).call{value: bridgeFee}(
                ""
            );
            require(sentUser, "Refund failed");
            require(sentSystem, "Refund failed");

            emit DebugMsg("Refund succeeded");
        }
    }

    // hàm lấy phí CCIP + Bridge
    function getFeeCCIP(
        IERC20 token,
        uint64 destChainSelector,
        address destAddress,
        address desWalletAddress,
        uint256 amountToBridge
    ) external view returns (uint256) {
        if (destChainSelector == 0) {
            revert InvalidDestChainSelector();
        }
        if (destAddress == address(0)) {
            revert DestAddressZero();
        }
        if (desWalletAddress == address(0)) {
            revert DesWalletAddressZero();
        }
        if (amountToBridge == 0) {
            revert AmountToBridgeZero();
        }
        require(amountToBridge > 0, "Amount must be > 0");

        // Look up tokenId
        bytes32 tokenId = tokenAddressToId[address(token)];
        require(tokenId != bytes32(0), "Unsupported token");

        // Build message
        Client.EVM2AnyMessage memory evmMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(destAddress),
            data: abi.encode(desWalletAddress, tokenId, amountToBridge),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 ccipFee = IRouterClient(getRouter()).getFee(
            destChainSelector,
            evmMessage
        );
        uint256 bridgeFee = this.getFeeBridge(address(token), amountToBridge);

        return ccipFee + bridgeFee;
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal virtual override whenNotPaused nonReentrant {
        bytes32 messageId = message.messageId;

        if (processedMessages[messageId]) revert AlreadyProcessed();
        processedMessages[messageId] = true;

        (address userAddress, bytes32 tokenId, uint256 amount) = abi.decode(
            message.data,
            (address, bytes32, uint256)
        );

        if (amount == 0) revert InvalidAmount();

        address tokenAddr = tokenMapping[tokenId];

        emit DebugTokenMapping(tokenId, tokenAddr);

        if (tokenAddr == address(0)) revert UnsupportedToken();

        uint256 balanceBefore = IERC20(tokenAddr).balanceOf(address(this));
        if (balanceBefore < amount) revert InsufficientBalance();

        IERC20(tokenAddr).safeTransfer(userAddress, amount);

        emit MessageReceived(
            userAddress,
            tokenId,
            tokenAddr,
            amount,
            messageId
        );
        emit UnlockTokenCCIP(
            userAddress,
            tokenAddr,
            amount,
            IERC20(tokenAddr).balanceOf(address(this)),
            IERC20(tokenAddr).balanceOf(userAddress),
            messageId
        );
    }

    // ==================== PRICE FEED MANAGEMENT ====================
    
    /**
     * @dev Set price feed for a specific token
     * @param tokenId Token ID
     * @param priceFeedAddress Chainlink price feed address
     */
    function setTokenPriceFeed(bytes32 tokenId, address priceFeedAddress) external onlyOwner {
        require(tokenId != bytes32(0), "Invalid token ID");
        require(priceFeedAddress != address(0), "Invalid price feed address");
        
        tokenPriceFeeds[tokenId] = AggregatorV3Interface(priceFeedAddress);
        emit TokenPriceFeedSet(tokenId, priceFeedAddress);
    }
    
    /**
     * @dev Set fallback price for tokens without oracle
     * @param tokenId Token ID
     * @param price Price in USD with 8 decimals (e.g., $1.00 = 100000000)
     */
    function setFallbackPrice(bytes32 tokenId, uint256 price) external onlyOwner {
        require(tokenId != bytes32(0), "Invalid token ID");
        require(price > 0, "Invalid price");
        
        fallbackPrices[tokenId] = price;
        emit FallbackPriceSet(tokenId, price);
    }
    
    /**
     * @dev Remove price feed for a token (will use fallback price if available)
     * @param tokenId Token ID
     */
    function removeTokenPriceFeed(bytes32 tokenId) external onlyOwner {
        require(tokenId != bytes32(0), "Invalid token ID");
        
        delete tokenPriceFeeds[tokenId];
        emit TokenPriceFeedSet(tokenId, address(0));
    }
    
    /**
     * @dev Remove fallback price for a token
     * @param tokenId Token ID
     */
    function removeFallbackPrice(bytes32 tokenId) external onlyOwner {
        require(tokenId != bytes32(0), "Invalid token ID");
        
        delete fallbackPrices[tokenId];
        emit FallbackPriceSet(tokenId, 0);
    }
    
    /**
     * @dev Get token price feed address
     * @param tokenId Token ID
     * @return Price feed address (address(0) if not set)
     */
    function getTokenPriceFeed(bytes32 tokenId) external view returns (address) {
        return address(tokenPriceFeeds[tokenId]);
    }
    
    /**
     * @dev Get fallback price for token
     * @param tokenId Token ID
     * @return Fallback price in USD with 8 decimals
     */
    function getFallbackPrice(bytes32 tokenId) external view returns (uint256) {
        return fallbackPrices[tokenId];
    }

    function rescueTokenCCIP(IERC20 token, uint256 amount) external onlyOwner {
        require(address(token) != address(0), "Invalid token address");
        require(
            token.balanceOf(address(this)) >= amount,
            "Insufficient token balance"
        );
        token.safeTransfer(owner(), amount);
        emit RescueTokenCCIP(address(token), amount);
    }

    function rescueTokenVL(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient native balance");
        payable(owner()).transfer(amount);
        emit RescueTokenVL(amount);
    }

    function withdraw(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        to.transfer(amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {}

    fallback() external payable {}
}
