// SPDX-License-Identifier: UNLICENSED
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