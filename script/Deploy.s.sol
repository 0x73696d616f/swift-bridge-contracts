// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import { Helpers } from "../common/Helpers.sol";

import { MintableERC20 } from "../common/MintableERC20.sol";

import { SwiftGate } from "../src/SwiftGate.sol";

contract MockContract {}

contract DeployScript is Script {
    address[] public governors;
    uint256[] public governorPKs;
    uint256 public constant MIN_SIGATURES = 13;
    SwiftGate swiftGateEthereum_;
    SwiftGate swiftGateOptimism_;
    uint16 public constant OPTIMISM_CHAIN_ID = 1;
    uint16 public constant SCROLL_CHAIN_ID = 2;
    uint16 public constant CHIADO_CHAIN_ID = 3;
    uint16 public constant MANTLE_CHAIN_ID = 4;
    uint16 public constant TAIKO_CHAIN_ID = 5;
    address public constant AAVEV3_REWARDS_CONTROLLER_OPTIMISM = 0x062BB55A42875366DB1B7D227B73621C33a6cB6b;
    address public constant AAVEV3_L2POOL_OPTIMISM = 0xCAd01dAdb7E97ae45b89791D986470F3dfC256f7;
    address public constant AAVEV3_REWARDS_CONTROLLER_SCROLL = 0xa76F05D0cdf599E0186dec880F2FA480fd0c5280;
    address public constant AAVEV3_L2POOL_SCROLL = 0x48914C788295b5db23aF2b5F0B3BE775C4eA9440;
    address public constant WETH_OPTIMISM = 0x4200000000000000000000000000000000000006;
    address public constant SWIFT_GATE = 0xB84f07612F4bfEc42E042b6CDD26df496b3d397f;
    address public constant AAVE_SCROLL_DAI = 0x7984E363c38b590bB4CA35aEd5133Ef2c6619C40;
    address public constant AAVE_OPTIMISM_DAI = 0xD9662ae38fB577a3F6843b6b8EB5af3410889f3A;

    address public constant OPTIMISM_MOCK_TOKEN = 0x2368B457E93DB89FB67f0dA1554af642F61fa0A8;
    address public constant SCROLL_MOCK_TOKEN = 0x030A74336C10c3214602e515f3fbc604D4451691;
    address public constant CHIADO_MOCK_TOKEN = 0x0B49058317F8d67ba09587a4d17e8C04907fa0B2;
    address public constant MANTLE_MOCK_TOKEN = 0xb33200abe32eB66C4ca6F5a4F92a8D8cBA47DBaD;
    address public constant TAIKO_MOCK_TOKEN = 0xc32cF0BF647259335a2151191CEDEDd1A22CaFd7;

    address public constant WRAPPED_SCROLL_TOKEN_ON_CHIADO = 0x407566726c00f97b093dCa55Fa9e87934Ed51bBd;

    mapping (uint16=>string) public chainIdToName;
    mapping (address=>address) public tokenToAToken;
    
    function setUp() public {
        for (uint i_ = 11; i_ < MIN_SIGATURES + 11; i_++) {
            governorPKs.push(i_);
            governors.push(vm.addr(i_));
        }
        vm.label(WETH_OPTIMISM, "WETH_OPTIMISM");
        chainIdToName[OPTIMISM_CHAIN_ID] = "OPTIMISM";
        chainIdToName[SCROLL_CHAIN_ID] = "SCROLL";
        chainIdToName[CHIADO_CHAIN_ID] = "CHIADO";
        chainIdToName[MANTLE_CHAIN_ID] = "MANTLE";
        chainIdToName[TAIKO_CHAIN_ID] = "TAIKO";
        tokenToAToken[AAVE_SCROLL_DAI] = 0x99Cb50E6bE36C8096e6731ED7738d93090B710DD;
        tokenToAToken[AAVE_OPTIMISM_DAI] = 0x844f622596D061B8AeB0bf265bDfbdafd5Fb7856;
    }

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        uint16 chainId_ = TAIKO_CHAIN_ID;
        uint16 remoteChainId_ = MANTLE_CHAIN_ID;

        //_depositToAaveV3(chainId_, AAVE_OPTIMISM_DAI, 90);
        //_withdrawFromAaveV3(chainId_, AAVE_OPTIMISM_DAI, 10);

        //WETH_OPTIMISM.call{value: 10000}("");
        //_addDstToken(chainId_, AAVE_OPTIMISM_DAI, SWIFT_GATE);

        //_createWrappedTokens(chainId_);

        //address wrappedToken_ = SwiftGate(SWIFT_GATE).getWrappedToken(OPTIMISM_CHAIN_ID, 0xaB1Ef4C5390fE153550F490282fb95871078C52c);
        //console.log(MintableERC20(wrappedToken_).balanceOf(0x81B14fEa9FBf83937b97bA0F7Ef8383Cd10236F7));

        //_receive(SCROLL_MOCK_TOKEN, 100, 0xbEf4683c8E272971DcDF94B0AbCC55292329bDD4, remoteChainId_, chainId_, keccak256("1"));
        _send(TAIKO_MOCK_TOKEN, 100, 0xbEf4683c8E272971DcDF94B0AbCC55292329bDD4, remoteChainId_);
        //Helpers._addWrappedToken(SWIFT_GATE, chainId_, remoteChainId_, AAVE_OPTIMISM_DAI, "Wrapped OPTIMISM AAVE DAI", "WOPAD", governorPKs, keccak256("3"));
        vm.stopBroadcast();
    }

    function _send(address token_, uint256 amount_, address to_, uint16 remoteChainId_) internal {
        MintableERC20(token_).approve(SWIFT_GATE, amount_);
        SwiftGate(SWIFT_GATE).swiftSend(token_, amount_, to_, remoteChainId_, true);
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

        SwiftGate(SWIFT_GATE).swiftReceive(params_, Helpers._getSignatures(messageHash_, governorPKs), salt_);
    }

    function _deploy(uint16 chainId_) internal {
        address aaveV3Pool_;
        address aaveV3RewardsController_;
        if (chainId_ == OPTIMISM_CHAIN_ID) {
            aaveV3Pool_ = AAVEV3_L2POOL_OPTIMISM;
            aaveV3RewardsController_ = AAVEV3_REWARDS_CONTROLLER_OPTIMISM;
        } else if(chainId_ == SCROLL_CHAIN_ID) {
            aaveV3Pool_ = AAVEV3_L2POOL_SCROLL;
            aaveV3RewardsController_ = AAVEV3_REWARDS_CONTROLLER_SCROLL;
        }

        SwiftGate swiftGate_ =  Helpers._deploySwiftGate(chainId_, governors, MIN_SIGATURES, aaveV3Pool_, aaveV3RewardsController_);
        //SwiftGate swiftGate_ = SwiftGate(0xB84f07612F4bfEc42E042b6CDD26df496b3d397f);

        // increase nonce to have different token addresses
        for (uint i_ = 1; i_ < chainId_;i_++) {
            new MockContract();
        }

        string memory name_ = string(abi.encodePacked("SwiftGate Token ", chainIdToName[chainId_]));
        string memory symbol_ = string(abi.encodePacked("SWT ", chainIdToName[chainId_]));
        address token_ = address(new MintableERC20(name_, symbol_));

        console.log("swiftGate", address(swiftGate_));
        console.log("token", token_);
        _addDstToken(chainId_, token_, address(swiftGate_));
    }

    function _createWrappedTokens(uint16 chainId_) internal {
        if (chainId_ != OPTIMISM_CHAIN_ID) Helpers._addWrappedToken(SWIFT_GATE, chainId_, OPTIMISM_CHAIN_ID, OPTIMISM_MOCK_TOKEN, string(abi.encodePacked("Wrapped SwiftGate Token ", chainIdToName[OPTIMISM_CHAIN_ID])), string(abi.encodePacked("WSWT ", chainIdToName[OPTIMISM_CHAIN_ID])), governorPKs, keccak256("1"));
        if (chainId_ != SCROLL_CHAIN_ID) Helpers._addWrappedToken(SWIFT_GATE, chainId_, SCROLL_CHAIN_ID, SCROLL_MOCK_TOKEN, string(abi.encodePacked("Wrapped SwiftGate Token ", chainIdToName[SCROLL_CHAIN_ID])), string(abi.encodePacked("WSWT ", chainIdToName[SCROLL_CHAIN_ID])), governorPKs, keccak256("2"));
        if (chainId_ != CHIADO_CHAIN_ID) Helpers._addWrappedToken(SWIFT_GATE, chainId_, CHIADO_CHAIN_ID, CHIADO_MOCK_TOKEN, string(abi.encodePacked("Wrapped SwiftGate Token ", chainIdToName[CHIADO_CHAIN_ID])), string(abi.encodePacked("WSWT ", chainIdToName[CHIADO_CHAIN_ID])), governorPKs, keccak256("3"));
        if (chainId_ != MANTLE_CHAIN_ID) Helpers._addWrappedToken(SWIFT_GATE, chainId_, MANTLE_CHAIN_ID, MANTLE_MOCK_TOKEN, string(abi.encodePacked("Wrapped SwiftGate Token ", chainIdToName[MANTLE_CHAIN_ID])), string(abi.encodePacked("WSWT ", chainIdToName[MANTLE_CHAIN_ID])), governorPKs, keccak256("4"));
        if (chainId_ != TAIKO_CHAIN_ID) Helpers._addWrappedToken(SWIFT_GATE, chainId_, TAIKO_CHAIN_ID, TAIKO_MOCK_TOKEN, string(abi.encodePacked("Wrapped SwiftGate Token ", chainIdToName[TAIKO_CHAIN_ID])), string(abi.encodePacked("WSWT ", chainIdToName[TAIKO_CHAIN_ID])), governorPKs, keccak256("5"));
    }

    function _depositToAaveV3(uint16 chainId_, address token_, uint256 amount_) internal {
        Helpers._depositToAaveV3(SWIFT_GATE, chainId_, token_, amount_, governorPKs, bytes32(block.timestamp));
    }

    function _withdrawFromAaveV3(uint16 chainId_, address token_, uint256 amount_) internal {
        Helpers._withdrawFromAaveV3(SWIFT_GATE, chainId_, token_, tokenToAToken[token_], amount_, SWIFT_GATE, governorPKs, bytes32(block.timestamp));
    }

    function _addDstToken(uint16 chainId_, address token_, address swiftGate_) internal {
        if (chainId_ != OPTIMISM_CHAIN_ID) Helpers._addDstToken(swiftGate_, chainId_, OPTIMISM_CHAIN_ID, token_, governorPKs, keccak256("1"));
        if (chainId_ != SCROLL_CHAIN_ID) Helpers._addDstToken(swiftGate_, chainId_, SCROLL_CHAIN_ID, token_, governorPKs, keccak256("2"));
        if (chainId_ != CHIADO_CHAIN_ID) Helpers._addDstToken(swiftGate_, chainId_, CHIADO_CHAIN_ID, token_, governorPKs, keccak256("3"));
        if (chainId_ != MANTLE_CHAIN_ID) Helpers._addDstToken(swiftGate_, chainId_, MANTLE_CHAIN_ID, token_, governorPKs, keccak256("4"));
        if (chainId_ != TAIKO_CHAIN_ID) Helpers._addDstToken(swiftGate_, chainId_, TAIKO_CHAIN_ID, token_, governorPKs, keccak256("5"));
    }
}
