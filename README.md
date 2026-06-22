# Decentralized StableCoin (SanaC) Protocol

Welcome to the **SanaC (SANA)** Protocol repository. This document serves as a comprehensive guide to understanding, deploying, interacting with, and auditing the Decentralized StableCoin system. 

SanaC is an exogenously collateralized, dollar-pegged, algorithmically stable cryptocurrency. The protocol is designed to be minimal, ensuring that 1 SANA token strictly maintains a $1 peg by staying over-collateralized at all times.

---

## Table of Contents

1. [Protocol Specification](#1-protocol-specification)
2. [User Documentation](#2-user-documentation)
3. [Developer Documentation](#3-developer-documentation)
4. [Architecture Guide](#4-architecture-guide)
5. [Security Reference](#5-security-reference)
6. [Auditor Documentation](#6-auditor-documentation)
7. [Testing Guide](#7-testing-guide)
8. [Educational Resource](#8-educational-resource)

---

## 1. Protocol Specification

The protocol is built heavily inspired by MakerDAO's DSS system but stripped down to its bare essentials.

### Key Characteristics
* **Collateral Types:** Exogenous (Wrapped Ethereum - WETH, and Wrapped Bitcoin - WBTC).
* **Peg:** Algorithmic soft-peg to 1 USD.
* **Collateralization Ratio:** 200% (Liquidation Threshold is 50%, meaning collateral value must be at least double the minted debt).
* **Liquidation Bonus:** 10%.
* **Oracle:** Chainlink Price Feeds with built-in stale price checks (3-hour timeout).
* **Precision:** Core mathematical operations use `1e18` (WAD) precision.

<!-- ### Missing Features (Explicitly Excluded)
To keep the protocol minimal and secure, the following features are **Not implemented in the current version**:
* Governance modules
* DAO voting
* Stability fees
* Yield mechanisms
* Interest rates
* Flash loans
* Multi-chain support -->

---

## 2. User Documentation

### Core Concepts

* **Collateral:** To mint SANA, you must provide WETH or WBTC as collateral.
* **Overcollateralization:** For every $1 of SANA you mint, you must maintain at least $2 worth of collateral. If your collateral value drops, your position might be liquidated.
* **Health Factor:** A metric that determines the safety of your position. A Health Factor of `< 1.0` means you are undercollateralized and vulnerable to liquidation.

### How to use the Protocol

1. **Deposit Collateral:** Supply WETH or WBTC to the `DSCEngine`.
2. **Mint SANA:** Borrow against your deposited collateral. You can also use `depositCollateralAndMintDsc` to do steps 1 and 2 in a single transaction.
3. **Burn SANA:** Repay your minted debt. 
4. **Redeem Collateral:** Withdraw your WETH/WBTC. You can use `redeemCollateralForDsc` to burn SANA and retrieve collateral simultaneously.
5. **Liquidate:** Any user can monitor the system and liquidate positions that drop below a Health Factor of `1.0`, earning a 10% bonus on the seized collateral.

---

## 3. Developer Documentation

### Installation & Setup
The project uses [Foundry](https://getfoundry.sh/).

```bash
forge install
forge build
```

### Deployment Scripts
The protocol provides deterministic deployment scripts via `script/DeployDSC.s.sol`. 
* The script initializes the `HelperConfig` which manages network-specific settings (Price Feeds, Token Addresses, Deployer Keys).
* It deploys `DecentralizedStableCoin` first.
* It deploys `DSCEngine` passing the permitted tokens, price feeds, and the SANA address.
* It transfers the ownership of `DecentralizedStableCoin` to `DSCEngine` to secure the minting rights.

**Networks Supported (`script/HelperConfig.s.sol`):**
* **Sepolia Testnet:** Uses live Chainlink feeds and testnet WETH/WBTC.
* **Local Anvil:** Dynamically deploys `ERC20Mock` and `MockV3Aggregator` contracts for isolated local testing.

---

## 4. Architecture Guide

The protocol consists of two primary smart contracts and several critical supporting components.

### Core Contracts
1. **`DecentralizedStableCoin.sol`:** An ERC20 token extending `ERC20Burnable` and `Ownable`. 
   * It contains strict access controls. Only the owner (`DSCEngine`) can mint or burn the tokens.
   * Hardcoded Token Name: `SanaC`, Symbol: `SANA`.
2. **`DSCEngine.sol`:** The core engine, functioning as the vault manager.
   * Tracks user collateral balances (`sCollateralDeposited`).
   * Tracks user debt (`sDscMinted`).
   * Handles USD value conversions using Chainlink.
   * Enforces the `MIN_HEALTH_FACTOR`.

### Libraries & Utilities
* **`OracleLib.sol`:** Extends Chainlink's `AggregatorV3Interface`. Validates that the latest round data is not stale (older than 3 hours). If an oracle fails or halts, the entire protocol freezes to prevent bad debt, acting as a structural circuit breaker.

---

## 5. Security Reference

### Access Control
* `DecentralizedStableCoin`: `mint()` and `burn()` are restricted by the `onlyOwner` modifier. Ownership is permanently transferred to `DSCEngine` during deployment.
* `DSCEngine`: Uses `ReentrancyGuard` (`nonReentrant`) on all state-mutating functions (Deposit, Redeem, Mint, Liquidate) to prevent reentrancy attacks.

### Oracle Security
The `OracleLib` ensures that stale prices will revert the transaction. This guarantees that no user can mint SANA or be liquidated using outdated prices if Chainlink nodes go offline.

### Solvency
The strict 200% overcollateralization ratio and the 10% liquidation bonus mathematically incentivize external liquidators to constantly maintain the solvency of the protocol.

---

## 6. Auditor Documentation

If you are auditing this codebase, please note the following design decisions:
* **Precision Math:** The system strictly scales Chainlink feed outputs (`1e8`) to match 18 decimal precision (`1e18`) by multiplying by `1e10` (`ADDITIONAL_FEED_PRECISION`).
* **Health Factor Calculation:** 
  `Health Factor = (Collateral Value in USD * Liquidation Threshold / 100) * 1e18 / Total DSC Minted`.
  If a user has 0 minted DSC, the Health Factor returns `type(uint256).max` to avoid division by zero errors.
* **CEI Pattern:** All functions in `DSCEngine.sol` strictly follow the Checks-Effects-Interactions (CEI) pattern.

---

## 7. Testing Guide

The testing suite relies on Foundry and is split into Unit, Fuzz, and Invariant tests.

### Running Tests
```bash
forge test
```

### 1. Unit Tests (`test/unit/DSCEngine.t.sol`)
* Validates constructor constraints (Token and Price Feed array lengths).
* Tests USD value scaling and token conversions.
* Validates `depositCollateral` behavior and reverts on unsupported tokens.
* Tests strict adherence to the Health Factor during minting (`testMintWithZeroRevertsNeedsMoreThenZero`, `testCantMintWithoutDepositCollateral`).

### 2. Fuzz & Invariant Tests (`test/fuzz/`)
* **Invariant:** The total USD value of WETH + WBTC in the `DSCEngine` must *always* be greater than or equal to the total supply of SANA.
* **Invariant:** Core view and getter functions must never revert.
* **`Handler.t.sol`:** To ensure the fuzz tests generate realistic scenarios without wasting execution cycles, the `Handler` bounds inputs (e.g., users cannot redeem more collateral than they deposited, and they can only mint if they have deposited).
* **Mock Contracts (`test/mocks/`):** The test suite uses `MockV3Aggregator` for deterministic price feed manipulation and `ERC20Mock` to simulate collateral tokens.

---

## 8. Educational Resource

For those learning DeFi development, this repository demonstrates:
* **Algorithmic Stablecoin Mechanics:** How collateralization, debt tracking, and liquidations work together to hold a soft peg.
* **Oracles in Production:** The correct way to implement Chainlink price feeds, including stale data checks.
* **Advanced Testing:** How to implement Stateful Invariant Fuzzing using Foundry Handlers to simulate millions of real-world interactions mathematically.
* **Solidity Best Practices:** Strict usage of the CEI pattern, Custom Errors for gas optimization, and explicit modifier constraints.
