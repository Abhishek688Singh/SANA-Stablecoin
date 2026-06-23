// SPDX-License-Identifier: MIT

// 1. The total supply of DSC should be less than the total value of collateral
// 2. Getter view functions should never revert <- evergreen invariant

// Invariants:
// protocol must never be insolvent / undercollateralized
// TODO: users cant create stablecoins with a bad health factor
// TODO: a user should only be able to be liquidated if they have a bad health factor

pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { DeployDSC } from "script/DeployDSC.s.sol";
import { DecentralizedStableCoin } from "src/DecentralizedStableCoin.sol";
import { DSCEngine } from "src/DSCEngine.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StopOnRevertHandler } from "test/fuzz/failingOnRevert/StopOnRevertHandler.t.sol";

contract StopOnRevertInvariants is StdInvariant, Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    StopOnRevertHandler handler;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed,, weth, wbtc,) = config.activeNetworkConfig();

        // targetContract(address(dsce));
        handler = new StopOnRevertHandler(dsce, dsc);
        targetContract(address(handler));
        //dont call the redeemcollateral unless there is some collateral to redeem
        // targetContract(address(ethUsdPriceFeed)); Why can't we just do
        // this?//////////////////////////////////////////
    }

    /**
     * This invariant test targets the Handler contract.
     *
     * Foundry will repeatedly call the functions defined in Handler
     * with random inputs while respecting the guardrails written there.
     *
     * After every sequence of calls, this invariant is checked:
     *
     *     wethValue + wbtcValue >= totalSupply
     *
     * Meaning:
     * The total USD value of all collateral held by the protocol
     * must always be greater than or equal to the total DSC supply.
     *
     * No matter how many times or in what order the Handler functions
     * are executed, this condition should always remain true.
     */
    function invariant_protocallMustHaveMoreValueThenTotalSupply() public view {
        //get value of all the collateral in protocall
        //compare it to all the debt (dsc)
        uint256 totalSupply = dsc.totalSupply();

        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalBtcDeposited);

        console.log("weth value: ", wethValue);
        console.log("wbtc value: ", wbtcValue);
        console.log("total supply: ", totalSupply);

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNotBeRevert() public view {
        dsce.getLiquidationBonus();
        dsce.getPrecision();
        dsce.getCollateralTokens();
    }
}
