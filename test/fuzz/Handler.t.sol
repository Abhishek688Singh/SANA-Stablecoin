// SPDX-License-Identifier: MIT
// narrow down the way we call functions

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    DecentralizedStableCoin dsc;
    DSCEngine dsce;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _DSCEngine, DecentralizedStableCoin _DecentralizedStableCoin) {
        dsc = _DecentralizedStableCoin;
        dsce = _DSCEngine;

        address[] memory collateralTokens = dsce.getCollateralToken();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    //redeemCollateral <- (Call this when you have collateral)

    /**
     *  Without any Guardrails
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
        vm.stopPrank(); //
    }

    //helper functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
