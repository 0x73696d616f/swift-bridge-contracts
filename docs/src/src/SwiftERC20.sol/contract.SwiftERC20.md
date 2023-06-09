# SwiftERC20
[Git Source](https://github.com/0x73696d616f/swift-gate-contracts/blob/c2f63902e1326587b99cc4130505b65fba901d42/src/SwiftERC20.sol)

**Inherits:**
ERC20Upgradeable


## State Variables
### _swiftGate

```solidity
address internal _swiftGate;
```


### _remoteToken

```solidity
address internal _remoteToken;
```


## Functions
### onlySwiftGate


```solidity
modifier onlySwiftGate();
```

### initialize


```solidity
function initialize(string memory name_, string memory symbol_, address swiftGate_, address remoteToken_)
    public
    initializer;
```

### mint


```solidity
function mint(address account_, uint256 amount_) external onlySwiftGate;
```

### burn


```solidity
function burn(address account_, uint256 amount_) external onlySwiftGate;
```

### getSwiftGate


```solidity
function getSwiftGate() external view returns (address);
```

### getRemoteToken


```solidity
function getRemoteToken() external view returns (address);
```

## Errors
### OnlySwiftGateError

```solidity
error OnlySwiftGateError(address msgSender_);
```

