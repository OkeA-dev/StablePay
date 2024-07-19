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
// fallback function (if exists)\
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeploySPC} from "../../script/DeploySPC.s.sol";
import {StablePayCoin} from "../../src/StablePayCoin.sol";
import {SPCEngine} from "../../src/SPCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract TestSPCEngine is Test {
    StablePayCoin spc;
    SPCEngine spcEngine;
    DeploySPC deployspc;
    HelperConfig config;
    address public wethUsdPriceFeed;
    address public weth;

    function setUp() external {
        deployspc = new DeploySPC();
        (spc, spcEngine, config) = deployspc.run();
        (wethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();
    }

    ////////////////////////
    //    PRICE TEST    ///
    //////////////////////
    function testGetUsdValue() public {
        uint256 ethAmount = 20e18;
        //20e18 * 2000 = 40000e18
        uint256 expectedValue = 40000e18;
        uint256 actualValue = spcEngine.getUsdValue(weth, ethAmount);

        assertEq(expectedValue, actualValue);
    }
}
