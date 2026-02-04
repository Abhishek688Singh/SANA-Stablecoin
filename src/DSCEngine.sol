// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";

contract DSCEngine {
    /////////////////
    //   Errors    //
    /////////////////
    error DSCEngine__NeedsMoreThenZero();
    error DSCEngine__TokenAddressLengthAndPriceFeedAddressLengthMustBeSame();

    /////////////////////
    // State variables //
    /////////////////////
    mapping(address token => address priceFeed) private sPriceFeed; //tokenToPriceFeed
    DecentralizedStableCoin private immutable I_DSC;

    /////////////////
    //  Modifiers  //
    /////////////////
    modifier moreThenZero(uint256 value) {
        _moreThenZero(value);
        _;
    }

    // modifier isAllowedToken(address token) {}

    /////////////////
    //  Functions  //
    /////////////////
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressLengthAndPriceFeedAddressLengthMustBeSame();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            sPriceFeed[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        I_DSC = DecentralizedStableCoin(dscAddress);
    }

    //////////////////////////
    //  EXTERNAL Functions  //
    //////////////////////////
    function depositCollateralAndMintDsc() external {}

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external moreThenZero(amountCollateral) {}

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc(uint256 amountDsc) external moreThenZero(amountDsc) {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    //////////////////////////
    //  INTERNAL Functions  //
    //////////////////////////
    function _moreThenZero(uint256 value) internal pure {
        if (value == 0) revert DSCEngine__NeedsMoreThenZero();
    }
}
