// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ERC20Upgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol"; 

contract SwiftERC20 is ERC20Upgradeable {
    /// @notice address of the swift gate contract
    address internal _swiftGate;

    /// @notice address of the remote token contract
    address internal _remoteToken;

    /// @notice triggered when an address other than the swift gate calls this contract
    /// @param msgSender_ the caller of the function
    error OnlySwiftGateError(address msgSender_);

    /// @notice can only be called by swift gate
    modifier onlySwiftGate() {
        if(msg.sender != _swiftGate) revert OnlySwiftGateError(msg.sender);
        _;
    }

    /**
     * @notice initialize the contract
     * @param name_ name of the wrapped token
     * @param symbol_ symbol of the wrapped token
     * @param swiftGate_  address of the swift gate contract
     * @param remoteToken_  address of the remote token contract
     */
    function initialize(string memory name_, string memory symbol_, address swiftGate_, address remoteToken_) initializer public {
        _swiftGate = swiftGate_;
        __ERC20_init(name_, symbol_);
        _remoteToken = remoteToken_;
    }

    /**
     * @notice swift gate mints tokens
     * @param account_ address to mint tokens to
     * @param amount_ amount of tokens to mint
     */
    function mint(address account_, uint256 amount_) external onlySwiftGate {
        _mint(account_, amount_);
    }

    /**
     * @notice swift gate burns tokens
     * @param account_ address to burn tokens from
     * @param amount_ amount of tokens to burn
     */
    function burn(address account_, uint256 amount_) external onlySwiftGate {
        _burn(account_, amount_);
    }

    /// @notice returns the address of the swift gate
    function getSwiftGate() external view returns (address) {
        return _swiftGate;
    }

    /// @notice returns the address of the remote token
    function getRemoteToken() external view returns (address) {
        return _remoteToken;
    }
}