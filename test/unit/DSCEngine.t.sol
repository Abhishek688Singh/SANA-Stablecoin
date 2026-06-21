// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// test name pattern
// test<Action>Reverts<Condition>

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
    /*
    - Deposit 10 WETH.
    - Mint 1000 DSC.

    Both use 18 decimals, so using ether as a denomination for the numeric literal is completely fine because:

    1000 ether == 1000e18

    Even though the variable represents DSC and not ETH, ether in Solidity is just a multiplier of 10^18.
        */
    uint256 public constant MINT_DSC = 20 ether;
    uint256 public constant AMOUNT_COLLATERAl = 20 ether;
    uint256 public constant AMOUNT_DSC_TO_MINT = 20 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(nitesh, STARTING_ERC20_BALANCE);
    }

    ////////////////////////////
    //    Constructor test    //
    ////////////////////////////
    address[] public tokenAddresses;
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

    function testGetTokenAmountFromUsd() public view {
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

    //this test uses latest version of openzeppelin/openzeppelin-contracts
    function testDepositCollateralRevertsForUnsupportedToken() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(nitesh);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), STARTING_BALANCE);
        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(nitesh);
        ERC20Mock(weth).approve(address(dsce), STARTING_BALANCE);
        dsce.depositCollateral(weth, STARTING_BALANCE);
        vm.stopPrank();
        _;
    }

    function testDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(nitesh);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositedAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(STARTING_BALANCE, expectedDepositedAmount);
    }

    ///////////////////////////////////
    //      MintCollateral test      //
    ///////////////////////////////////
    function testCantMintWithoutDepositCollateral() public {
        // Do NOT deposit collateral; do NOT approve anything.
        // Try to mint — should revert because health factor will be broken.
        // With 0 collateral, the health factor will be 0
        // vm.startPrank(nitesh);

        uint256 expectedHealthFactor = dsce.calculateHealthFactor(MINT_DSC, 0);

        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreakHealthFactor.selector, expectedHealthFactor));
        dsce.mintDsc(MINT_DSC);

        // vm.stopPrank();
    }

    /**
     * Make every other condition valid.
     *
     * Break only the condition you want to test.
     */
    function testMintWithZeroRevertsNeedsMoreThenZero() public {
        vm.startPrank(nitesh);
        //Arrange
        //{is2}
        // I allow address(dsce) to spend up to MINT_DSC amount of (weth/wbtc) my tokens from my wallet.
        ERC20Mock(weth).approve(address(dsce), MINT_DSC);

        //We first run this to prevent some health factor issues {is3}
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAl, AMOUNT_DSC_TO_MINT);

        //Act + Assert
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThenZero.selector);
        dsce.mintDsc(0);

        vm.stopPrank();
    }

    // TODO: increase the test coverage upto 85%
}
