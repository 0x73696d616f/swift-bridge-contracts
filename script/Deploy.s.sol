// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import { Helpers } from "../common/Helpers.sol";

import { MintableERC20 } from "../common/MintableERC20.sol";

import { SwiftGate } from "../src/SwiftGate.sol";

contract DeployScript is Script {
    address[] public governors;
    uint256[] public governorPKs;
    uint256 public constant MIN_SIGATURES = 13;
    SwiftGate swiftGateEthereum_;
    SwiftGate swiftGateOptimism_;
    uint16 public constant SCROLL_CHAIN_ID = 1;
    uint16 public constant OPTIMISM_CHAIN_ID = 2;
    address public constant wrappedETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant wrappedETHOptimism = 0x4200000000000000000000000000000000000006;
    address public constant SWIFT_GATE = 0x7374Da744DD2b54e50b933692f471B6395023B12;
    
    function setUp() public {
        for (uint i_ = 11; i_ < MIN_SIGATURES + 11; i_++) {
            governorPKs.push(i_);
            governors.push(vm.addr(i_));
        }
        vm.label(wrappedETH, "wrappedETH");
        vm.label(wrappedETHOptimism, "wrappedETHOptimism");
    }

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY_ANVIL"));
        uint16 chainId_ = OPTIMISM_CHAIN_ID;
        uint16 remoteChainId_ = SCROLL_CHAIN_ID;

        //_deploy(chainId_, remoteChainId_);

        address wrappedToken_ = SwiftGate(SWIFT_GATE).getWrappedToken(OPTIMISM_CHAIN_ID, 0xaB1Ef4C5390fE153550F490282fb95871078C52c);
        console.log(MintableERC20(wrappedToken_).balanceOf(0x81B14fEa9FBf83937b97bA0F7Ef8383Cd10236F7));

        //_receive(0xaB1Ef4C5390fE153550F490282fb95871078C52c, 100, vm.addr(vm.envUint("PRIVATE_KEY_ANVIL")), remoteChainId_, chainId_, keccak256("1"));
        //_send(0xaB1Ef4C5390fE153550F490282fb95871078C52c, 100, 0x81B14fEa9FBf83937b97bA0F7Ef8383Cd10236F7, remoteChainId_);
        //Helpers._addWrappedToken(SWIFT_GATE, chainId_, remoteChainId_, 0xd36e5a69D4d002f52056201DcC836e29c077E408, "Wrapped SCROLL TOKEN", "WST", governorPKs, keccak256("3"));
        vm.stopBroadcast();
    }

    function _send(address token_, uint256 amount_, address to_, uint16 remoteChainId_) internal {
        MintableERC20(token_).approve(SWIFT_GATE, amount_);
        SwiftGate(SWIFT_GATE).swiftSend(token_, amount_, to_, remoteChainId_, true);
    }

    struct SwReceiveParams {
        address token;
        uint256 amount;
        address receiver;
        uint16 srcChain;
        uint16 dstChain;
    }

    function _receive(address token_, uint256 amount_, address receiver_, uint16 sourceChainId_, uint16 remoteChainId_, bytes32 salt_) internal {
        SwiftGate.SwReceiveParams[] memory params_ = new SwiftGate.SwReceiveParams[](1);
        params_[0] = SwiftGate.SwReceiveParams(token_, amount_, receiver_, sourceChainId_, remoteChainId_);

        bytes32 messageHash_ = salt_;
        for (uint i_ = 0; i_ < params_.length; i_++) {
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
        }

        console.log("salt", vm.toString(salt_));
        console.log("messageHash", vm.toString(messageHash_));

        SwiftGate(SWIFT_GATE).swiftReceive(params_, Helpers._getSignatures(messageHash_, governorPKs), salt_);
    }

    function _deploy(uint16 chainId_, uint16 remoteChainId_) internal {
        SwiftGate swiftGate_ =  Helpers._deploySwiftGate(chainId_, governors, MIN_SIGATURES, address(0), address(0));
        address token_ = address(new MintableERC20{salt: keccak256(abi.encodePacked(chainId_))}());

        console.log("swiftGate", address(swiftGate_));
        console.log("token", token_);
        
        Helpers._addDstToken(address(swiftGate_), chainId_, remoteChainId_, token_, governorPKs, keccak256("1"));
    }
}
