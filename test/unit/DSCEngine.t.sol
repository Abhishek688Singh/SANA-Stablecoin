// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;
    address public nitesh = makeAddr("NITESH");
    uint256 public constant STARTING_BALANCE = 20 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 20 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed,btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(nitesh, STARTING_ERC20_BALANCE);
    }

    ////////////////////////////
    //    Constructor test    //
    ////////////////////////////
    address [] public tokenAddresses;
    address[] public priceFeedAddresses;
    function testRevertIfTokenLengthDosentMatchPriceFeedLength() public {
        tokenAddresses.push(weth);

        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressLengthAndPriceFeedAddressLengthMustBeSame.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }


    ///////////////////////
    //    price test     //
    ///////////////////////
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/eth = 30,000e18getUsdValue
        uint256 expectedValue = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedValue, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view{
        uint256 usdAmountInWei = 200e18;
        uint256 expectedAmount = 1e17;
        uint256 amount = dsce.getTokenAmountFromUsd(weth, usdAmountInWei);
        assertEq(amount, expectedAmount);
    }

    ///////////////////////////////////
    //    depositCollateral test     //
    ///////////////////////////////////
    function testRevertIfCollateralZero() public {
        vm.startPrank(nitesh);
        ERC20Mock(weth).approve(address(dsce), STARTING_BALANCE);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThenZero.selector);
        dsce.depositCollateral(nitesh, 0);
        vm.stopPrank();
    }
}
