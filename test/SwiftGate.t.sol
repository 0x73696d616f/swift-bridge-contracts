// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import "../common/Helpers.sol";
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
        
        swiftGateEthereum_ = Helpers._deploySwiftGate(ETHEREUM_CHAIN_ID, governors, MIN_SIGATURES, address(0), address(0));
        vm.label(address(swiftGateEthereum_), "swiftGateEthereum");
        swiftGateOptimism_ = Helpers._deploySwiftGate(OPTIMISM_CHAIN_ID, governors, MIN_SIGATURES, address(0), address(0));
        vm.label(address(swiftGateOptimism_), "swiftGateOptimism");

        wrappedETH = address(new ERC20("Wrapped ETH", "WETH"));
        vm.label(wrappedETH, "wrappedETH");
        wrappedETHOptimism = address(new ERC20("Wrapped ETH OPTIMISM", "WETHOP"));
        vm.label(wrappedETHOptimism, "wrappedETHOptimism");

        Helpers._addWrappedToken(address(swiftGateOptimism_), OPTIMISM_CHAIN_ID, ETHEREUM_CHAIN_ID, address(wrappedETH), "Swift Gate Wrapped ETH", "SGWETH", governorPKs);
        Helpers._addWrappedToken(address(swiftGateEthereum_), ETHEREUM_CHAIN_ID, OPTIMISM_CHAIN_ID, address(wrappedETHOptimism), "Swift Gate Wrapped OPETH", "SGWOPETH", governorPKs);
    
        Helpers._addDstToken(address(swiftGateEthereum_), ETHEREUM_CHAIN_ID, OPTIMISM_CHAIN_ID, address(wrappedETH), governorPKs);
        Helpers._addDstToken(address(swiftGateOptimism_), OPTIMISM_CHAIN_ID, ETHEREUM_CHAIN_ID, address(wrappedETHOptimism), governorPKs);
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

    function testBatchSwiftSendFromEthereumToOptimismBackAndForth() public {
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
           
            deal(wrappedETH, sender_, amount_);
            _swiftSend(address(swiftGateEthereum_), sender_, address(wrappedETH), amount_, receiver_, OPTIMISM_CHAIN_ID);
        }

        console.log("swift batch receive size", batchSize_);
        _swiftReceive(address(swiftGateOptimism_), params_);

        for (uint i_ = 1; i_ <= batchSize_; i_++) {
            address sender_ = params_[i_ - 1].receiver;
            address receiver_ = makeAddr(string(abi.encodePacked("sender", vm.toString(i_)))); 
            address wrappedToken_ = swiftGateOptimism_.getWrappedToken(params_[i_ - 1].srcChain, params_[i_ - 1].token);

            _swiftSend(address(swiftGateOptimism_), sender_, wrappedToken_, amount_, receiver_, ETHEREUM_CHAIN_ID);

            params_[i_ - 1].receiver = receiver_;
            params_[i_ - 1].srcChain = OPTIMISM_CHAIN_ID;
            params_[i_ - 1].dstChain = ETHEREUM_CHAIN_ID;
        }

        console.log("swift batch receive size destination", batchSize_);
        _swiftReceive(address(swiftGateEthereum_), params_);
    }

    ////////////////////////////////// Helpers ///////////////////////////////////////////////////

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
        SwiftGate.Signature[] memory signatures_ = Helpers._getSignatures(messageHash_, governorPKs);

        uint256 initialGas_ = gasleft();
        SwiftGate(swiftGate_).swiftReceive(params_, signatures_);
        console.log("swiftReceive gas cost", initialGas_ - gasleft());

        for (uint i_; i_ < params_.length; i_++) {
            ERC20 wrappedToken_ = ERC20(SwiftGate(swiftGate_).getWrappedToken(params_[i_].srcChain, params_[i_].token));
            if (address(wrappedToken_) != address(0))
                assertEq(wrappedToken_.balanceOf(params_[i_].receiver), params_[i_].amount);
            else
                assertEq(ERC20(params_[i_].token).balanceOf(params_[i_].receiver), params_[i_].amount);
        }
    }

    function _swiftSend(address swiftGate_, address sender_, address token_, uint256 amount_, address receiver_, uint16 dstChain_) internal {
        uint256 initialSWGateBalance_ = ERC20(token_).balanceOf(swiftGate_);

        vm.startPrank(sender_);
        ERC20(token_).approve(swiftGate_, amount_);
        SwiftGate(swiftGate_).swiftSend(token_, amount_, receiver_, dstChain_, true);
        vm.stopPrank();

        if (SwiftGate(swiftGate_).getRemoteTokenOf(token_) == address(0))
            assertEq(ERC20(token_).balanceOf(swiftGate_), initialSWGateBalance_ + amount_);
        else
            assertEq(ERC20(token_).balanceOf(sender_), initialSWGateBalance_);
    }
}
