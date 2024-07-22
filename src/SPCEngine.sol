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
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
    error SPCEngine__BreaksHealthFactor(uint256 userHealthFactor);
    error SPCEngine__MintFailed();

    ////////////////////////
    //   STATE VARIABLE   //
    ///////////////////////
    uint256 private constant ADDITIONAL_FEED_PERCISION = 1e10;
    uint256 private constant PERCISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PERCISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_depositedCollaterals;
    mapping(address user => uint256 amountOfSPCMinted) private s_SPCMinted;
    StablePayCoin private immutable i_spc;
    address[] private s_collateralTokens;

    event CollateralDeposited(address indexed user, address indexed tokenAddress, uint256 tokenAmount);
    event RedeemCollateral(address indexed user, address indexed token, uint256 tokenAmount);

    /////////////////
    //   MODIFIER  //
    ////////////////

    modifier moreThanZero(uint256 _amount) {
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
    /////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedsAddresses, address spcAddress) {
        if (tokenAddresses.length != priceFeedsAddresses.length) {
            revert SPC__tokenAddressAndPriceFeedsAddressMustHaveTheSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedsAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
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
    function depositCollateral(address _tokenCollateralAddress, uint256 _amountCollateral)
        public
        moreThanZero(_amountCollateral)
        isAllowedToken(_tokenCollateralAddress)
        nonReentrant
    {
        s_depositedCollaterals[msg.sender][_tokenCollateralAddress] += _amountCollateral;
        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _amountCollateral);
        bool success = IERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _amountCollateral);
        if (!success) {
            revert SPCEngine__TransferFailed();
        }
    }

    /**
     *
     * @param _tokenCollateralAddress the token address of the deposited collateral
     * @param _amountCollateral the amount of collateral to deposite
     * @param _amountSPCtoMint the amount of SPC token to mint
     * @notice this function would deposit collateral and mint spc token at one transaction
     */
    function depositCollateralAndMintSPC(
        address _tokenCollateralAddress,
        uint256 _amountCollateral,
        uint256 _amountSPCtoMint
    ) external {
        depositCollateral(_tokenCollateralAddress, _amountCollateral);
        mint(_amountSPCtoMint);
    }

    /**
     * 
     * @param _tokenCollateralAddress the collateral addresst to redeem
     * @param _amountCollateral the amount of collateral to redeem
     * @param _amountSPCtoBurn the amount of token Spc to burn
     * @notice this function redeem collateral and burn the spc token
     */
    function redeemCollateralForSPC(address _tokenCollateralAddress, uint256 _amountCollateral, uint256 _amountSPCtoBurn) external {
        redeemCollateral(_tokenCollateralAddress, _amountCollateral);
        burn(_amountSPCtoBurn);
    }

    function redeemCollateral(address _tokenCollateralAddress, uint256 _amountCollateral)
        public
        moreThanZero(_amountCollateral)
        nonReentrant
    {
        s_depositedCollaterals[msg.sender][_tokenCollateralAddress] -= _amountCollateral;
        emit RedeemCollateral(msg.sender, _tokenCollateralAddress, _amountCollateral);
        bool success = IERC20(_tokenCollateralAddress).transfer(msg.sender, _amountCollateral);
        if (!success) {
            revert SPCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * 
     * @param _amountSPCtoBurn the amount of the Spc token to burn
     * @notice this function send the specific amount of spc to the spcEngine contract to  burn.
     */

    function burn(uint256 _amountSPCtoBurn) public moreThanZero(_amountSPCtoBurn) {
        s_SPCMinted[msg.sender] -= _amountSPCtoBurn;
        bool success = i_spc.transferFrom(msg.sender, address(this), _amountSPCtoBurn);

        if (!success) {
            revert SPCEngine__TransferFailed();
        }
        i_spc.burn(_amountSPCtoBurn);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function liquidate() external {}
    /**
     * @notice it Follow CEI
     * @param _amountSPCtoMint is the amount of the token minted
     * @notice they must have collateral value that there _inimum treshold
     *
     */

    function mint(uint256 _amountSPCtoMint) public moreThanZero(_amountSPCtoMint) nonReentrant {
        s_SPCMinted[msg.sender] += _amountSPCtoMint;

        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_spc.mint(msg.sender, _amountSPCtoMint);
        if (!minted) {
            revert SPCEngine__MintFailed();
        }
    }

    function getHealthFactor() external {}

    /////////////////////////////////////
    //   PRIVATE & INTERNAL VIEW FUNCTION  //
    ///////////////////////////////////

    function _revertIfHealthFactorIsBroken(address user) private view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert SPCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }
    /**
     *
     * @param user the address of the user to check their collateral balance
     * Return how close to liquidity the user is
     */

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalSPCMinted, uint256 collateralValueInUsd) = _getAccountInfomation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PERCISION;

        return (collateralAdjustedForThreshold * PERCISION) / totalSPCMinted;
    }

    function _getAccountInfomation(address user)
        private
        view
        returns (uint256 totalSPCMinted, uint256 totalAccountCollateralValue)
    {
        totalSPCMinted = s_SPCMinted[user];
        totalAccountCollateralValue = getAccountCollateralValue(user);
    }

    /////////////////////////////////////////
    //   PUBLIC & EXTERNAL VIEW FUNCTION  //
    ///////////////////////////////////////
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_depositedCollaterals[user][token];
            totalCollateralInUsd += getUsdValue(token, amount);
        }
        return totalCollateralInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeeds = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeeds.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PERCISION) * amount) / PERCISION;
    }
}

//    uint256 private constant PRECISION = 1e18;
//uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
