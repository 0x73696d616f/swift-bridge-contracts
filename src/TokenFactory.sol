// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Clones } from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol"; 
import { ERC20Token } from "./ERC20Token.sol";

contract TokenFactory {
    address internal immutable _implementation;
    address internal immutable _swiftGate;

    error OnlySwiftGateError(address msgSender_);

    modifier onlySwiftGate() {
        if(msg.sender != _swiftGate) revert OnlySwiftGateError(msg.sender);
        _;
    } 

    constructor() {
        _implementation = address(new ERC20Token());
        _swiftGate = msg.sender;
    }

    function create(string memory name_, string memory symbol_) external onlySwiftGate returns (address proxy_) {
        proxy_ = Clones.cloneDeterministic(_implementation, keccak256(abi.encodePacked(name_, symbol_)));
        ERC20Token(proxy_).initialize(name_, symbol_, msg.sender);
    }

    function getImplementation() external view returns (address) {
        return _implementation;
    }
}