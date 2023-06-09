# TokenFactory
[Git Source](https://github.com/0x73696d616f/swift-gate-contracts/blob/c2f63902e1326587b99cc4130505b65fba901d42/src/TokenFactory.sol)


## State Variables
### _implementation

```solidity
address internal immutable _implementation;
```


### _swiftGate

```solidity
address internal immutable _swiftGate;
```


## Functions
### onlySwiftGate


```solidity
modifier onlySwiftGate();
```

### constructor


```solidity
constructor();
```

### create


```solidity
function create(string memory name_, string memory symbol_, address remoteToken_)
    external
    onlySwiftGate
    returns (address proxy_);
```

### getImplementation


```solidity
function getImplementation() external view returns (address);
```

## Errors
### OnlySwiftGateError

```solidity
error OnlySwiftGateError(address msgSender_);
```

