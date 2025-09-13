// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { BambooOFT } from "../BambooOFT.sol";

// @dev WARNING: This is for testing purposes only
contract MyOFTMock is BambooOFT {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _owner,
        address _delegate,
        uint256 _totalSupply
    ) BambooOFT(_name, _symbol, _lzEndpoint, _owner, _delegate, _totalSupply) {}

    function mint(address _to, uint256 _amount) public override {
        _mint(_to, _amount);
    }
}
