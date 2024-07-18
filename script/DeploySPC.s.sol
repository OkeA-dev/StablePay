//SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {StablePayCoin} from "../src/StablePayCoin.sol";
import {SPCEngine} from "../src/SPCEngine.sol";

contract DeploySPC is Script {
    StablePayCoin stablePayCoin;

    function run() external returns (StablePayCoin, SPCEngine) {
        vm.startBroadcast();
        stablePayCoin = new StablePayCoin();
        vm.stopBroadcast();

           }
}