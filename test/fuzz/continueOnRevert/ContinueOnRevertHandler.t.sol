// // SPDX-License-Identifier: MIT
// // narrow down the way we call functions
// // Commented out for now until revert on fail == false per function customization is implemented

// pragma solidity ^0.8.19;

// import { Test, console } from "forge-std/Test.sol";
// import { DSCEngine } from "src/DSCEngine.sol";
// import { DecentralizedStableCoin } from "src/DecentralizedStableCoin.sol";
// import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
// import { MockV3Aggregator } from "test/mocks/MockV3Aggregator.sol";

// contract ContinueOnRevertHandler is Test {
//     DecentralizedStableCoin public dsc;
//     DSCEngine public dsce;

//     ERC20Mock public weth;
//     ERC20Mock public wbtc;
//     MockV3Aggregator public ethUsdPriceFeed;
//     MockV3Aggregator public btcUsdPriceFeed;

//     //Ghost variables
//     uint256 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

//     address[] private usersWithCollateralDeposited;

//     constructor(DSCEngine _DSCEngine, DecentralizedStableCoin _DecentralizedStableCoin) {
//         dsc = _DecentralizedStableCoin;
//         dsce = _DSCEngine;

//         address[] memory collateralTokens = dsce.getCollateralTokens();
//         weth = ERC20Mock(collateralTokens[0]);
//         wbtc = ERC20Mock(collateralTokens[1]);

//         ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
//         btcUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(wbtc)));
//     }

//     // FUNCTOINS TO INTERACT WITH

//     /////////////////////////
//     //      DSCEngine      //
//     /////////////////////////

//     function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
//         amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         collateral.mint(msg.sender, amountCollateral);
//         dsce.depositCollateral(address(collateral), amountCollateral);
//     }

//     function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
//         amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         dsce.redeemCollateral(address(collateral), amountCollateral);
//     }

//     function burnDsc(uint256 amountDsc) public {
//         amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
//         dsc.burn(amountDsc);
//     }

//     function mintDsc(uint256 amountDsc) public {
//         amountDsc = bound(amountDsc, 0, MAX_DEPOSIT_SIZE);
//         dsc.mint(msg.sender, amountDsc);
//     }

//     /////////////////////////////////
//     //   DecentralizedStableCoin   //
//     /////////////////////////////////
//     /**
//      * TODO: write tests for  DecentralizedStableCoin
//      */

//     /////////////////////////////
//     //        Aggregator       //
//     /////////////////////////////

//     //this break our invariants test
//     // function updateCollateralPrice(uint96 newPrice) public {
//     //     int256 newPriceInt = int256(uint256(newPrice));
//     //     ethUsdPriceFeed.updateAnswer(newPriceInt);
//     // }

//     /////////////////////////////
//     //    Helper Functions     //
//     /////////////////////////////

//     function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
//         if (collateralSeed % 2 == 0) {
//             return weth;
//         } else {
//             return wbtc;
//         }
//     }

//     function callSummary() external view {
//         console.log("Weth total deposited", weth.balanceOf(address(dsce)));
//         console.log("Wbtc total deposited", wbtc.balanceOf(address(dsce)));
//         console.log("Total supply of DSC", dsc.totalSupply());
//     }
// }

