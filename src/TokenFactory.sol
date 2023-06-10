// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Clones } from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol"; 
import { SwiftERC20 } from "./SwiftERC20.sol";

contract TokenFactory {
    /// @notice implementation of the swiftGate wrapped tokens
    address internal immutable _implementation;

    /// @notice address of the swift gate contract
    address internal immutable _swiftGate;

    /// @notice triggered when an address other than the swift gate calls this contract
    /// @param msgSender_ the caller of the function
    error OnlySwiftGateError(address msgSender_);

    /// @notice can only be called by swift gate
    modifier onlySwiftGate() {
        if(msg.sender != _swiftGate) revert OnlySwiftGateError(msg.sender);
        _;
    } 

    /// @notice the swift gate creates the token factory in its constructor.
    constructor() {
        _implementation = address(new SwiftERC20());
        _swiftGate = msg.sender;
    }

    /**
     * @notice create a new wrapped token. Called by the swift gate
     * @param name_ name of the wrapped token
     * @param symbol_ symbol of the wrapped token
     * @param remoteToken_  address of the remote token contract
     */
    function create(string memory name_, string memory symbol_, address remoteToken_) external onlySwiftGate returns (address proxy_) {
        proxy_ = Clones.clone(_implementation);
        SwiftERC20(proxy_).initialize(name_, symbol_, msg.sender, remoteToken_);
    }

    /// @notice returns the address of the implementation of the wrapped tokens
    function getImplementation() external view returns (address) {
        return _implementation;
    }
}