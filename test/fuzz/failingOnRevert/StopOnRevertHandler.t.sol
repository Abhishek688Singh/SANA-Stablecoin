// SPDX-License-Identifier: MIT
// narrow down the way we call functions

pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { DSCEngine } from "src/DSCEngine.sol";
import { DecentralizedStableCoin } from "src/DecentralizedStableCoin.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { MockV3Aggregator } from "test/mocks/MockV3Aggregator.sol";

contract StopOnRevertHandler is Test {
    DecentralizedStableCoin dsc;
    DSCEngine dsce;

    ERC20Mock weth;
    ERC20Mock wbtc;
    MockV3Aggregator ethUsdPriceFeed;
    MockV3Aggregator btcUsdPriceFeed;

    //Ghost variables
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    address[] private usersWithCollateralDeposited;

    constructor(DSCEngine _DSCEngine, DecentralizedStableCoin _DecentralizedStableCoin) {
        dsc = _DecentralizedStableCoin;
        dsce = _DSCEngine;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(wbtc)));
    }

    // FUNCTOINS TO INTERACT WITH

    /////////////////////////
    //      DSCEngine      //
    /////////////////////////

    /**
     *  Without any Guardrails
     *  redeemCollateral <- (Call this when you have collateral)
     *
     * function depositCollateral(address collateral, uint256 amountCollateral) public {
     *     dsce.depositCollateral(collateral, amountCollateral);
     * }
     *
     *  // : Guardrails
     */

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed); //
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE); //

        vm.startPrank(msg.sender); //
        collateral.mint(msg.sender, amountCollateral); //
        collateral.approve(address(dsce), amountCollateral); //
        dsce.depositCollateral(address(collateral), amountCollateral);
        usersWithCollateralDeposited.push(msg.sender);
        vm.stopPrank(); //
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed); //
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(msg.sender, address(collateral));

        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }

        vm.prank(msg.sender);
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }

    /////////////////////////////////
    //   DecentralizedStableCoin   //
    /////////////////////////////////
    /**
     * TODO: write tests for  DecentralizedStableCoin
     */

     
    /////////////////////////////
    //        Aggregator       //
    /////////////////////////////

    //this break our invariants test
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    /////////////////////////////
    //    Helper Functions     //
    /////////////////////////////
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
