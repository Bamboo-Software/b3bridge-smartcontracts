// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

contract BambooOFT is OFT {
    // Events
    event TokensMinted(address indexed to, uint256 amount);
    event MintingFinalized();
    
    // State variables
    bool public mintingFinalized;
    uint256 public maxSupply; // Max supply cho chain này
    
    modifier mintingNotFinalized() {
        require(!mintingFinalized, "BambooOFT: Minting has been finalized");
        _;
    }
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _owner,
        address _delegate,
        uint256 _totalSupply // Total supply cho chain này
    ) OFT(_name, _symbol, _lzEndpoint, _owner) Ownable(_owner) {
        maxSupply = _totalSupply;
        
        // Tự động mint toàn bộ supply cho owner ngay khi deploy
        if (_totalSupply > 0) {
            _mint(_delegate, _totalSupply);
            emit TokensMinted(_delegate, _totalSupply);
        }
    }
    
    /**
     * @dev Mint tokens to specified address
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external virtual onlyOwner mintingNotFinalized {
        require(to != address(0), "BambooOFT: Cannot mint to zero address");
        require(amount > 0, "BambooOFT: Amount must be greater than 0");
        
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
    
    /**
     * @dev Batch mint to multiple addresses
     * @param recipients Array of addresses to mint to
     * @param amounts Array of amounts to mint
     */
    function batchMint(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner mintingNotFinalized {
        require(recipients.length == amounts.length, "BambooOFT: Arrays length mismatch");
        require(recipients.length > 0, "BambooOFT: Empty arrays");
        
        uint256 totalMintAmount = 0;
        
        // Calculate total mint amount first
        for (uint256 i = 0; i < amounts.length; i++) {
            require(recipients[i] != address(0), "BambooOFT: Cannot mint to zero address");
            require(amounts[i] > 0, "BambooOFT: Amount must be greater than 0");
            totalMintAmount += amounts[i];
        }
        
        // Perform minting
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
            emit TokensMinted(recipients[i], amounts[i]);
        }
    }
    

    
    /**
     * @dev Finalize minting - không thể mint thêm sau khi gọi
     */
    function finalizeMinting() external onlyOwner {
        require(!mintingFinalized, "BambooOFT: Minting already finalized");
        mintingFinalized = true;
        emit MintingFinalized();
    }
    
    /**
     * @dev Get current supply info for this chain
     */
    function getSupplyInfo() external view returns (
        uint256 currentSupply,
        uint256 chainMaxSupply,
        bool mintingActive
    ) {
        currentSupply = totalSupply();
        chainMaxSupply = maxSupply;
        mintingActive = !mintingFinalized;
    }
}