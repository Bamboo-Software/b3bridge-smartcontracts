// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/BambooPresale.sol";
import "../../test/mocks/ERC20Mock.sol";

contract BambooPresaleTest is Test {
    BambooPresale public presale;
    ERC20Mock public token;
    ERC20Mock public paymentToken;
    
    address public owner = address(0x1);
    address public tokenWallet = address(0x2);
    address public contributor1 = address(0x3);
    address public contributor2 = address(0x4);
    address public contributor3 = address(0x5);
    
    uint256 public constant TARGET_AMOUNT = 1000 ether;
    uint256 public constant SOFT_CAP = 500 ether;
    uint256 public constant TOTAL_TOKENS = 10000 ether;
    uint256 public constant MIN_CONTRIBUTION = 1 ether;
    uint256 public constant MAX_CONTRIBUTION = 100 ether;
    uint256 public startTime;
    uint256 public endTime;
    
    event Contributed(address indexed contributor, uint256 amount);
    event Finalized(uint256 totalRaised, uint256 tokensDistributed);
    event Cancelled();
    event TokensClaimed(address indexed contributor, uint256 tokenAmount);
    event TokensDeposited(uint256 amount);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy mock tokens
        token = new ERC20Mock("Test Token", "TEST");
        paymentToken = new ERC20Mock("USDT", "USDT");
        
        // Set up time
        startTime = block.timestamp + 1 hours;
        endTime = startTime + 30 days;
        
        // Deploy presale contract
        presale = new BambooPresale(
            address(token),
            address(paymentToken), // Use USDT as payment token
            TARGET_AMOUNT,
            SOFT_CAP, // softCap
            startTime,
            endTime,
            TOTAL_TOKENS,
            MIN_CONTRIBUTION,
            MAX_CONTRIBUTION,
            tokenWallet, // userWallet
            owner, // systemWallet
            owner // initialOwner
        );
        
        // Mint tokens to token wallet
        token.mint(tokenWallet, TOTAL_TOKENS);
        paymentToken.mint(contributor1, 1000 ether);
        paymentToken.mint(contributor2, 1000 ether);
        paymentToken.mint(contributor3, 1000 ether);
        
        vm.stopPrank();
    }
    
    // ============ Constructor Tests ============
    
    function testConstructor() public {
        assertEq(address(presale.presaleTokenAddress()), address(token));
        assertEq(address(presale.paymentToken()), address(paymentToken));
        assertEq(presale.useNativeToken(), false);
        assertEq(presale.targetAmount(), TARGET_AMOUNT);
        assertEq(presale.startTime(), startTime);
        assertEq(presale.endTime(), endTime);
        assertEq(presale.totalTokens(), TOTAL_TOKENS);
        assertEq(presale.minContribution(), MIN_CONTRIBUTION);
        assertEq(presale.maxContribution(), MAX_CONTRIBUTION);
        assertEq(presale.userWallet(), tokenWallet);
        assertEq(presale.owner(), owner);
        assertEq(presale.finalized(), false);
        assertEq(presale.cancelled(), false);
        assertEq(presale.tokensDeposited(), false);
    }
    
    function testConstructorWithNativeToken() public {
        vm.startPrank(owner);
        
        BambooPresale nativePresale = new BambooPresale(
            address(token),
            address(0), // Use native token
            TARGET_AMOUNT,
            SOFT_CAP, // softCap
            startTime,
            endTime,
            TOTAL_TOKENS,
            MIN_CONTRIBUTION,
            MAX_CONTRIBUTION,
            tokenWallet, // userWallet
            owner, // systemWallet
            owner // initialOwner
        );
        
        assertEq(nativePresale.useNativeToken(), true);
        assertEq(address(nativePresale.paymentToken()), address(0));
        
        vm.stopPrank();
    }
    
    function testConstructorRevertInvalidStartTime() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Start time must be in the future");
        new BambooPresale(
            address(token),
            address(paymentToken),
            TARGET_AMOUNT,
            SOFT_CAP, // softCap
            block.timestamp - 1, // Past time
            endTime,
            TOTAL_TOKENS,
            MIN_CONTRIBUTION,
            MAX_CONTRIBUTION,
            tokenWallet, // userWallet
            owner, // systemWallet
            owner // initialOwner
        );
        
        vm.stopPrank();
    }
    
    function testConstructorRevertInvalidEndTime() public {
        vm.startPrank(owner);
        
        vm.expectRevert("End time must be after start time");
        new BambooPresale(
            address(token),
            address(paymentToken),
            TARGET_AMOUNT,
            SOFT_CAP, // softCap
            startTime,
            startTime - 1, // Before start time
            TOTAL_TOKENS,
            MIN_CONTRIBUTION,
            MAX_CONTRIBUTION,
            tokenWallet, // userWallet
            owner, // systemWallet
            owner // initialOwner
        );
        
        vm.stopPrank();
    }
    
    function testConstructorRevertZeroTargetAmount() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Target amount must be greater than 0");
        new BambooPresale(
            address(token),
            address(paymentToken),
            0, // Zero target amount
            SOFT_CAP, // softCap
            startTime,
            endTime,
            TOTAL_TOKENS,
            MIN_CONTRIBUTION,
            MAX_CONTRIBUTION,
            tokenWallet, // userWallet
            owner, // systemWallet
            owner // initialOwner
        );
        
        vm.stopPrank();
    }
    
    // ============ Deposit Tokens Tests ============
    
    function testDepositTokens() public {
        vm.startPrank(owner);
        
        // Transfer tokens to presale contract
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        
        // Deposit tokens
        vm.expectEmit(true, false, false, true);
        emit TokensDeposited(TOTAL_TOKENS);
        presale.depositTokens();
        
        assertEq(presale.tokensDeposited(), true);
        
        vm.stopPrank();
    }
    
    function testDepositTokensRevertInsufficientBalance() public {
        vm.startPrank(owner);
        
        // Don't transfer tokens to contract
        vm.expectRevert("Insufficient tokens in contract");
        presale.depositTokens();
        
        vm.stopPrank();
    }
    
    function testDepositTokensRevertAlreadyDeposited() public {
        vm.startPrank(owner);
        
        // Transfer tokens to presale contract
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        
        // Deposit tokens first time
        presale.depositTokens();
        
        // Try to deposit again
        vm.expectRevert("Tokens already deposited");
        presale.depositTokens();
        
        vm.stopPrank();
    }
    
    function testDepositTokensRevertNotOwner() public {
        vm.startPrank(contributor1);
        
        vm.expectRevert();
        presale.depositTokens();
        
        vm.stopPrank();
    }
    
    // ============ Contribute Tests ============
    
    function testContributeWithPaymentToken() public {
        // Setup: deposit tokens
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        // Move time to after start time
        vm.warp(startTime + 1);
        
        // Approve payment token
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), 50 ether);
        
        // Contribute
        vm.expectEmit(true, false, false, true);
        emit Contributed(contributor1, 50 ether);
        presale.contribute(50 ether);
        
        assertEq(presale.contributions(contributor1), 50 ether);
        assertEq(presale.totalRaised(), 50 ether);
        assertEq(paymentToken.balanceOf(address(presale)), 50 ether);
        
        vm.stopPrank();
    }
    
    function testContributeWithNativeToken() public {
        // Deploy presale with native token
        vm.startPrank(owner);
        BambooPresale nativePresale = new BambooPresale(
            address(token),
            address(0), // Use native token
            TARGET_AMOUNT,
            SOFT_CAP, // softCap
            startTime,
            endTime,
            TOTAL_TOKENS,
            MIN_CONTRIBUTION,
            MAX_CONTRIBUTION,
            tokenWallet, // userWallet
            owner, // systemWallet
            owner // initialOwner
        );
        
        // Transfer tokens to presale contract
        vm.prank(tokenWallet);
        token.transfer(address(nativePresale), TOTAL_TOKENS);
        nativePresale.depositTokens();
        vm.stopPrank();
        
        // Move time to after start time
        vm.warp(startTime + 1);
        
        // Contribute with native token
        vm.deal(contributor1, 100 ether);
        vm.startPrank(contributor1);
        
        vm.expectEmit(true, false, false, true);
        emit Contributed(contributor1, 50 ether);
        nativePresale.contribute{value: 50 ether}(50 ether);
        
        assertEq(nativePresale.contributions(contributor1), 50 ether);
        assertEq(nativePresale.totalRaised(), 50 ether);
        assertEq(address(nativePresale).balance, 50 ether);
        
        vm.stopPrank();
    }
    
    function testContributeRevertTokensNotDeposited() public {
        // Move time to after start time
        vm.warp(startTime + 1);
        
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), 50 ether);
        
        vm.expectRevert("Tokens not deposited yet");
        presale.contribute(50 ether);
        
        vm.stopPrank();
    }
    
    function testContributeRevertCampaignNotStarted() public {
        // Setup: deposit tokens
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        // Try to contribute before start time
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), 50 ether);
        
        vm.expectRevert("Campaign has not started");
        presale.contribute(50 ether);
        
        vm.stopPrank();
    }
    
    function testContributeRevertCampaignEnded() public {
        // Setup: deposit tokens
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        // Move time to after end time
        vm.warp(endTime + 1);
        
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), 50 ether);
        
        vm.expectRevert("Campaign has ended");
        presale.contribute(50 ether);
        
        vm.stopPrank();
    }
    
    function testContributeRevertBelowMinimum() public {
        // Setup: deposit tokens
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        // Move time to after start time
        vm.warp(startTime + 1);
        
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), 0.5 ether);
        
        vm.expectRevert("Contribution below minimum");
        presale.contribute(0.5 ether);
        
        vm.stopPrank();
    }
    
    function testContributeRevertAboveMaximum() public {
        // Setup: deposit tokens
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        // Move time to after start time
        vm.warp(startTime + 1);
        
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), 150 ether);
        
        vm.expectRevert("Contribution above maximum");
        presale.contribute(150 ether);
        
        vm.stopPrank();
    }
    
    function testContributeRevertExceedsTarget() public {
        // Setup: deposit tokens
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        // Move time to after start time
        vm.warp(startTime + 1);
        
        // Contribute up to target
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), TARGET_AMOUNT);
        presale.contribute(TARGET_AMOUNT);
        vm.stopPrank();
        
        // Try to contribute more
        vm.startPrank(contributor2);
        paymentToken.approve(address(presale), 1 ether);
        
        vm.expectRevert("Exceeds target amount");
        presale.contribute(1 ether);
        
        vm.stopPrank();
    }
    
    // ============ Finalize Tests ============
    
    function testFinalizeSuccess() public {
        // Setup: deposit tokens and contribute
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        vm.warp(startTime + 1);
        
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), 500 ether);
        presale.contribute(500 ether);
        vm.stopPrank();
        
        // Move time to after end time
        vm.warp(endTime + 1);
        
        // Finalize
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit Finalized(500 ether, 5000 ether); // 500 * 10000 / 1000
        presale.finalize();
        
        assertEq(presale.finalized(), true);
        assertEq(paymentToken.balanceOf(owner), 10 ether); // 2% fee
        assertEq(paymentToken.balanceOf(tokenWallet), 490 ether); // Remaining amount
        
        vm.stopPrank();
    }
    
    function testFinalizeRevertNotOwner() public {
        vm.startPrank(contributor1);
        
        vm.expectRevert();
        presale.finalize();
        
        vm.stopPrank();
    }
    
    function testFinalizeRevertTokensNotDeposited() public {
        vm.warp(endTime + 1);
        
        vm.startPrank(owner);
        vm.expectRevert("Tokens not deposited yet");
        presale.finalize();
        
        vm.stopPrank();
    }
    
    // ============ Claim Tokens Tests ============
    
    function testClaimTokens() public {
        // Setup: deposit tokens, contribute, and finalize
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        vm.warp(startTime + 1);
        
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), 100 ether);
        presale.contribute(100 ether);
        vm.stopPrank();
        
        vm.warp(endTime + 1);
        
        vm.startPrank(owner);
        presale.finalize();
        vm.stopPrank();
        
        // Claim tokens
        vm.startPrank(contributor1);
        uint256 expectedTokens = (100 ether * TOTAL_TOKENS) / TARGET_AMOUNT;
        
        vm.expectEmit(true, false, false, true);
        emit TokensClaimed(contributor1, expectedTokens);
        presale.claimTokens();
        
        assertEq(token.balanceOf(contributor1), expectedTokens);
        assertEq(presale.contributions(contributor1), 0);
        
        vm.stopPrank();
    }
    
    function testClaimTokensRevertNotFinalized() public {
        vm.startPrank(contributor1);
        
        vm.expectRevert("Campaign not finalized");
        presale.claimTokens();
        
        vm.stopPrank();
    }
    
    function testClaimTokensRevertNoContribution() public {
        // Setup: deposit tokens and finalize
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.warp(endTime + 1);
        presale.finalize();
        vm.stopPrank();
        
        vm.startPrank(contributor1);
        
        vm.expectRevert("No contribution found");
        presale.claimTokens();
        
        vm.stopPrank();
    }
    
    // ============ Cancel Tests ============
    
    function testCancel() public {
        // Setup: deposit tokens and contribute
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        vm.warp(startTime + 1);
        
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), 100 ether);
        presale.contribute(100 ether);
        vm.stopPrank();
        
        // Cancel
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit Cancelled();
        presale.cancel();
        
        assertEq(presale.cancelled(), true);
        assertEq(paymentToken.balanceOf(contributor1), 1000 ether); // Refunded
        assertEq(token.balanceOf(tokenWallet), TOTAL_TOKENS); // Tokens returned
        
        vm.stopPrank();
    }
    
    function testCancelRevertNotOwner() public {
        vm.startPrank(contributor1);
        
        vm.expectRevert();
        presale.cancel();
        
        vm.stopPrank();
    }
    
    // ============ Emergency Functions Tests ============
    
    function testEmergencyWithdrawTokens() public {
        // Setup: deposit tokens
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        // Emergency withdraw
        vm.startPrank(owner);
        presale.emergencyWithdrawTokens();
        
        assertEq(token.balanceOf(tokenWallet), TOTAL_TOKENS);
        assertEq(token.balanceOf(address(presale)), 0);
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdrawPaymentTokens() public {
        // Setup: contribute some payment tokens
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        vm.warp(startTime + 1);
        
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), 100 ether);
        presale.contribute(100 ether);
        vm.stopPrank();
        
        // Emergency withdraw payment tokens
        vm.startPrank(owner);
        presale.emergencyWithdrawPaymentTokens();
        
        assertEq(paymentToken.balanceOf(tokenWallet), 100 ether);
        assertEq(paymentToken.balanceOf(address(presale)), 0);
        
        vm.stopPrank();
    }
    
    // ============ View Functions Tests ============
    
    function testGetCampaignInfo() public {
        // Setup: deposit tokens
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        // Test basic info
        (
            bool finalized,
            bool cancelled,
            bool tokensDeposited,
            bool useNativeToken,
            uint256 targetAmount,
            uint256 softCap,
            uint256 startTime,
            uint256 endTime,
            uint256 totalTokens,
            uint256 minContribution,
            uint256 maxContribution,
            uint256 totalRaised
        ) = presale.getCampaignInfoBasic();
        
        assertEq(targetAmount, TARGET_AMOUNT);
        assertEq(softCap, SOFT_CAP);
        assertEq(startTime, startTime);
        assertEq(endTime, endTime);
        assertEq(totalTokens, TOTAL_TOKENS);
        assertEq(minContribution, MIN_CONTRIBUTION);
        assertEq(maxContribution, MAX_CONTRIBUTION);
        assertEq(totalRaised, 0);
        assertEq(finalized, false);
        assertEq(cancelled, false);
        assertEq(tokensDeposited, true);
        assertEq(useNativeToken, false);
        
        // Test addresses info
        (
            address userWallet,
            address systemWallet,
            address paymentToken,
            IERC20 presaleTokenAddress
        ) = presale.getCampaignInfoAddresses();
        
        assertEq(userWallet, tokenWallet);
        assertEq(paymentToken, address(paymentToken));
    }
    
    function testGetContributors() public {
        // Setup: deposit tokens and contribute
        vm.startPrank(owner);
        vm.prank(tokenWallet);
        token.transfer(address(presale), TOTAL_TOKENS);
        presale.depositTokens();
        vm.stopPrank();
        
        vm.warp(startTime + 1);
        
        vm.startPrank(contributor1);
        paymentToken.approve(address(presale), 100 ether);
        presale.contribute(100 ether);
        vm.stopPrank();
        
        vm.startPrank(contributor2);
        paymentToken.approve(address(presale), 200 ether);
        presale.contribute(200 ether);
        vm.stopPrank();
        
        BambooPresale.ContributorInfo[] memory contributors = presale.getContributors();
        assertEq(contributors.length, 2);
        assertEq(contributors[0].wallet, contributor1);
        assertEq(contributors[0].amount, 100 ether);
        assertEq(contributors[1].wallet, contributor2);
        assertEq(contributors[1].amount, 200 ether);
    }
} 