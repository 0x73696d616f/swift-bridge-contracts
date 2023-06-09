// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import "../src/SwiftGate.sol";

contract SwiftGateTest is Test {
    address[] public governors;
    uint256[] public governorPKs;
    uint256 public constant MIN_SIGATURES = 13;
    SwiftGate swiftGateEthereum_;
    SwiftGate swiftGateOptimism_;
    uint16 public constant ETHEREUM_CHAIN_ID = 1;
    uint16 public constant OPTIMISM_CHAIN_ID = 2;
    address public wrappedETH;
    address public wrappedETHOptimism;

    function setUp() public {
        for (uint i_ = 11; i_ < MIN_SIGATURES + 11; i_++) {
            governorPKs.push(i_);
            vm.label(vm.addr(i_), string(abi.encodePacked("governor", vm.toString(i_ - 10))));
            governors.push(vm.addr(i_));
        }
        
        swiftGateEthereum_ = new SwiftGate(ETHEREUM_CHAIN_ID, governors, MIN_SIGATURES);
        swiftGateOptimism_ = new SwiftGate(OPTIMISM_CHAIN_ID, governors, MIN_SIGATURES);

        wrappedETH = address(new ERC20("Wrapped ETH", "WETH"));
        wrappedETHOptimism = address(new ERC20("Wrapped ETH OPTIMISM", "WETHOP"));

        _addWrappedToken(address(swiftGateOptimism_), OPTIMISM_CHAIN_ID, ETHEREUM_CHAIN_ID, address(wrappedETH), "Swift Gate Wrapped ETH", "SGWETH");
        _addWrappedToken(address(swiftGateEthereum_), ETHEREUM_CHAIN_ID, OPTIMISM_CHAIN_ID, address(wrappedETHOptimism), "Swift Gate Wrapped ETH OPTIMISM", "SGWETHOP");
    
        _addDstToken(address(swiftGateEthereum_), ETHEREUM_CHAIN_ID, OPTIMISM_CHAIN_ID, address(wrappedETH));
        _addDstToken(address(swiftGateOptimism_), OPTIMISM_CHAIN_ID, ETHEREUM_CHAIN_ID, address(wrappedETHOptimism));
    }

    function testSwiftSendFromEthereumToOptimism() public {
        address sender_ = makeAddr("sender");
        address receiver_ = makeAddr("receiver");
        uint256 amount_ = 100;

        vm.startPrank(sender_);
        deal(wrappedETH, sender_, amount_);
        ERC20(wrappedETH).approve(address(swiftGateEthereum_), amount_);
        uint256 initialGas_ = gasleft();
        swiftGateEthereum_.swiftSend(address(wrappedETH), amount_, receiver_, OPTIMISM_CHAIN_ID, true);
        console.log("Gas used swift Send", initialGas_ - gasleft());
        vm.stopPrank();

        assertEq(ERC20(wrappedETH).balanceOf(address(swiftGateEthereum_)), amount_);
        assertEq(ERC20(wrappedETH).balanceOf(sender_), 0);

        SwiftGate.SwReceiveParams[] memory params_ = new SwiftGate.SwReceiveParams[](1);
        params_[0].token = address(wrappedETH);
        params_[0].receiver = receiver_;
        params_[0].amount = amount_;
        params_[0].srcChain = ETHEREUM_CHAIN_ID;
        params_[0].dstChain = OPTIMISM_CHAIN_ID;

        _swiftReceive(address(swiftGateOptimism_), params_);

        ERC20 wrappedETHOnOptimism_ = ERC20(swiftGateOptimism_.getWrappedToken(ETHEREUM_CHAIN_ID, wrappedETH));

        assertEq(wrappedETHOnOptimism_.balanceOf(receiver_), amount_);
    }

    function testBatchSwiftSendFromEthereumToOptimism() public {
        uint256 amount_ = 100;
        uint256 batchSize_ = 20;
        SwiftGate.SwReceiveParams[] memory params_ = new SwiftGate.SwReceiveParams[](batchSize_);

        for (uint i_ = 1; i_ <= batchSize_; i_++) {
            address sender_ = makeAddr(string(abi.encodePacked("sender", vm.toString(i_))));
            address receiver_ = makeAddr(string(abi.encodePacked("receiver", vm.toString(i_))));
            params_[i_ - 1].token = address(wrappedETH);
            params_[i_ - 1].receiver = receiver_;
            params_[i_ - 1].amount = amount_;
            params_[i_ - 1].srcChain = ETHEREUM_CHAIN_ID;
            params_[i_ - 1].dstChain = OPTIMISM_CHAIN_ID;

            uint256 initialBalance_ = ERC20(wrappedETH).balanceOf(address(swiftGateEthereum_));
            
            vm.startPrank(sender_);
            deal(wrappedETH, sender_, amount_);
            ERC20(wrappedETH).approve(address(swiftGateEthereum_), amount_);
            swiftGateEthereum_.swiftSend(address(wrappedETH), amount_, receiver_, OPTIMISM_CHAIN_ID, true);
            vm.stopPrank();

            assertEq(ERC20(wrappedETH).balanceOf(address(swiftGateEthereum_)), initialBalance_ + amount_);
            assertEq(ERC20(wrappedETH).balanceOf(sender_), 0);
        }

        console.log("swift batch receive size", batchSize_);
        _swiftReceive(address(swiftGateOptimism_), params_);
    }

    ////////////////////////////////// Helpers ///////////////////////////////////////////////////

    function _addWrappedToken(
        address swiftGate_, 
        uint16 localChainId_, 
        uint16 remoteChainId_,
        address token_, 
        string memory name_, 
        string memory symbol_
    ) internal {
        bytes32 addWrappedTokenHash_ = keccak256(abi.encodePacked(localChainId_, remoteChainId_, token_, name_, symbol_));
        SwiftGate.Signature[] memory signatures_ = _getSignatures(addWrappedTokenHash_);
        SwiftGate(swiftGate_).addWrappedToken(remoteChainId_, token_, name_, symbol_, signatures_);
    }

    function _addDstToken(
        address swiftGate_, 
        uint16 localChainId_, 
        uint16 remoteChainId_,
        address token_
    ) internal {
        bytes32 addDstTokenHash_ = keccak256(abi.encodePacked(localChainId_, remoteChainId_, token_));
        SwiftGate.Signature[] memory signatures_ = _getSignatures(addDstTokenHash_);
        SwiftGate(swiftGate_).addDstToken(remoteChainId_, token_, signatures_);
    }

    function _swiftReceive(
        address swiftGate_,
        SwiftGate.SwReceiveParams[] memory params_
    ) internal {
        bytes32 messageHash_;
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
        SwiftGate.Signature[] memory signatures_ = _getSignatures(messageHash_);

        uint256 initialGas_ = gasleft();
        SwiftGate(swiftGate_).swiftReceive(params_, signatures_);
        console.log("swiftReceive gas cost", initialGas_ - gasleft());

        for (uint i_; i_ < params_.length; i_++) {
            ERC20 wrappedToken_ = ERC20(SwiftGate(swiftGate_).getWrappedToken(params_[i_].srcChain, params_[i_].token));
            assertEq(wrappedToken_.balanceOf(params_[i_].receiver), params_[i_].amount);
        }
    }
    
    function _getSignatures(bytes32 messageHash_) internal view returns (SwiftGate.Signature[] memory signatures_ ) {
        signatures_ = new SwiftGate.Signature[](MIN_SIGATURES);
        for (uint i_; i_ < MIN_SIGATURES; i_++) {
            (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(governorPKs[i_], messageHash_);
            signatures_[i_] = SwiftGate.Signature(v_, r_, s_);
        }
    }
}
