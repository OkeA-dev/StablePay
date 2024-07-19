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
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySPC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (StablePayCoin, SPCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address wbtc, address weth, uint256 deployerKey) =
            config.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        StablePayCoin spc = new StablePayCoin();
        SPCEngine spcEngine = new SPCEngine(tokenAddresses, priceFeedAddresses, address(spc));
        spc.transferOwnership(address(spcEngine));

        vm.stopBroadcast();

        return (spc, spcEngine, config);
    }
}
