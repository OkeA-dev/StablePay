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

/*
 * @title StablePayCoin
 * @author Oke Abdulquadri
 * Collateral: Exogenous
 * Minting (Stability Mechanism): Decentralized (Algorithmic)
 * Value (Relative Stability): Anchored (Pegged to USD)
 * Collateral Type: Crypto
 *
* This is the contract meant to be owned by SPCEngine. It is a ERC20 token that can be minted and burned by the
SPCEngine smart contract.
 */

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StablePayCoin is ERC20Burnable, Ownable {
    error StablePayCoin__BurnAmountExceedsBalance();
    error StablePayCoin__MustBeMoreThanZero();
    error StablePayCoin__NotZeroAddress();

    constructor () ERC20("StablePay Coin", "SPC") Ownable(msg.sender) {}

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert StablePayCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert StablePayCoin__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) public override onlyOwner{
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert StablePayCoin__MustBeMoreThanZero();
        }
        if (_amount > balance) {
            revert StablePayCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

}