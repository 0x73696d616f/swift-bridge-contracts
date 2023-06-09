// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ERC20Upgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol"; 

contract ERC20Token is ERC20Upgradeable {
    address internal _swiftGate;

    error OnlySwiftGateError(address msgSender_);

    modifier onlySwiftGate() {
        if(msg.sender != _swiftGate) revert OnlySwiftGateError(msg.sender);
        _;
    }

    function initialize(string memory name_, string memory symbol_, address swiftGate_) initializer public {
        _swiftGate = swiftGate_;
        __ERC20_init(name_, symbol_);
    }

    function mint(address account_, uint256 amount_) external onlySwiftGate {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlySwiftGate {
        _burn(account_, amount_);
    }

    function getSwiftGate() external view returns (address) {
        return _swiftGate;
    }
}