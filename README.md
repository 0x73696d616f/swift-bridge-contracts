# SwiftGate contracts

## Swift Gate - 0xB84f07612F4bfEc42E042b6CDD26df496b3d397f

The swift gate smart contract is responsible for bridging tokens between different blockchains. The governors whitelist tokens on a certain chain id that can be bridged to other chain ids. 

Users call `swiftSend()` to bridge tokens to other chain and specify if they want the `swiftReceive()`call on the destination chain to be batched with other users bridged tokens or not. Calling `swiftSend()` with the `isSingle_` argument to true will inccur in much bigger gas costs, but instant bridging, whereas setting this flag to false is slower but about 6 times cheaper.

The governors, each running the backend, sign a transaction specifying tokens to be received on the destination chain after users call `swiftSend()` in the source chain.

Validating 13 signatures is an expensive process and to compensate for this, swift gate leverages batching user deposits so that for a batch of bridged tokens only a message hash has to be signed. For example, for each bridged token, a regular bridge would require 2 transactions, one on the source chain and one on the destination chain, having to validate 13 signatures once. In this case, for 10 deposits, it would require 20 transactions in which the signatures are validated 10 times. However, if the bridged assets are batched, it takes 11 transactions (10 `swiftSend()` + 1 `swiftReceive()`) and the signatures are only validate once.

## Token Factory - 0xDBAF1e8f67B63a1DA2f9bB0214d6087cAA58170D

The token factory creates wrapped tokens for tokens on other blockchains. Its owner is the swift gate, from which governors can create new wrapped tokens. 

The tokens are [clones](https://docs.openzeppelin.com/contracts/4.x/api/proxy#Clones), which means that they have a common implementation as `SwiftERC20`. When a token is created on the token factory, it deploys a proxy which points to the implementation, effectively reducing gas costs significantly for the governors.

## SwiftERC20 - 0x46972365C218484d1286B6Ea08d35bD5aaa935C4

Implementation of wrapped tokens of the swift gate. Regular ERC20 token that is mintable and burnable by the swift gate. When a token not native to a blockchain is received, the receiver is minted wrapped tokens. When the user wants to bridge back the tokens, these are burned and they get the remote tokens on the original blockchain.

## Smart Contracts Architecture

![alt text](https://github.com/0x73696d616f/swift-gate-contracts/blob/master/smart-contracts-architecture.png)
[imageUrl](https://github.com/0x73696d616f/swift-gate-contracts/blob/master/smart-contracts-architecture.png)

