// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/*
 * @title DSCEngine
 * @author Abhishek Singh
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract DSCEngine is ReentrancyGuard {
    /////////////////
    //   Errors    //
    /////////////////
    error DSCEngine__NeedsMoreThenZero();
    error DSCEngine__TokenAddressLengthAndPriceFeedAddressLengthMustBeSame();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreakHealthFactor(uint256 userHealthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();

    /////////////////////
    // State variables //
    /////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //200% over collateralised
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address token => address priceFeed) private sPriceFeed; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private sCollateralDeposited;
    mapping(address user => uint256 amountDSCminted) private sDscMinted;
    address[] private sCollateralTokens;
    DecentralizedStableCoin private immutable I_DSC;

    /////////////////
    //  Events     //
    /////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed user, address indexed token, uint256 indexed amount);

    /////////////////
    //  Modifiers  //
    /////////////////
    modifier moreThenZero(uint256 value) {
        _moreThenZero(value);
        _;
    }

    modifier isAllowedToken(address token) {
        _isAllowedToken(token);
        _;
    }

    /////////////////
    //  Functions  //
    /////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressLengthAndPriceFeedAddressLengthMustBeSame();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            sPriceFeed[tokenAddresses[i]] = priceFeedAddresses[i];
            sCollateralTokens.push(tokenAddresses[i]);
        }
        I_DSC = DecentralizedStableCoin(dscAddress);
    }

    //////////////////////////
    //  EXTERNAL Functions  //
    //////////////////////////
    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountDscToMint: The amount of DSC you want to mint
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThenZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        sCollateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool sucess = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!sucess) revert DSCEngine__TransferFailed();
    }

    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    //In order to redeem collateral
    //Health factor  must be above 1 after redeeming
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThenZero(amountCollateral)
        nonReentrant
    {
        sCollateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral);
        // _revertIfHealthFactorBroken(msg.sender);
        bool sucess = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if (!sucess) revert DSCEngine__TransferFailed();
        _revertIfHealthFactorBroken(msg.sender);
    }

    /*
     * @param amountDscToMint: The amount of DSC you want to mint
     * You can only mint DSC if you have enough collateral
     */
    function mintDsc(uint256 amountDscToMint) public moreThenZero(amountDscToMint) nonReentrant {
        sDscMinted[msg.sender] += amountDscToMint;
        //If they dont have that much, that they minted then revert
        _revertIfHealthFactorBroken(msg.sender);

        bool minted = I_DSC.mint(msg.sender, amountDscToMint);
        if (!minted) revert DSCEngine__MintFailed();
    }

    function burnDsc(uint256 amount) public moreThenZero(amount) {
        sDscMinted[msg.sender] -= amount;
        bool sucess = I_DSC.transferFrom(msg.sender, address(this), amount);
        if (!sucess) revert DSCEngine__TransferFailed();
        I_DSC.burn(amount);
        _revertIfHealthFactorBroken(msg.sender);
    }

    /**
     * @notice Liquidates an undercollateralized position by covering part of the user's debt.
     * @param collateral The ERC20 collateral token to seize during liquidation.
     * @param user The address of the user being liquidated.
     * @param debtToCover The amount of DSC debt to repay on behalf of the user.
     * follow CEI: Checks, Effects, Interactions
     */
    function liquidate(address collateral, address user, uint256 debtToCover) external {
        //need to check health factor of uesr
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }

        //we want to burn DSC debt
        // And take their collateral
        //Bad user: $140 eth -> $100  : 140/100 * 100 = < 150% collateralized
        //debtToCover = 100$
        //$100 of DSC = ??? $of ETH
        uint256 getTokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
    }

    function getHealthFactor() external view {}

    //////////////////////////
    //  INTERNAL Functions  //
    //////////////////////////
    function _moreThenZero(uint256 value) internal pure {
        if (value == 0) revert DSCEngine__NeedsMoreThenZero();
    }

    function _isAllowedToken(address token) internal view {
        if (sPriceFeed[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
    }

    function _revertIfHealthFactorBroken(address user) internal view {
        //1. Check health factor if they have enough collateral
        //2. revert if they dont have enough
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreakHealthFactor(userHealthFactor);
        }
    }

    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateeralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateeralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _getAccountInformation(address user)
        public
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = sDscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    //////////////////////////
    //    Public Functions  //
    //////////////////////////

    //uint256 usdAmountInWei -> is in the form of wei: $2 = 2e18;
    //in this conteact we are doing every maths in 1e18
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface feed = AggregatorV3Interface(sPriceFeed[token]);
        (, int256 price,,,) = feed.latestRoundData();
        //To preserve the 1e18, we * PRECISION to make it 1e36

        // We multiply by PRECISION (1e18) to avoid losing precision during division.
        // This temporarily scales numerator to 1e36 precision.

        // price from Chainlink already has 1e8 precision.
        // Example: $29 => 29e8

        // To normalize price to 1e18 precision,
        // we multiply by ADDITIONAL_FEED_PRECISION (1e10).
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);//To preserve the 1e18, we * PRECISION to make it 1e36
        //Give the 10% bonus to the collateral
        
    }

    function getAccountCollateralValue(address user) public view returns (uint256 collateralValueInUsd) {
        for (uint256 i = 0; i < sCollateralTokens.length; i++) {
            address token = sCollateralTokens[i];
            uint256 amount = sCollateralDeposited[user][token];
            collateralValueInUsd += getUsdValue(token, amount);
        }
        return collateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(sPriceFeed[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return (((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION);
    }
}
