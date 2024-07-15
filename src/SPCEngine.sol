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

import {StablePayCoin} from "./StablePayCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
 * @title SPCEngine
 * @author Oke Abdulquadri
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our SPC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming SPC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract SPCEngine is ReentrancyGuard {
    /////////////////
    //   ERROR     //
    ////////////////
    error SPCEngine__NeedsMoreThanZero();
    error SPC__tokenAddressAndPriceFeedsAddressMustHaveTheSameLength();
    error SPCEngine__isNotAllowedToken();
    error SPCEngine__TransferFailed();

    ////////////////////////
    //   STATE VARIABLE   //
    ///////////////////////
    mapping(address token => address priceFeed) public s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount))
        public s_depositedCollaterals;
    StablePayCoin private immutable i_spc;

    event CollateralDeposited(
        address indexed user,
        address indexed tokenAddress,
        uint256 tokenAmount
    );

    /////////////////
    //   MODIFIER  //
    ////////////////

    modifier moreThanZero(uint _amount) {
        if (_amount <= 0) {
            revert SPCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert SPCEngine__isNotAllowedToken();
        }
        _;
    }

    /////////////////
    //   FUNCTION  //
    ////////////////
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedsAddresses,
        address spcAddress
    ) {
        if (tokenAddresses.length != priceFeedsAddresses.length) {
            revert SPC__tokenAddressAndPriceFeedsAddressMustHaveTheSameLength();
        }

        for (uint i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedsAddresses[i];
        }

        i_spc = StablePayCoin(spcAddress);
    }

    //////////////////
    //   EXTERNAL  //
    ////////////////

    /*
     * Deposit collateral in to the system
     * @param tokenCollateralAddress: The address of the token to deposit as collateral
     * @param collateralAmount: The amount of token to deposit
     */
    function depositCollateral(
        address _tokenCollateralAddress,
        uint256 _amountCollateral
    )
        external
        moreThanZero(_amountCollateral)
        isAllowedToken(_tokenCollateralAddress)
        nonReentrant
    {
        s_depositedCollaterals[msg.sender][
            _tokenCollateralAddress
        ] += _amountCollateral;
        emit CollateralDeposited(
            msg.sender,
            _tokenCollateralAddress,
            _amountCollateral
        );
        bool success = IERC20(_tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            _amountCollateral
        );
        if (!success) {
            revert SPCEngine__TransferFailed();
        }
    }

    function depositCollateralAndMintSPC() external {}

    function redeemCollateralForSPC() external {}

    function redeemCollateral() external {}

    function burn() external {}

    function liquidate() external {}

    function mint() external {}

    function getHealthFactor() external {}
}
