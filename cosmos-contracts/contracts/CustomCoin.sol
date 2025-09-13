// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract CustomCoin is ERC20, Ownable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    uint8 private _customDecimals;

    modifier onlyMinter() {
        require(msg.sender == owner() || hasRole(MINTER_ROLE, msg.sender), "Not authorized to mint");
        _;
    }
    modifier onlyBurner() {
        require(msg.sender == owner() || hasRole(BURNER_ROLE, msg.sender), "Not authorized to burn");
        _;
    }

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) Ownable(msg.sender) {
        _customDecimals = decimals_;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    function decimals() public view override returns (uint8) {
        return _customDecimals;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyBurner {
        _burn(from, amount);
    }

    function grantMinterRole(
        address account
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    function grantBurnerRole(
        address account
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BURNER_ROLE, account);
    }

    function revokeMinterRole(
        address account
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }

    function revokeBurnerRole(
        address account
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(BURNER_ROLE, account);
    }

    function hasMinterRole(address account) public view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    function hasBurnerRole(address account) public view returns (bool) {
        return hasRole(BURNER_ROLE, account);
    }
}

