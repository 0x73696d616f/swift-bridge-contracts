// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MintableERC20 is ERC20 {
    constructor() ERC20("MintableERC20", "MERC20") {
        _mint(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 1000e18);
    }
}