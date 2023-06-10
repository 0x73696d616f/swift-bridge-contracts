// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { TokenFactory } from "./TokenFactory.sol";
import { SwiftERC20 } from "./SwiftERC20.sol";
import { IPool } from "lib/aave-v3-core/contracts/interfaces/IPool.sol";
import { IRewardsController } from 'lib/aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';

import "forge-std/Test.sol";

contract SwiftGate {
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct SwReceiveParams {
        address token;
        uint256 amount;
        address receiver;
        uint16 srcChain;
        uint16 dstChain;
    }

    uint16 internal _chainId;
    IPool internal _aaveV3LendingPool;
    IRewardsController internal _aaveV3RewardsController;
    mapping(address => bool) internal _governors;
    mapping(uint256 => uint256) internal _feeOfChainId;
    mapping(uint256 => uint256) internal _feeIfBatchedOfChainId;
    mapping(bytes32 => bool) internal _signedMessages;

    /// @notice Mapping of chainId => destination token => wrappedToken
    mapping(uint256 => mapping(address => address)) internal _remoteToWrappedTokens;

    /// @notice Mapping of token to wrapped token
    mapping(address => address) internal _wrappedToRemoteTokens;

    /// @notice Mapping of chainId => local token => is supported token
    mapping(uint256 => mapping(address => bool)) internal _dstTokens;

    /// @notice Factory for creating wrapped tokens
    TokenFactory internal immutable _tokenFactory;

    /// @notice Minimum signatures to validate messages
    uint256 internal _minSignatures;

    error LengthMismatchError();
    error NotEnoughSignaturesError();
    error InvalidSignatureError();
    error WrontDstChainError(uint256 chainId);
    error UnsupportedTokenError(uint16 chainId, address token);
    error ZeroAddressError();
    error ZeroAmountError();
    error ChainIdAlreadySetError();
    error DuplicateSignatureError();

    event SwiftSend(address token, uint256 amount, address receiver, uint16 dstChain, bool isSingle);

    constructor(address[] memory governors_, uint256 minSignatures_) {
        _tokenFactory = new TokenFactory();
        _minSignatures = minSignatures_;
        for(uint i_; i_ < governors_.length;) {
            _governors[governors_[i_]] = true;

            unchecked {
                ++i_;
            }
        }
    }

    function initialize(uint16 chainId_, address aaveV3, address aaveV3RewardsController_) external {
        if (_chainId != 0) revert ChainIdAlreadySetError();
        _chainId = chainId_;
        _aaveV3LendingPool = IPool(aaveV3);
        _aaveV3RewardsController = IRewardsController(aaveV3RewardsController_);
    }

 
    /** 
     * @notice Receives a batch of tokens, mints the wrapped versions and verifies the signatures.
     *  @param params_ Struct with the parameters to sned across bridges - includes token, amount, receiver, srcChain, dstChain
     *  @param signatures_ Array of signatures from the governors (message hash signed by governors )
     *  @param salt_ Message Hash 
     */
    function swiftReceive(
        SwReceiveParams[] calldata params_,
        Signature[] calldata signatures_,
        bytes32 salt_
    ) external {
        bytes32 messageHash_ = salt_;
        for (uint i_ = 0; i_ < params_.length;) {
            if (params_[i_].dstChain != _chainId) revert WrontDstChainError(params_[i_].dstChain); // prevents message replay

            messageHash_ = keccak256(
                abi.encodePacked(
                    messageHash_, 
                    params_[i_].token, 
                    params_[i_].amount,
                    params_[i_].receiver,
                    params_[i_].srcChain, 
                    params_[i_].dstChain
                )
            );

            address wrappedToken_ = _remoteToWrappedTokens[params_[i_].srcChain][params_[i_].token];

            if (wrappedToken_ != address(0)) {
                SwiftERC20(wrappedToken_).mint(params_[i_].receiver, params_[i_].amount);
            } else {
                SwiftERC20(params_[i_].token).transfer(params_[i_].receiver, params_[i_].amount);
            }

            unchecked {
                ++i_;
            }
        }
        _verifySignatures(messageHash_, signatures_);
    }

    /** 
     *  @notice Sends a token to another chain.
     *  @param token_ The token to send.
     *  @param amount_ The amount of tokens to send.
     *  @param receiver_ The receiver of the tokens.
     *  @param dstChain_ The destination chain.
     *  @param isSingle_ Whether the token is to be batched with other tokens to save gas or not.
     */ 
    function swiftSend(address token_, uint256 amount_, address receiver_, uint16 dstChain_, bool isSingle_) external {
        if (receiver_ == address(0)) revert ZeroAddressError();
        if (amount_ == 0) revert ZeroAmountError();

        address remoteToken_ = _wrappedToRemoteTokens[token_];

        if (remoteToken_ == address(0) && !_dstTokens[dstChain_][token_]) revert UnsupportedTokenError(dstChain_, token_);

        if (remoteToken_ != address(0)) {
            SwiftERC20(token_).burn(msg.sender, amount_);
        } else {
            SwiftERC20(token_).transferFrom(msg.sender, address(this), amount_);
        }

        emit SwiftSend(token_, amount_, receiver_, dstChain_, isSingle_);
    }   

    /** 
     *  @notice Adds a wrapped token to the respective mapping so it can be used across chains
     */
    function addWrappedToken(
        uint16 chainId_, 
        address token_, 
        string memory name_, 
        string memory symbol_, 
        Signature[] calldata signatures_,
        bytes32 salt_
    ) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, chainId_, token_, name_, symbol_)), signatures_);
        address wrappedToken_ = _tokenFactory.create(name_, symbol_, token_);
        _remoteToWrappedTokens[chainId_][token_] = wrappedToken_;
        _wrappedToRemoteTokens[wrappedToken_] = token_;
    }

    /** 
     *  @notice Adds a token to the dstTokens mapping (verified with the signatures)
     */
    function addDstToken(uint16 chainId_, address token_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, chainId_, token_)), signatures_);
        _dstTokens[chainId_][token_] = true;
    }

    /** 
     *  @notice Approves a given token so it can be handled in aave lending pool
     */
    function depositToAaveV3(address token_, uint256 amount_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, token_, amount_)), signatures_);
        SwiftERC20(token_).approve(address(_aaveV3LendingPool), amount_);
        _aaveV3LendingPool.supply(token_, amount_, address(this), 0);
    }

    /** 
     *  @notice Claims rewards from aave (that will then be distributed to the governors)
     */
    function withdrawFromAaveV3(address token_, address aToken_, uint256 amount_, address receiver_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, token_, amount_, receiver_)), signatures_);
        _aaveV3LendingPool.withdraw(token_, amount_, receiver_);
        address[] memory aTokens_ = new address[](1);
        aTokens_[0] = aToken_;
        _aaveV3RewardsController.claimAllRewards(aTokens_, receiver_);
    }

    ////////////////////////////// Setters ///////////////////////////////////////////////

    function setFeeOfChainId(uint16 chainId_, uint256 fee_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, chainId_, fee_)), signatures_);
        _feeOfChainId[chainId_] = fee_;
    }

    function setFeeIfBatchedOfChainId(uint16 chainId_, uint256 feeIfBatched_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, chainId_, feeIfBatched_)), signatures_);
        _feeIfBatchedOfChainId[chainId_] = feeIfBatched_;
    }

    function setGovernors(address[] calldata governors_, bool[] calldata set_, Signature[] calldata signatures_, bytes32 salt_) external {
        if (governors_.length != set_.length || set_.length != signatures_.length) revert LengthMismatchError();
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, governors_, set_)), signatures_);
        
        for (uint i_; i_ < governors_.length;) {
            _governors[governors_[i_]] = set_[i_];
            unchecked {
                ++i_;
            }
        }
    }

    function setMinSignatures(uint256 minSignatures_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, minSignatures_)), signatures_);
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

    function getWrappedToken(uint16 chainId_, address token_) external view returns (address) {
        return _remoteToWrappedTokens[chainId_][token_];
    }

    function getTokenFactory() external view returns (address) {
        return address(_tokenFactory);
    }

    function getRemoteTokenOf(address wrappedToken_) external view returns (address) {
        return _wrappedToRemoteTokens[wrappedToken_];
    }

    function isDstToken(uint16 chainId_, address token_) external view returns (bool) {
        return _dstTokens[chainId_][token_];
    }

    function getMinSignatures() external view returns (uint256) {
        return _minSignatures;
    }

    function getAaveV3LendingPool() external view returns (address) {
        return address(_aaveV3LendingPool);
    }

    ////////////////////////////// Internal ///////////////////////////////////////////////

    function _verifySignatures(bytes32 messageHash_, Signature[] calldata signatures_) internal {
        if(_signedMessages[messageHash_]) revert DuplicateSignatureError();
        _signedMessages[messageHash_] = true;

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
