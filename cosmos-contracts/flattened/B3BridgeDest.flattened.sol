

// Sources flattened with hardhat v2.24.2 https://hardhat.org

// SPDX-License-Identifier: MIT AND UNLICENSED

// File @chainlink/contracts-ccip/contracts/libraries/Client.sol@v1.6.0

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.0;

// End consumer library.
library Client {
  /// @dev RMN depends on this struct, if changing, please notify the RMN maintainers.
  struct EVMTokenAmount {
    address token; // token address on the local chain.
    uint256 amount; // Amount of tokens.
  }

  struct Any2EVMMessage {
    bytes32 messageId; // MessageId corresponding to ccipSend on source.
    uint64 sourceChainSelector; // Source chain selector.
    bytes sender; // abi.decode(sender) if coming from an EVM chain.
    bytes data; // payload sent in original message.
    EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
  }

  // If extraArgs is empty bytes, the default is 200k gas limit.
  struct EVM2AnyMessage {
    bytes receiver; // abi.encode(receiver address) for dest EVM chains.
    bytes data; // Data payload.
    EVMTokenAmount[] tokenAmounts; // Token transfers.
    address feeToken; // Address of feeToken. address(0) means you will send msg.value.
    bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2).
  }

  // Tag to indicate only a gas limit. Only usable for EVM as destination chain.
  bytes4 public constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;

  struct EVMExtraArgsV1 {
    uint256 gasLimit;
  }

  function _argsToBytes(
    EVMExtraArgsV1 memory extraArgs
  ) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(EVM_EXTRA_ARGS_V1_TAG, extraArgs);
  }

  // Tag to indicate a gas limit (or dest chain equivalent processing units) and Out Of Order Execution. This tag is
  // available for multiple chain families. If there is no chain family specific tag, this is the default available
  // for a chain.
  // Note: not available for Solana VM based chains.
  bytes4 public constant GENERIC_EXTRA_ARGS_V2_TAG = 0x181dcf10;

  /// @param gasLimit: gas limit for the callback on the destination chain.
  /// @param allowOutOfOrderExecution: if true, it indicates that the message can be executed in any order relative to
  /// other messages from the same sender. This value's default varies by chain. On some chains, a particular value is
  /// enforced, meaning if the expected value is not set, the message request will revert.
  /// @dev Fully compatible with the previously existing EVMExtraArgsV2.
  struct GenericExtraArgsV2 {
    uint256 gasLimit;
    bool allowOutOfOrderExecution;
  }

  // Extra args tag for chains that use the Solana VM.
  bytes4 public constant SVM_EXTRA_ARGS_V1_TAG = 0x1f3b3aba;

  struct SVMExtraArgsV1 {
    uint32 computeUnits;
    uint64 accountIsWritableBitmap;
    bool allowOutOfOrderExecution;
    bytes32 tokenReceiver;
    // Additional accounts needed for execution of CCIP receiver. Must be empty if message.receiver is zero.
    // Token transfer related accounts are specified in the token pool lookup table on SVM.
    bytes32[] accounts;
  }

  /// @dev The maximum number of accounts that can be passed in SVMExtraArgs.
  uint256 public constant SVM_EXTRA_ARGS_MAX_ACCOUNTS = 64;

  /// @dev The expected static payload size of a token transfer when Borsh encoded and submitted to SVM.
  /// TokenPool extra data and offchain data sizes are dynamic, and should be accounted for separately.
  uint256 public constant SVM_TOKEN_TRANSFER_DATA_OVERHEAD = (4 + 32) // source_pool
    + 32 // token_address
    + 4 // gas_amount
    + 4 // extra_data overhead
    + 32 // amount
    + 32 // size of the token lookup table account
    + 32 // token-related accounts in the lookup table, over-estimated to 32, typically between 11 - 13
    + 32 // token account belonging to the token receiver, e.g ATA, not included in the token lookup table
    + 32 // per-chain token pool config, not included in the token lookup table
    + 32 // per-chain token billing config, not always included in the token lookup table
    + 32; // OffRamp pool signer PDA, not included in the token lookup table

  /// @dev Number of overhead accounts needed for message execution on SVM.
  /// @dev These are message.receiver, and the OffRamp Signer PDA specific to the receiver.
  uint256 public constant SVM_MESSAGING_ACCOUNTS_OVERHEAD = 2;

  /// @dev The size of each SVM account address in bytes.
  uint256 public constant SVM_ACCOUNT_BYTE_SIZE = 32;

  function _argsToBytes(
    GenericExtraArgsV2 memory extraArgs
  ) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(GENERIC_EXTRA_ARGS_V2_TAG, extraArgs);
  }

  function _svmArgsToBytes(
    SVMExtraArgsV1 memory extraArgs
  ) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(SVM_EXTRA_ARGS_V1_TAG, extraArgs);
  }
}


// File @chainlink/contracts-ccip/contracts/interfaces/IAny2EVMMessageReceiver.sol@v1.6.0

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Application contracts that intend to receive messages from  the router should implement this interface.
interface IAny2EVMMessageReceiver {
  /// @notice Called by the Router to deliver a message. If this reverts, any token transfers also revert.
  /// The message will move to a FAILED state and become available for manual execution.
  /// @param message CCIP Message.
  /// @dev Note ensure you check the msg.sender is the OffRampRouter.
  function ccipReceive(
    Client.Any2EVMMessage calldata message
  ) external;
}


// File @chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v5.0.2/contracts/utils/introspection/IERC165.sol@v1.4.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File @chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol@v1.6.0

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.4;

/// @title CCIPReceiver - Base contract for CCIP applications that can receive messages.
abstract contract CCIPReceiver is IAny2EVMMessageReceiver, IERC165 {
  address internal immutable i_ccipRouter;

  constructor(
    address router
  ) {
    if (router == address(0)) revert InvalidRouter(address(0));
    i_ccipRouter = router;
  }

  /// @notice IERC165 supports an interfaceId.
  /// @param interfaceId The interfaceId to check.
  /// @return true if the interfaceId is supported.
  /// @dev Should indicate whether the contract implements IAny2EVMMessageReceiver.
  /// e.g. return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId
  /// This allows CCIP to check if ccipReceive is available before calling it.
  /// - If this returns false or reverts, only tokens are transferred to the receiver.
  /// - If this returns true, tokens are transferred and ccipReceive is called atomically.
  /// Additionally, if the receiver address does not have code associated with it at the time of
  /// execution (EXTCODESIZE returns 0), only tokens will be transferred.
  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual override returns (bool) {
    return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  /// @inheritdoc IAny2EVMMessageReceiver
  function ccipReceive(
    Client.Any2EVMMessage calldata message
  ) external virtual override onlyRouter {
    _ccipReceive(message);
  }

  /// @notice Override this function in your implementation.
  /// @param message Any2EVMMessage.
  function _ccipReceive(
    Client.Any2EVMMessage memory message
  ) internal virtual;

  /// @notice Return the current router
  /// @return CCIP router address
  function getRouter() public view virtual returns (address) {
    return address(i_ccipRouter);
  }

  error InvalidRouter(address router);

  /// @dev only calls from the set router are accepted.
  modifier onlyRouter() {
    if (msg.sender != getRouter()) revert InvalidRouter(msg.sender);
    _;
  }
}


// File @chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol@v1.6.0

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.4;

interface IRouterClient {
  error UnsupportedDestinationChain(uint64 destChainSelector);
  error InsufficientFeeTokenAmount();
  error InvalidMsgValue();

  /// @notice Checks if the given chain ID is supported for sending/receiving.
  /// @param destChainSelector The chain to check.
  /// @return supported is true if it is supported, false if not.
  function isChainSupported(
    uint64 destChainSelector
  ) external view returns (bool supported);

  /// @param destinationChainSelector The destination chainSelector.
  /// @param message The cross-chain CCIP message including data and/or tokens.
  /// @return fee returns execution fee for the message.
  /// delivery to destination chain, denominated in the feeToken specified in the message.
  /// @dev Reverts with appropriate reason upon invalid message.
  function getFee(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage memory message
  ) external view returns (uint256 fee);

  /// @notice Request a message to be sent to the destination chain.
  /// @param destinationChainSelector The destination chain ID.
  /// @param message The cross-chain CCIP message including data and/or tokens.
  /// @return messageId The message ID.
  /// @dev Note if msg.value is larger than the required fee (from getFee) we accept.
  /// the overpayment with no refund.
  /// @dev Reverts with appropriate reason upon invalid message.
  function ccipSend(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage calldata message
  ) external payable returns (bytes32);
}


// File @openzeppelin/contracts/utils/Context.sol@v5.3.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// File @openzeppelin/contracts/access/Ownable.sol@v5.3.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File @openzeppelin/contracts/interfaces/draft-IERC6093.sol@v5.3.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/draft-IERC6093.sol)
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC-721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC-1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}


// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v5.3.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// File @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol@v5.3.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// File @openzeppelin/contracts/token/ERC20/ERC20.sol@v5.3.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;




/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * Both values are immutable: they can only be set once during construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner`'s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner`'s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}


// File @openzeppelin/contracts/utils/cryptography/ECDSA.sol@v5.3.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.20;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS
    }

    /**
     * @dev The signature derives the `address(0)`.
     */
    error ECDSAInvalidSignature();

    /**
     * @dev The signature has an invalid length.
     */
    error ECDSAInvalidSignatureLength(uint256 length);

    /**
     * @dev The signature has an S value that is in the upper half order.
     */
    error ECDSAInvalidSignatureS(bytes32 s);

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with `signature` or an error. This will not
     * return address(0) without also returning an error description. Errors are documented using an enum (error type)
     * and a bytes32 providing additional information about the error.
     *
     * If no error is returned, then the address can be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     */
    function tryRecover(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly ("memory-safe") {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[ERC-2098 short signatures]
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        unchecked {
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            // We do not check for an overflow here since the shift operation results in 0 or 1.
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            return tryRecover(hash, v, r, s);
        }
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, r, vs);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS, s);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature, bytes32(0));
        }

        return (signer, RecoverError.NoError, bytes32(0));
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, v, r, s);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Optionally reverts with the corresponding custom error according to the `error` argument provided.
     */
    function _throwError(RecoverError error, bytes32 errorArg) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert ECDSAInvalidSignature();
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert ECDSAInvalidSignatureLength(uint256(errorArg));
        } else if (error == RecoverError.InvalidSignatureS) {
            revert ECDSAInvalidSignatureS(errorArg);
        }
    }
}


// File @openzeppelin/contracts/utils/ReentrancyGuard.sol@v5.3.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}


// File contracts/interfaces/ICustomCoin.sol

// Original license: SPDX_License_Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ICustomCoin {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}


// File contracts/interfaces/ISeiOracle.sol

// Original license: SPDX_License_Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title ISeiOracle Interface
/// @notice Interface to get exchange rates from the Sei Oracle
interface ISeiOracle {
    /// @notice Struct representing an oracle exchange rate
    struct OracleExchangeRate {
        string exchangeRate;
        string lastUpdate;
        int64 lastUpdateTimestamp;
    }

    /// @notice Struct representing a pair of denom and its oracle exchange rate
    struct DenomOracleExchangeRatePair {
        string denom;
        OracleExchangeRate oracleExchangeRateVal;
    }

    /// @notice Gets all exchange rates
    /// @return An array of denom and their corresponding oracle exchange rates
    function getExchangeRates()
        external
        view
        returns (DenomOracleExchangeRatePair[] memory);
}


// File contracts/B3BridgeSei.sol

// Original license: SPDX_License_Identifier: UNLICENSED
pragma solidity ^0.8.20;









contract B3BridgeSei is CCIPReceiver, Ownable, ReentrancyGuard {
    ISeiOracle internal oracle =
        ISeiOracle(0x0000000000000000000000000000000000001008);
    using ECDSA for bytes32;
    mapping(bytes32 => address) public tokenMapping;
    address public sourceBridge;
    uint64 public sourceChainSelector;
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
        uint256 chainId;
    }
    uint64 public minFee;
    uint64 public maxFee;

    event DebugTokenAddress(bytes32 tokenId, address tokenAddress);
    event MintTokenCCIP(address receiver, bytes32 tokenId, uint256 amount);
    event BurnTokenVL(
        address indexed sender,
        address destWalletAddress,
        uint256 amount,
        uint256 fee,
        address indexed sourceBridge,
        address wTokenAddress,
        uint256 chainId
    );

    event MintedTokenVL(address recipientAddr, address token, uint256 amount);
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
        address _sourceBridge,
        uint64 _sourceChainSelector,
        address[] memory _validators,
        uint256 _threshold
    ) CCIPReceiver(router) Ownable(msg.sender) {
        require(_validators.length > 0, "Validator list cannot be empty");
        require(
            _threshold > 0 && _threshold <= _validators.length,
            "Invalid threshold"
        );

        sourceBridge = _sourceBridge;
        sourceChainSelector = _sourceChainSelector;

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
    }

    function getFeeCCIP(
        IERC20 token,
        uint256 amount,
        bytes32 tokenId
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

        emit MintTokenCCIP(receiver, tokenId, amount);
    }

    function burnTokenCCIP(
        bytes32 tokenId,
        uint256 amount
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
            "Amount sent is too small"
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

        emit MintedTokenVL(data.to, data.tokenAddr, data.amount);
        emit InterchainCall(
            payloadData[txKey].chainId,
            "distributeFee",
            txKey,
            signaturesOfValidator[txKey],
            data.amount
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

    function updateSourceBridge(
        address _sourceBridge,
        uint64 _sourceChainSelector
    ) external onlyOwner {
        sourceBridge = _sourceBridge;
        sourceChainSelector = _sourceChainSelector;
    }
}
