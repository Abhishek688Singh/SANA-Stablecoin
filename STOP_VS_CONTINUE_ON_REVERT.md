# StopOnRevert vs ContinueOnRevert Handler in Foundry Invariant Testing

## Big Picture

In invariant testing, the **Handler contract is NOT the contract being tested**.

The real contract being tested is:

```solidity
DSCEngine
```

The handler only acts as a **middleman** between Foundry and DSCEngine.

---

# Flow of Invariant Testing

```text
Foundry
   ↓
Handler Contract
   ↓
DSCEngine
   ↓
Check Invariants
```

Foundry randomly calls functions from the Handler.

The Handler then calls functions of DSCEngine.

---

# StopOnRevert Handler

### Philosophy

Only test **valid user actions**.

The handler carefully prepares the state so that DSCEngine calls succeed.

If a revert occurs unexpectedly:

```text
Invariant Test FAILS
```

---

## Flow

```text
Foundry
   ↓
StopOnRevertHandler
   ↓
Prepare Valid State
   ↓
DSCEngine
   ↓
Success
```

If:

```text
DSCEngine reverts
```

Then:

```text
STOP
↓
Invariant Failed
```

---

## Example

```solidity
function mintAndDepositCollateral(...)
```

Handler does:

```solidity
collateral.mint(user, amount);

collateral.approve(
    address(dscEngine),
    amount
);

dscEngine.depositCollateral(
    address(collateral),
    amount
);
```

Everything required for success is prepared beforehand.

---

## Liquidation Example

```solidity
uint256 hf = dscEngine.getHealthFactor(user);

if(hf >= MIN_HEALTH_FACTOR){
    return;
}

dscEngine.liquidate(...);
```

The handler checks:

* Is the user liquidatable?
* If NO → Return.
* If YES → Liquidate.

This avoids unnecessary reverts.

---

# ContinueOnRevert Handler

### Philosophy

Test the protocol under **random and sometimes invalid actions**.

The handler does not always prepare a valid state.

If a revert occurs:

```text
Ignore it
Continue fuzzing
```

---

## Flow

```text
Foundry
   ↓
ContinueOnRevertHandler
   ↓
Random Inputs
   ↓
DSCEngine
   ↓
Success OR Revert
```

If:

```text
DSCEngine reverts
```

Then:

```text
IGNORE
↓
Continue Testing
```

---

## Example

```solidity
function mintAndDepositCollateral(...)
```

Handler:

```solidity
collateral.mint(msg.sender, amount);

dscEngine.depositCollateral(
    address(collateral),
    amount
);
```

Notice:

* No approve()
* amount can be zero
* Invalid states are allowed

This may revert.

And that's perfectly okay.

---

# Liquidation Example

```solidity
function liquidate(...)
{
    dscEngine.liquidate(...);
}
```

No health factor check.

Possible outcomes:

```text
User is healthy
↓
liquidate()
↓
REVERT
↓
IGNORE
↓
Continue fuzzing
```

---

# Why Do Both Handlers Have The Same Functions?

Because they represent the same user actions.

Both expose:

```solidity
mintAndDepositCollateral()
redeemCollateral()
burnDsc()
liquidate()
transferDsc()
```

But they differ in:

1. How they prepare state.
2. Whether invalid inputs are allowed.
3. What happens when a revert occurs.

---

# Comparison Table

| StopOnRevert                | ContinueOnRevert           |
| --------------------------- | -------------------------- |
| Valid user behaviour        | Random user behaviour      |
| Prepares valid state        | Allows invalid state       |
| Revert = Failure            | Revert = Ignore            |
| Strict testing              | Exploratory testing        |
| Safer inputs                | Arbitrary inputs           |
| Checks protocol correctness | Checks protocol robustness |

---

# Mental Model

Think of them as:

### StopOnRevert

```text
"I will only perform actions that a normal user can perform."

If something reverts:

"Something is wrong!"
```

---

### ContinueOnRevert

```text
"I will try EVERYTHING."

Valid actions
Invalid actions
Zero amounts
Missing approvals
Bad liquidations

If something reverts:

"Okay, let's try something else."
```

---

# One Line Summary

```text
StopOnRevert = Test correctness of valid behaviour.

ContinueOnRevert = Test robustness against arbitrary behaviour.
```
