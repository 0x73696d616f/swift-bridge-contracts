// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MintableERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(0x81B14fEa9FBf83937b97bA0F7Ef8383Cd10236F7, 1000e18);
    }

    function faucet() external {
        _mint(msg.sender, 1_000_000);
    } 
}