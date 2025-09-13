// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BambooPresale is Ownable, ReentrancyGuard {
    // Token ERC20 được sử dụng trong cuộc gọi vốn
    IERC20 public presaleTokenAddress;
    
    // Token thanh toán (USDT nếu được chỉ định, để trống nếu dùng native token)
    IERC20 public paymentToken;
    bool public useNativeToken; // true nếu dùng native token (ETH/BNB/AVA), false nếu dùng USDT
    
    // Thông tin cuộc gọi vốn
    uint256 public targetAmount; // Số tiền cần gọi
    uint256 public softCap; // Ngưỡng tối thiểu để gọi vốn thành công
    uint256 public startTime; // Thời gian bắt đầu (timestamp)
    uint256 public endTime; // Thời gian kết thúc (timestamp)
    uint256 public totalTokens; // Tổng số token phân bổ
    uint256 public minContribution; // Số tiền tối thiểu mỗi người góp
    uint256 public maxContribution; // Số tiền tối đa mỗi người góp
    uint256 public totalRaised; // Tổng số tiền đã gọi được
    bool public finalized; // Trạng thái hoàn tất
    bool public cancelled; // Trạng thái hủy
    bool public tokensDeposited; // Trạng thái đã deposit token
    
    // Danh sách contributors
    mapping(address => uint256) public contributions;
    mapping(address => uint256) public contributionTimes; // Thời gian góp vốn
    mapping(address => bool) public hasClaimed; // Trạng thái đã claim token
    mapping(address => uint256) public tokensClaimed; // Số token đã claim bởi mỗi contributor
    address[] public contributors;
    
    // Ví nhận tiền khi gọi vốn thành công
    address public userWallet;
    
    // Ví nhận phí hệ thống
    address public systemWallet;
    
    // Struct để lưu thông tin contributor
    struct ContributorInfo {
        address wallet;
        uint256 amount;
        uint256 timestamp;
        bool hasClaimed;
        uint256 tokensClaimed;
    }
    
    // Sự kiện
    event Contributed(address indexed contributor, uint256 amount, uint256 timestamp);
    event Finalized(uint256 totalRaised, uint256 tokensDistributed);
    event Cancelled();
    event TokensClaimed(address indexed contributor, uint256 tokenAmount);
    event TokensDeposited(uint256 amount);
    
    constructor(
        address _presaleTokenAddress,
        address _paymentToken, // Địa chỉ USDT hoặc address(0) nếu dùng native token
        uint256 _targetAmount,
        uint256 _softCap,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _totalTokens,
        uint256 _minContribution,
        uint256 _maxContribution,
        address _userWallet,
        address _systemWallet,
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_softCap <= _targetAmount, "SoftCap must be less than or equal to target amount");
        require(_totalTokens > 0, "Total tokens must be greater than 0");
        require(_minContribution > 0, "Min contribution must be greater than 0");
        require(_maxContribution >= _minContribution, "Max contribution must be >= min contribution");
        require(_presaleTokenAddress != address(0), "Token address cannot be zero");
        require(_userWallet != address(0), "User wallet cannot be zero");
        require(_systemWallet != address(0), "System wallet cannot be zero");
        
        presaleTokenAddress = IERC20(_presaleTokenAddress);
        useNativeToken = _paymentToken == address(0);
        if (!useNativeToken) {
            paymentToken = IERC20(_paymentToken);
        }
        targetAmount = _targetAmount;
        softCap = _softCap;
        startTime = _startTime;
        endTime = _endTime;
        totalTokens = _totalTokens;
        minContribution = _minContribution;
        maxContribution = _maxContribution;
        userWallet = _userWallet;
        systemWallet = _systemWallet;
        finalized = false;
        cancelled = false;
        tokensDeposited = false;
    }
    
    // Hàm deposit tokens: systemWallet chuyển token vào contract
    function depositTokens() external onlyOwner {
        require(!tokensDeposited, "Tokens already deposited");
        require(!finalized && !cancelled, "Campaign is finalized or cancelled");
        require(presaleTokenAddress.allowance(systemWallet, address(this)) >= totalTokens, "Insufficient allowance from systemWallet");
        
        require(presaleTokenAddress.transferFrom(systemWallet, address(this), totalTokens), "Token transfer from systemWallet failed");
        
        tokensDeposited = true;
        emit TokensDeposited(totalTokens);
    }
    
    // Hàm contribute: Góp vốn vào cuộc gọi vốn, chỉ cho phép góp một lần
    function contribute(uint256 _amount) external payable nonReentrant {
        require(!finalized && !cancelled, "Campaign is finalized or cancelled");
        require(tokensDeposited, "Tokens not deposited yet");
        require(block.timestamp >= startTime, "Campaign has not started");
        require(block.timestamp <= endTime, "Campaign has ended");
        require(_amount >= minContribution, "Contribution below minimum");
        require(_amount <= maxContribution, "Contribution above maximum");
        require(totalRaised + _amount <= targetAmount, "Exceeds target amount");
        require(contributions[msg.sender] == 0, "Contributor has already participated");
        
        if (useNativeToken) {
            require(msg.value == _amount, "Incorrect native token amount sent");
        } else {
            require(msg.value == 0, "Do not send native tokens when using ERC20");
            require(paymentToken.transferFrom(msg.sender, address(this), _amount), "Payment token transfer failed");
        }
        
        contributors.push(msg.sender);
        contributions[msg.sender] = _amount;
        contributionTimes[msg.sender] = block.timestamp;
        hasClaimed[msg.sender] = false; // Khởi tạo trạng thái chưa claim
        tokensClaimed[msg.sender] = 0; // Khởi tạo số token đã claim
        totalRaised += _amount;
        
        emit Contributed(msg.sender, _amount, block.timestamp);
    }
    
    // Hàm cancel: Hủy cuộc gọi vốn
    function cancel() external onlyOwner nonReentrant {
        require(!finalized && !cancelled, "Campaign is finalized or cancelled");
        require(block.timestamp <= endTime, "Campaign has ended");
        
        cancelled = true;
        
        // Hoàn tiền cho contributors
        for (uint256 i = 0; i < contributors.length; i++) {
            address contributor = contributors[i];
            uint256 amount = contributions[contributor];
            if (amount > 0) {
                contributions[contributor] = 0;
                contributionTimes[contributor] = 0;
                hasClaimed[contributor] = false; // Reset trạng thái claim
                tokensClaimed[contributor] = 0; // Reset số token đã claim
                if (useNativeToken) {
                    payable(contributor).transfer(amount);
                } else {
                    require(paymentToken.transfer(contributor, amount), "Payment token refund failed");
                }
            }
        }
        
        // Hoàn token cho userWallet
        uint256 remainingTokens = presaleTokenAddress.balanceOf(address(this));
        if (remainingTokens > 0) {
            require(presaleTokenAddress.transfer(userWallet, remainingTokens), "Token transfer failed");
        }
        
        emit Cancelled();
    }
    
    // Hàm finalize: Kết thúc cuộc gọi vốn
    function finalize() external onlyOwner nonReentrant {
        require(!finalized && !cancelled, "Campaign is finalized or cancelled");
        require(tokensDeposited, "Tokens not deposited yet");
        require(block.timestamp > endTime || totalRaised >= softCap, "Campaign is still active or softCap not reached");
        
        finalized = true;
        
        // Kiểm tra nếu đạt softCap
        if (totalRaised >= softCap) {
            // Phí hệ thống (2% số tiền gọi được)
            uint256 systemFee = totalRaised * 2 / 100;
            uint256 ownerAmount = totalRaised - systemFee;
            
            if (useNativeToken) {
                payable(systemWallet).transfer(systemFee);
                payable(userWallet).transfer(ownerAmount);
            } else {
                require(paymentToken.transfer(systemWallet, systemFee), "System fee transfer failed");
                require(paymentToken.transfer(userWallet, ownerAmount), "Owner payment transfer failed");
            }
            
            // Burn token không sử dụng nếu không đạt target
            if (totalRaised < targetAmount) {
                uint256 tokensToDistribute = (totalRaised * totalTokens) / targetAmount;
                uint256 tokensToBurn = totalTokens - tokensToDistribute;
                if (tokensToBurn > 0) {
                    require(presaleTokenAddress.transfer(address(0xdead), tokensToBurn), "Token burn failed");
                }
                emit Finalized(totalRaised, tokensToDistribute);
            } else {
                emit Finalized(totalRaised, totalTokens);
            }
        } else {
            // Nếu không đạt softCap, hoàn tiền và token
            for (uint256 i = 0; i < contributors.length; i++) {
                address contributor = contributors[i];
                uint256 amount = contributions[contributor];
                if (amount > 0) {
                    contributions[contributor] = 0;
                    contributionTimes[contributor] = 0;
                    hasClaimed[contributor] = false; // Reset trạng thái claim
                    tokensClaimed[contributor] = 0; // Reset số token đã claim
                    if (useNativeToken) {
                        payable(contributor).transfer(amount);
                    } else {
                        require(paymentToken.transfer(contributor, amount), "Payment token refund failed");
                    }
                }
            }
            
            uint256 remainingTokens = presaleTokenAddress.balanceOf(address(this));
            if (remainingTokens > 0) {
                require(presaleTokenAddress.transfer(userWallet, remainingTokens), "Token transfer failed");
            }
            
            emit Finalized(totalRaised, 0);
        }
    }
    
    // Hàm claimTokens: Contributors nhận token
    function claimTokens() external nonReentrant {
        require(finalized && !cancelled, "Campaign not finalized");
        require(totalRaised >= softCap, "SoftCap not reached");
        require(contributions[msg.sender] > 0, "No contribution found");
        require(!hasClaimed[msg.sender], "Tokens already claimed");
        
        uint256 contribution = contributions[msg.sender];

        uint256 tokenAmount = (contribution * totalTokens) / targetAmount;
        require(presaleTokenAddress.transfer(msg.sender, tokenAmount), "Token transfer failed");
        
        hasClaimed[msg.sender] = true; // Đánh dấu đã claim
        tokensClaimed[msg.sender] = tokenAmount; // Ghi lại số token đã claim
        
        emit TokensClaimed(msg.sender, tokenAmount);
    }
    
    // Hàm kiểm tra xem contributor đã claim token chưa
    function hasContributorClaimed(address _contributor) external view returns (bool) {
        return hasClaimed[_contributor];
    }
    
    // Hàm lấy số token đã claim bởi một contributor
    function getTokensClaimed(address _contributor) external view returns (uint256) {
        return tokensClaimed[_contributor];
    }
    
    // Hàm getContributors: Lấy danh sách contributors với thông tin chi tiết
    function getContributors() external view returns (ContributorInfo[] memory) {
        ContributorInfo[] memory contributorInfos = new ContributorInfo[](contributors.length);
        for (uint256 i = 0; i < contributors.length; i++) {
            address contributor = contributors[i];
            contributorInfos[i] = ContributorInfo({
                wallet: contributor,
                amount: contributions[contributor],
                timestamp: contributionTimes[contributor],
                hasClaimed: hasClaimed[contributor],
                tokensClaimed: tokensClaimed[contributor]
            });
        }
        return contributorInfos;
    }
    
    // Hàm lấy thông tin cơ bản của cuộc gọi vốn
    function getCampaignInfoBasic() external view returns (
        bool _finalized,
        bool _cancelled,
        bool _tokensDeposited,
        bool _useNativeToken,
        uint256 _targetAmount,
        uint256 _softCap,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _totalTokens,
        uint256 _minContribution,
        uint256 _maxContribution,
        uint256 _totalRaised
    ) {
        return (
            finalized,
            cancelled,
            tokensDeposited,
            useNativeToken,
            targetAmount,
            softCap,
            startTime,
            endTime,
            totalTokens,
            minContribution,
            maxContribution,
            totalRaised
        );
    }
    
    // Hàm lấy thông tin địa chỉ và trạng thái của cuộc gọi vốn
    function getCampaignInfoAddresses() external view returns (
        address _userWallet,
        address _systemWallet,
        address _paymentToken,
        IERC20 _presaleTokenAddress
    ) {
        return (
            userWallet,
            systemWallet,
            address(paymentToken),
            presaleTokenAddress
        );
    }
    
    // Emergency function to withdraw tokens (only owner)
    function emergencyWithdrawTokens() external onlyOwner {
        require(!finalized && !cancelled, "Campaign is finalized or cancelled");
        uint256 balance = presaleTokenAddress.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(presaleTokenAddress.transfer(systemWallet, balance), "Token transfer failed");
    }
    
    // Emergency function to withdraw payment tokens (only owner)
    function emergencyWithdrawPaymentTokens() external onlyOwner {
        require(!finalized && !cancelled, "Campaign is finalized or cancelled");
        if (useNativeToken) {
            uint256 balance = address(this).balance;
            require(balance > 0, "No native tokens to withdraw");
            payable(systemWallet).transfer(balance);
        } else {
            uint256 balance = paymentToken.balanceOf(address(this));
            require(balance > 0, "No payment tokens to withdraw");
            require(paymentToken.transfer(systemWallet, balance), "Payment token transfer failed");
        }
    }
}