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
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TestSPCEngine is Test {

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 100 ether;

    StablePayCoin spc;
    SPCEngine spcEngine;
    DeploySPC deployspc;
    HelperConfig config;
    address public wethUsdPriceFeed;
    address public weth;
    address USER = makeAddr("user");

    function setUp() external {
        deployspc = new DeploySPC();
        (spc, spcEngine, config) = deployspc.run();
        (wethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        
    }

      //////////////////////
     //    PRICE TEST    //
    //////////////////////
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
      
        uint256 expectedValue = 30_000 ether;
        uint256 actualValue = spcEngine.getUsdValue(weth, ethAmount);

        assertEq(actualValue, expectedValue);
    }

    function testRevertIfCollateralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(spcEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(SPCEngine.SPCEngine__NeedsMoreThanZero.selector);
        spcEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
