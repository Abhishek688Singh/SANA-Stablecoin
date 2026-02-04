// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedStableCoin is ERC20, ERC20Burnable, Ownable {
    error DecentralizedStableCoin_MustBeMoreThenZero();
    error DecentralizedStableCoin_BurnAmountExceedsBalance();
    error DecentralizedStableCoin_NotZeroAddress();

    constructor() ERC20("SanaC", "SNA") Ownable(msg.sender) {}

    function burn(uint256 _value) public override onlyOwner {
        uint256 balance = msg.sender.balance;
        if (_value <= 0) {
            revert DecentralizedStableCoin_MustBeMoreThenZero();
        }
        if (balance < _value) {
            revert DecentralizedStableCoin_BurnAmountExceedsBalance();
        }
        /**
         * super.burn() ---> tells that use burn() from parent class
         * only use super if fun is also `override`
         */
        super.burn(_value);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin_NotZeroAddress();
        }
        if (_amount < msg.sender.balance) {
            revert DecentralizedStableCoin_MustBeMoreThenZero();
        }
        /**
         * here we dont overriding fun so only call `_mint()`
         */
        _mint(_to, _amount);
        return true;
    }
}
