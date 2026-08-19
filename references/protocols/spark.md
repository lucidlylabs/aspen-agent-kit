---
protocol: spark
category: credit
chains: [1, 8453, 100]
archetype: lend_borrow
executor: knowledge-only
aliases:
  - "supply DAI to spark"
  - "earn yield on sparklend"
  - "borrow DAI against my ETH on spark"
  - "lever up on spark"
  - "repay my spark loan"
  - "withdraw from sparklend"
  - "supply wstETH to spark and borrow"
roles: [pool]
actions: [supply, borrow, repay, withdraw]
tokens: [DAI, USDC, USDS, WETH, wstETH]
---

# SparkLend

SparkLend is a pooled, cross-collateral lending market (an Aave v3 fork by the Sky/MakerDAO ecosystem,
DAI/USDS-centric). Every action goes through the single **Pool** contract (role `pool`) per chain; collateral
and debt are tracked across all of a user's positions (shared account health), like Aave and unlike Morpho's
isolated markets. Supplying mints spTokens; borrowing mints variable-debt tokens. Spark's DAI market is
backed by the Maker D3M, so DAI liquidity and rates track Maker's DSR/governance.

> **executor: knowledge-only.** No engine executor runs this archetype yet; the harness will
> `needs_research` a Spark request until a `lend_borrow` executor exists. This file is the knowledge the
> author + future executor build against.

## action: supply
**Function:** `supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)`
**Contract:** role `pool` (registry: `credit/spark/pool`)
**Use when:** depositing an asset to earn yield and/or enable it as collateral.

### params
- `asset` — the token address, resolved from the token book by symbol.
- `amount` — in the asset's decimals; scale from the token book, never a hardcoded 10^n.
- `onBehalfOf` — **MUST be the vault's own address.** `referralCode` — `0`.

### pitfalls
- Approve `asset` to the `pool` first (approve leg must be in the plan).
- `onBehalfOf` ≠ self credits someone else's account — refuse.

### safety
- Supplying does not auto-enable collateral on every market config; if borrowing against it, confirm the
  asset is collateral-enabled for the account.

## action: borrow
**Function:** `borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)`
**Contract:** role `pool` (registry: `credit/spark/pool`)
**Use when:** drawing a loan against supplied collateral.

### params
- `interestRateMode` — **2 = variable** (stable is deprecated/disabled; use variable). `referralCode` — `0`.
- `onBehalfOf` — the vault (whose account is debited; the borrowed tokens go to `msg.sender` = the vault).

### pitfalls
- `interestRateMode = 1` (stable) reverts — use 2.
- Borrowing on behalf of another account requires a credit delegation you don't have — refuse unless self.

### safety
- After the borrow, the account **health factor MUST stay > 1** (with a buffer). Refuse a borrow that would
  drop HF to/near 1 — a price move liquidates the whole cross-collateral account.

## action: repay
**Function:** `repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)`
**Contract:** role `pool` (registry: `credit/spark/pool`)
**Use when:** paying down debt to raise the health factor or close a position.

### params
- `amount` — pass `type(uint256).max` to repay the full debt (leaves no dust). `interestRateMode` — 2.
- `onBehalfOf` — the vault whose debt is reduced. Approve `asset` to the `pool` first.

### pitfalls
- Repaying more than the debt with a fixed amount wastes the surplus; use the max sentinel for a full close.

### safety
- Repay before withdrawing the collateral that backs it, or the withdraw drops HF below 1 and reverts.

## action: withdraw
**Function:** `withdraw(address asset, uint256 amount, address to)`
**Contract:** role `pool` (registry: `credit/spark/pool`)
**Use when:** pulling supplied assets (and accrued yield) back out.

### params
- `amount` — pass `type(uint256).max` to withdraw the full spToken balance. `to` — **the vault.**

### pitfalls
- Withdrawing to a `to` other than the vault leaks funds — refuse.
- Withdrawing collateral while debt is open can drop HF < 1 and revert — repay first.

### safety
- Only withdraw down to the buffer above HF 1; a full withdraw requires the position's debt fully repaid.
