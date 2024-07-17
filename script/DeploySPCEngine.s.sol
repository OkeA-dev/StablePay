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
import {SPCEngine} from "../src/SPCEngine.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeploySPCEngine is Script {
    SPCEngine spcEngine;
    function run() external returns (SPCEngine) {
         address mostRecentlyDeploy = DevOpsTools.get_most_recent_deployment("StablePayCoin", block.chainid);
         

    }
}