// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { TokenFactory } from "./TokenFactory.sol";

contract SwiftGate {
    uint256 internal immutable _chainId;
    mapping(address => bool) internal _governors;
    mapping(uint256 => uint256) internal _feeOfChainId;
    mapping(uint256 => uint256) internal _feeIfBatchedOfChainId;
    mapping(uint256 => mapping(address => address)) internal _tokens;
    TokenFactory internal immutable _tokenFactory;
    uint256 internal _minSignatures;

    error LengthMismatchError();
    error NotEnoughSignaturesError();
    error InvalidSignatureError();

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(uint16 chainId_, address[] memory governors_, uint256 minSignatures_) {
        _chainId = chainId_;
        _tokenFactory = new TokenFactory();
        _minSignatures = minSignatures_;
        for(uint i_; i_ < governors_.length;) {
            _governors[governors_[i_]] = true;
        }
    }
 
    function swiftReceive(
        address[] calldata token_, 
        uint256[] calldata amount_, 
        address[] calldata receiver_, 
        uint16[] calldata srcChain_,
        uint16[] calldata dstChain_, 
        Signature[] calldata signatures_
    ) external {}

    function swiftSend(address token_, uint256 amount_, address receiver_, uint16 dstChain_, bool isSingle_) public {}

    function swiftSign(
        address[] calldata token_, 
        uint256[] calldata amount_, 
        address[] calldata receiver_, 
        uint16[] calldata srcChain_,
        uint16[] calldata dstChain_, 
        Signature[] calldata signatures_
    ) external {}

    function addToken(uint16 chainId_, address token_, string memory name_, string memory symbol_, Signature[] calldata signatures_) external {
        _verifySignatures(keccak256(abi.encodePacked(_chainId, chainId_, token_, name_, symbol_)), signatures_);
        _tokens[chainId_][token_] = _tokenFactory.create(name_, symbol_);
    }

    ////////////////////////////// Setters ///////////////////////////////////////////////

    function setFeeOfChainId(uint16 chainId_, uint256 fee_, Signature[] calldata signatures_) external {
        _verifySignatures(keccak256(abi.encodePacked(_chainId, chainId_, fee_)), signatures_);
        _feeOfChainId[chainId_] = fee_;
    }

    function setFeeIfBatchedOfChainId(uint16 chainId_, uint256 feeIfBatched_, Signature[] calldata signatures_) external {
        _verifySignatures(keccak256(abi.encodePacked(_chainId, chainId_, feeIfBatched_)), signatures_);
        _feeIfBatchedOfChainId[chainId_] = feeIfBatched_;
    }

    function setGovernors(address[] calldata governors_, bool[] calldata set_, Signature[] calldata signatures_) external {
        if (governors_.length != set_.length || set_.length != signatures_.length) revert LengthMismatchError();
        _verifySignatures(keccak256(abi.encodePacked(_chainId, governors_, set_)), signatures_);
        
        for (uint i_; i_ < governors_.length;) {
            _governors[governors_[i_]] = set_[i_];
            unchecked {
                ++i_;
            }
        }
    }

    function setMinSignatures(uint256 minSignatures_, Signature[] calldata signatures_) external {
        _verifySignatures(keccak256(abi.encodePacked(_chainId, minSignatures_)), signatures_);
        _minSignatures = minSignatures_;
    }

    ////////////////////////////// Getters ///////////////////////////////////////////////

    function getFeeOfChainId(uint16 chainId_) external view returns (uint256) {
        return _feeOfChainId[chainId_];
    }

    function getFeeIfBatchedOfChainId(uint16 chainId_) external view returns (uint256) {
        return _feeIfBatchedOfChainId[chainId_];
    }

    function getChainId() external view returns (uint256) {
        return _chainId;
    }

    function isGovernor(address account_) external view returns (bool) {
        return _governors[account_];
    }

    function getToken(uint16 chainId_, address token_) external view returns (address) {
        return _tokens[chainId_][token_];
    }

    function getTokenFactory() external view returns (address) {
        return address(_tokenFactory);
    }

    ////////////////////////////// Internal ///////////////////////////////////////////////

    function _verifySignatures(bytes32 messageHash_, Signature[] calldata signatures_) internal view {
        if (signatures_.length < _minSignatures) revert NotEnoughSignaturesError();
        for(uint i_; i_ < signatures_.length;) {
            address signer_ = ecrecover(messageHash_, signatures_[i_].v, signatures_[i_].r, signatures_[i_].s); 
            if (!_governors[signer_]) revert InvalidSignatureError();
            unchecked {
                ++i_;
            }
        }
    }
}
