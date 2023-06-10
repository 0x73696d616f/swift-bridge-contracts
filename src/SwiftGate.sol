// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { TokenFactory } from "./TokenFactory.sol";
import { SwiftERC20 } from "./SwiftERC20.sol";
import { IPool } from "lib/aave-v3-core/contracts/interfaces/IPool.sol";
import { IRewardsController } from 'lib/aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';

import "forge-std/Test.sol";

contract SwiftGate {
    /**
     * @notice Struct to hold signature data
     * @param v v of the signature
     * @param r r of the signature
     * @param s s of the signature
     */
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @notice Struct to hold swift receive parameters
     * @param token token to receive
     * @param amount amount of tokens to receive
     * @param receiver receiver of the tokens
     * @param srcChain source chain of the tokens
     * @param dstChain destination chain of the tokens
     */
    struct SwReceiveParams {
        address token;
        uint256 amount;
        address receiver;
        uint16 srcChain;
        uint16 dstChain;
    }

    /// @notice chain id of swift gate on this chain
    uint16 internal _chainId;

    /// @notice Aave v3 lending pool
    IPool internal _aaveV3LendingPool;

    /// @notice Aave v3 rewards controller
    IRewardsController internal _aaveV3RewardsController;

    /// @notice Mapping of governor address => is governor
    mapping(address => bool) internal _governors;

    /// @notice Mapping of chainId => fee
    mapping(uint256 => uint256) internal _feeOfChainId;

    /// @notice Mapping of chainId => fee if batched
    mapping(uint256 => uint256) internal _feeIfBatchedOfChainId;

    /// @notice Mapping of chainId => is chain supported
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

    /// @notice triggered when the lengths of the array arguments don't match
    error LengthMismatchError();

    /// @notice triggered when the number of signatures is less than the minimum
    error NotEnoughSignaturesError();

    /// @notice triggered when the signature is invalid
    error InvalidSignatureError();

    /* 
     * @notice triggered when the destination chain received does not match this chain id
     *         prevents message replay
     * @param chainId chain id of the message
     */
    error WrontDstChainError(uint256 chainId);

    /**
     * @notice triggered when the token is not supported on a certain destination chain
     * @param chainId chain id of the message
     * @param token token that is not supported
     */
    error UnsupportedTokenError(uint16 chainId, address token);

    /// @notice triggered on a zero address argument
    error ZeroAddressError();

    /// @notice triggered when the amount is zero
    error ZeroAmountError();

    /// @notice triggered when the chain id is already set. Prevents reinitialization
    error ChainIdAlreadySetError();

    /// @notice triggered when the signature is a duplicate. Prevents message replay
    error DuplicateSignatureError();

    /**
     * @notice emitted when an account calls swiftSend and bridges to the destination chain
     * @param token token that is being sent
     * @param remoteToken_ the address of the token on the destination chain, if the token being sent is wrapped
     * @param amount amount of tokens to send
     * @param receiver receiver of the tokens on the destination chain
     * @param dstChain destination chain of the tokens
     * @param isSingle whether the swiftSend is a single or batched swiftSend to be processed by the backend
     */
    event SwiftSend(address token, address remoteToken_, uint256 amount, address receiver, uint16 dstChain, bool isSingle);

    /// @notice creates the TokenFactory which is owner by this contract - swift gate
    constructor() {
        _tokenFactory = new TokenFactory();
    }

    /**
     * @notice initializes the swift gate contract
     * @param chainId_ chain id of the swift gate contract
     * @param aaveV3 aave v3 lending pool address
     * @param aaveV3RewardsController_ aave v3 rewards controller address
     * @param governors_ array of governor addresses
     * @param minSignatures_ minimum number of signatures to validate messages
     */
    function initialize(uint16 chainId_, address aaveV3, address aaveV3RewardsController_, address[] memory governors_, uint256 minSignatures_) external {
        if (_chainId != 0) revert ChainIdAlreadySetError();
        _chainId = chainId_;
        _aaveV3LendingPool = IPool(aaveV3);
        _aaveV3RewardsController = IRewardsController(aaveV3RewardsController_);
        _minSignatures = minSignatures_;
        for(uint i_; i_ < governors_.length;) {
            _governors[governors_[i_]] = true;

            unchecked {
                ++i_;
            }
        }
    }

 
    /** 
     * @notice receives a batch of tokens, mints the wrapped versions and verifies the signatures.
     * @param params_ struct with the parameters to sned across bridges - includes token, amount, receiver, srcChain, dstChain
     * @param signatures_ array of signatures from the governors (message hash signed by governors )
     * @param salt_ salt used to enable signing the same message more than once
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
     *  @notice sends a token to another chain.
     *  @param token_ the token to send.
     *  @param amount_ the amount of tokens to send.
     *  @param receiver_ the receiver of the tokens.
     *  @param dstChain_ the destination chain.
     *  @param isSingle_ whether the token is to be batched with other tokens to save gas or not.
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

        emit SwiftSend(token_, remoteToken_, amount_, receiver_, dstChain_, isSingle_);
    }   

    /** 
     * @notice adds a wrapped token to the respective mapping so it can be used across chains
     * @param chainId_ chain id of the wrapped token
     * @param token_ token that is being wrapped
     * @param name_ name of the wrapped token
     * @param symbol_ symbol of the wrapped token
     * @param signatures_ array of signatures from the governors (message hash signed by governors )
     * @param salt_ salt used to enable signing the same message more than once
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
     * @notice Adds a token to the dstTokens mapping (verified with the signatures). Signals that a token can be bridged to another chain
     * @param chainId_ chain id of the token
     * @param token_ token that is being added
     * @param signatures_ array of signatures from the governors (message hash signed by governors )
     * @param salt_ salt used to enable signing the same message more than once
     */
    function addDstToken(uint16 chainId_, address token_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, chainId_, token_)), signatures_);
        _dstTokens[chainId_][token_] = true;
    }

    /** 
     * @notice deposits a given token in the aave lending pool
     * @param token_ token to be deposited
     * @param amount_ amount to be deposited
     * @param signatures_ array of signatures from the governors (message hash signed by governors )
     * @param salt_ salt used to enable signing the same message more than once
     */
    function depositToAaveV3(address token_, uint256 amount_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, token_, amount_)), signatures_);
        SwiftERC20(token_).approve(address(_aaveV3LendingPool), amount_);
        _aaveV3LendingPool.supply(token_, amount_, address(this), 0);
    }

    /** 
     * @notice withdraws tokens and rewards from aave to claim the yield for the governors
     * @param token_ token to be withdrawn
     * @param aToken_ corresponding aave token. Required for the rewards controller
     * @param amount_ amount to be withdrawn
     * @param receiver_ address to receive the tokens
     * @param signatures_ array of signatures from the governors (message hash signed by governors )
     * @param salt_ salt used to enable signing the same message more than once
     */
    function withdrawFromAaveV3(address token_, address aToken_, uint256 amount_, address receiver_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, token_, amount_, receiver_)), signatures_);
        _aaveV3LendingPool.withdraw(token_, amount_, receiver_);
        address[] memory aTokens_ = new address[](1);
        aTokens_[0] = aToken_;
        _aaveV3RewardsController.claimAllRewards(aTokens_, receiver_);
    }

    ////////////////////////////// Setters ///////////////////////////////////////////////

    /**
     * @notice sets the fee for a given chain id
     * @param chainId_ chain id to set the fee for
     * @param fee_ fee to be set
     * @param signatures_ array of signatures from the governors (message hash signed by governors )
     * @param salt_ salt used to enable signing the same message more than once
     */
    function setFeeOfChainId(uint16 chainId_, uint256 fee_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, chainId_, fee_)), signatures_);
        _feeOfChainId[chainId_] = fee_;
    }

    /**
     * @notice sets the fee if the swiftSend call is batched for a given chain id. Much cheaper than single fee
     * @param chainId_ chain id to set the fee for
     * @param feeIfBatched_ fee to be set
     * @param signatures_ array of signatures from the governors (message hash signed by governors )
     * @param salt_ salt used to enable signing the same message more than once
     */
    function setFeeIfBatchedOfChainId(uint16 chainId_, uint256 feeIfBatched_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, chainId_, feeIfBatched_)), signatures_);
        _feeIfBatchedOfChainId[chainId_] = feeIfBatched_;
    }

    /**
     * @notice sets the governors of the swift gate. Useful if governors are not working well and need to be replaced
     * @param governors_ array of governors to be set
     * @param set_ array of booleans to set the governors to true or false
     * @param signatures_ array of signatures from the governors (message hash signed by governors )
     * @param salt_ salt used to enable signing the same message more than once
     */
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

    /**
     * @notice sets the min signatures required to execute calls to the swift gate
     * @param minSignatures_ min signatures to be set
     * @param signatures_ array of signatures from the governors (message hash signed by governors )
     * @param salt_ salt used to enable signing the same message more than once
     */
    function setMinSignatures(uint256 minSignatures_, Signature[] calldata signatures_, bytes32 salt_) external {
        _verifySignatures(keccak256(abi.encodePacked(salt_, _chainId, minSignatures_)), signatures_);
        _minSignatures = minSignatures_;
    }

    ////////////////////////////// Getters ///////////////////////////////////////////////

    /**
     * @notice gets the single swift send fee of to a given chain id
     * @param chainId_ chain id to get the fee for
     */
    function getFeeOfChainId(uint16 chainId_) external view returns (uint256) {
        return _feeOfChainId[chainId_];
    }

    /**
     * @notice gets the batched swift send fee of to a given chain id
     * @param chainId_ chain id to get the fee for
     */
    function getFeeIfBatchedOfChainId(uint16 chainId_) external view returns (uint256) {
        return _feeIfBatchedOfChainId[chainId_];
    }

    /**
     * @notice gets the chain id of the swift gate
     */
    function getChainId() external view returns (uint256) {
        return _chainId;
    }

    /**
     * @notice checks if an account is a governor
     * @param account_ account to check
     * @return true if the account is a governor, false otherwise
     */
    function isGovernor(address account_) external view returns (bool) {
        return _governors[account_];
    }

    /**
     * @notice gets the wrapped token of a given chain id and token address
     * @param chainId_ chain id to get the wrapped token for
     * @param token_ token to get the wrapped token for
     * @return wrapped token address
     */
    function getWrappedToken(uint16 chainId_, address token_) external view returns (address) {
        return _remoteToWrappedTokens[chainId_][token_];
    }

    /**
     * @notice gets the token factory address that creates the wrapped tokens
     * @return token factory address
     */
    function getTokenFactory() external view returns (address) {
        return address(_tokenFactory);
    }

    /**
     * @notice gets the remote token of a given wrapped token address
     * @param wrappedToken_ wrapped token to get the remote token for
     * @return remote token address
     */
    function getRemoteTokenOf(address wrappedToken_) external view returns (address) {
        return _wrappedToRemoteTokens[wrappedToken_];
    }

    /**
     * @notice checks if a token is allowed to be bridged to a destination chain id
     * @param chainId_ chain id to check
     * @param token_ token to check
     * @return true if the token is allowed to be bridged, false otherwise
     */
    function isDstToken(uint16 chainId_, address token_) external view returns (bool) {
        return _dstTokens[chainId_][token_];
    }

    /**
     * @notice gets the min signatures required to execute calls to the swift gate
     */
    function getMinSignatures() external view returns (uint256) {
        return _minSignatures;
    }

    /**
     * @notice gets the aave v3 lending pool address
     */
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
