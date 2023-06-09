# SwiftGate
[Git Source](https://github.com/0x73696d616f/swift-gate-contracts/blob/c2f63902e1326587b99cc4130505b65fba901d42/src/SwiftGate.sol)


## State Variables
### _chainId

```solidity
uint16 internal _chainId;
```


### _aaveV3LendingPool

```solidity
IPool internal _aaveV3LendingPool;
```


### _aaveV3RewardsController

```solidity
IRewardsController internal _aaveV3RewardsController;
```


### _governors

```solidity
mapping(address => bool) internal _governors;
```


### _feeOfChainId

```solidity
mapping(uint256 => uint256) internal _feeOfChainId;
```


### _feeIfBatchedOfChainId

```solidity
mapping(uint256 => uint256) internal _feeIfBatchedOfChainId;
```


### _signedMessages

```solidity
mapping(bytes32 => bool) internal _signedMessages;
```


### _remoteToWrappedTokens
Mapping of chainId => destination token => wrappedToken


```solidity
mapping(uint256 => mapping(address => address)) internal _remoteToWrappedTokens;
```


### _wrappedToRemoteTokens
Mapping of token to wrapped token


```solidity
mapping(address => address) internal _wrappedToRemoteTokens;
```


### _dstTokens
Mapping of chainId => local token => is supported token


```solidity
mapping(uint256 => mapping(address => bool)) internal _dstTokens;
```


### _tokenFactory
Factory for creating wrapped tokens


```solidity
TokenFactory internal immutable _tokenFactory;
```


### _minSignatures
Minimum signatures to validate messages


```solidity
uint256 internal _minSignatures;
```


## Functions
### constructor


```solidity
constructor(address[] memory governors_, uint256 minSignatures_);
```

### initialize


```solidity
function initialize(uint16 chainId_, address aaveV3, address aaveV3RewardsController_) external;
```

### swiftReceive

Receives a batch of tokens, mints the wrapped versions and verifies the signatures.


```solidity
function swiftReceive(SwReceiveParams[] calldata params_, Signature[] calldata signatures_, bytes32 salt_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SwReceiveParams[]`|Struct with the parameters to sned across bridges - includes token, amount, receiver, srcChain, dstChain|
|`signatures_`|`Signature[]`|Array of signatures from the governors (message hash signed by governors )|
|`salt_`|`bytes32`|Message Hash|


### swiftSend

Sends a token to another chain.


```solidity
function swiftSend(address token_, uint256 amount_, address receiver_, uint16 dstChain_, bool isSingle_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token_`|`address`|The token to send.|
|`amount_`|`uint256`|The amount of tokens to send.|
|`receiver_`|`address`|The receiver of the tokens.|
|`dstChain_`|`uint16`|The destination chain.|
|`isSingle_`|`bool`|Whether the token is to be batched with other tokens to save gas or not.|


### addWrappedToken

Adds a wrapped token to the respective mapping so it can be used across chains


```solidity
function addWrappedToken(
    uint16 chainId_,
    address token_,
    string memory name_,
    string memory symbol_,
    Signature[] calldata signatures_,
    bytes32 salt_
) external;
```

### addDstToken

Adds a token to the dstTokens mapping (verified with the signatures)


```solidity
function addDstToken(uint16 chainId_, address token_, Signature[] calldata signatures_, bytes32 salt_) external;
```

### depositToAaveV3

Approves a given token so it can be handled in aave lending pool


```solidity
function depositToAaveV3(address token_, uint256 amount_, Signature[] calldata signatures_, bytes32 salt_) external;
```

### withdrawFromAaveV3

Claims rewards from aave (that will then be distributed to the governors)


```solidity
function withdrawFromAaveV3(
    address token_,
    address aToken_,
    uint256 amount_,
    Signature[] calldata signatures_,
    bytes32 salt_
) external;
```

### setFeeOfChainId


```solidity
function setFeeOfChainId(uint16 chainId_, uint256 fee_, Signature[] calldata signatures_, bytes32 salt_) external;
```

### setFeeIfBatchedOfChainId


```solidity
function setFeeIfBatchedOfChainId(
    uint16 chainId_,
    uint256 feeIfBatched_,
    Signature[] calldata signatures_,
    bytes32 salt_
) external;
```

### setGovernors


```solidity
function setGovernors(
    address[] calldata governors_,
    bool[] calldata set_,
    Signature[] calldata signatures_,
    bytes32 salt_
) external;
```

### setMinSignatures


```solidity
function setMinSignatures(uint256 minSignatures_, Signature[] calldata signatures_, bytes32 salt_) external;
```

### getFeeOfChainId


```solidity
function getFeeOfChainId(uint16 chainId_) external view returns (uint256);
```

### getFeeIfBatchedOfChainId


```solidity
function getFeeIfBatchedOfChainId(uint16 chainId_) external view returns (uint256);
```

### getChainId


```solidity
function getChainId() external view returns (uint256);
```

### isGovernor


```solidity
function isGovernor(address account_) external view returns (bool);
```

### getWrappedToken


```solidity
function getWrappedToken(uint16 chainId_, address token_) external view returns (address);
```

### getTokenFactory


```solidity
function getTokenFactory() external view returns (address);
```

### getRemoteTokenOf


```solidity
function getRemoteTokenOf(address wrappedToken_) external view returns (address);
```

### isDstToken


```solidity
function isDstToken(uint16 chainId_, address token_) external view returns (bool);
```

### getMinSignatures


```solidity
function getMinSignatures() external view returns (uint256);
```

### getAaveV3LendingPool


```solidity
function getAaveV3LendingPool() external view returns (address);
```

### _verifySignatures


```solidity
function _verifySignatures(bytes32 messageHash_, Signature[] calldata signatures_) internal;
```

## Events
### SwiftSend

```solidity
event SwiftSend(address token, uint256 amount, address receiver, uint16 dstChain, bool isSingle);
```

## Errors
### LengthMismatchError

```solidity
error LengthMismatchError();
```

### NotEnoughSignaturesError

```solidity
error NotEnoughSignaturesError();
```

### InvalidSignatureError

```solidity
error InvalidSignatureError();
```

### WrontDstChainError

```solidity
error WrontDstChainError(uint256 chainId);
```

### UnsupportedTokenError

```solidity
error UnsupportedTokenError(uint16 chainId, address token);
```

### ZeroAddressError

```solidity
error ZeroAddressError();
```

### ZeroAmountError

```solidity
error ZeroAmountError();
```

### ChainIdAlreadySetError

```solidity
error ChainIdAlreadySetError();
```

### DuplicateSignatureError

```solidity
error DuplicateSignatureError();
```

## Structs
### Signature

```solidity
struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}
```

### SwReceiveParams

```solidity
struct SwReceiveParams {
    address token;
    uint256 amount;
    address receiver;
    uint16 srcChain;
    uint16 dstChain;
}
```

