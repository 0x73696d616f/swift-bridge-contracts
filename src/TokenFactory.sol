// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Clones } from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol"; 
import { SwiftERC20 } from "./SwiftERC20.sol";

contract TokenFactory {
    address internal immutable _implementation;
    address internal immutable _swiftGate;

    error OnlySwiftGateError(address msgSender_);

    modifier onlySwiftGate() {
        if(msg.sender != _swiftGate) revert OnlySwiftGateError(msg.sender);
        _;
    } 

    constructor() {
        _implementation = address(new SwiftERC20());
        _swiftGate = msg.sender;
    }

    function create(string memory name_, string memory symbol_, address remoteToken_) external onlySwiftGate returns (address proxy_) {
        proxy_ = Clones.clone(_implementation);
        SwiftERC20(proxy_).initialize(name_, symbol_, msg.sender, remoteToken_);
    }

    function getImplementation() external view returns (address) {
        return _implementation;
    }
}