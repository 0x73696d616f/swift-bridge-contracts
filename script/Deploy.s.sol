// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import { Helpers } from "../common/Helpers.sol";

import { SwiftGate } from "../src/SwiftGate.sol";

contract DeployScript is Script {
    address[] public governors;
    uint256[] public governorPKs;
    uint256 public constant MIN_SIGATURES = 13;
    SwiftGate swiftGateEthereum_;
    SwiftGate swiftGateOptimism_;
    uint16 public constant ETHEREUM_CHAIN_ID = 1;
    uint16 public constant OPTIMISM_CHAIN_ID = 2;
    address public constant wrappedETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant wrappedETHOptimism = 0x4200000000000000000000000000000000000006;
    
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

        SwiftGate swiftGate_ = _deploy(ETHEREUM_CHAIN_ID, governors, MIN_SIGATURES);

        vm.stopBroadcast();

        console.log(swiftGate_.getChainId());
    }

    function _deploy(uint16 chainId_, address[] memory governors_, uint256 minSignatures_) internal returns(SwiftGate) {
        return Helpers._deploySwiftGate(chainId_, governors_, minSignatures_, address(0), address(0));
    }
}
