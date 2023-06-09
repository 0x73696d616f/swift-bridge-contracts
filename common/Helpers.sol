// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Vm } from "../lib/forge-std/src/Vm.sol";

import { SwiftGate } from "../src/SwiftGate.sol";

import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


library Helpers {

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _addWrappedToken(
        address swiftGate_, 
        uint16 localChainId_, 
        uint16 remoteChainId_,
        address token_, 
        string memory name_, 
        string memory symbol_,
        uint256[] memory governorPKs,
        bytes32 salt_
    ) internal {
        bytes32 addWrappedTokenHash_ = keccak256(abi.encodePacked(salt_, localChainId_, remoteChainId_, token_, name_, symbol_));
        SwiftGate.Signature[] memory signatures_ = _getSignatures(addWrappedTokenHash_, governorPKs);
        SwiftGate(swiftGate_).addWrappedToken(remoteChainId_, token_, name_, symbol_, signatures_, salt_);
    }

    function _addDstToken(
        address swiftGate_, 
        uint16 localChainId_, 
        uint16 remoteChainId_,
        address token_,
        uint256[] memory governorPKs,
        bytes32 salt_
    ) internal {
        bytes32 addDstTokenHash_ = keccak256(abi.encodePacked(salt_, localChainId_, remoteChainId_, token_));
        SwiftGate.Signature[] memory signatures_ = _getSignatures(addDstTokenHash_, governorPKs);
        SwiftGate(swiftGate_).addDstToken(remoteChainId_, token_, signatures_, salt_);
    }

    function _depositToAaveV3(
        address swiftGate_, 
        uint16 chainId_, 
        address token_, 
        uint256 amount_, 
        uint256[] memory governorPKs, 
        bytes32 salt_
    ) internal {
        bytes32 depositToAaveV3Hash_ = keccak256(abi.encodePacked(salt_, chainId_, token_, amount_));
        SwiftGate.Signature[] memory signatures_ = _getSignatures(depositToAaveV3Hash_, governorPKs);
        SwiftGate(swiftGate_).depositToAaveV3(token_, amount_, signatures_, salt_);
    }

    function _withdrawFromAaveV3(
        address swiftGate_, 
        uint16 chainId_, 
        address token_, 
        address aToken_,
        uint256 amount_, 
        uint256[] memory governorPKs, 
        bytes32 salt_
    ) internal {
        bytes32 depositToAaveV3Hash_ = keccak256(abi.encodePacked(salt_, chainId_, token_, amount_));
        SwiftGate.Signature[] memory signatures_ = _getSignatures(depositToAaveV3Hash_, governorPKs);
        SwiftGate(swiftGate_).withdrawFromAaveV3(token_, aToken_, amount_, signatures_, salt_);
    }

    function _getSignatures(
        bytes32 messageHash_, 
        uint256[] memory governorPKs
    ) internal pure returns (SwiftGate.Signature[] memory signatures_ ) {
        signatures_ = new SwiftGate.Signature[](governorPKs.length);
        for (uint i_; i_ < governorPKs.length; i_++) {
            (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(governorPKs[i_], messageHash_);
            signatures_[i_] = SwiftGate.Signature(v_, r_, s_);
        }
    }

    function _deploySwiftGate(uint16 chainId_, address[] memory governors_, uint256 minSignatures_, address aaveV3LendingPool_, address aaveV3RewardsController_) internal returns(SwiftGate) {
        SwiftGate swiftGate_ = new SwiftGate{salt: keccak256("SwiftGate")}(governors_, minSignatures_);
        swiftGate_.initialize(chainId_, aaveV3LendingPool_, aaveV3RewardsController_);
        return swiftGate_;
    }
}