---
protocol: radiant-v2
category: credit
chains: [42161, 56, 1]
archetype: lend_borrow
executor: knowledge-only
aliases:
  - "supply USDC to radiant"
  - "deposit into radiant capital"
  - "borrow against my ETH on radiant"
  - "lever up on radiant v2"
  - "repay my radiant loan"
  - "withdraw from radiant"
  - "earn yield on radiant arbitrum"
roles: [lendingpool]
actions: [deposit, borrow, repay, withdraw]
tokens: [USDC, USDT, WETH, WBTC, wstETH]
---

# Radiant v2

Radiant Capital v2 is a cross-chain, pooled, cross-collateral lending market (an Aave v2 fork). Every action
goes through the single **LendingPool** contract (role `lendingpool`) per chain; collateral and debt are
tracked across all of a user's positions (shared account health), like Aave. Supplying mints rTokens;
borrowing mints variable-debt tokens. Radiant uses Aave-**v2** naming — the supply function is `deposit`, and
`repay`/`borrow` carry a `rateMode` argument. RDNT emission rewards require a locked dLP position, but base
lend/borrow works without it.

> **executor: knowledge-only.** No engine executor runs this archetype yet; the harness will
> `needs_research` a Radiant request until a `lend_borrow` executor exists. This file is the knowledge the
> author + future executor build against.

## action: deposit
**Function:** `deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)`
**Contract:** role `lendingpool` (registry: `credit/radiant-v2/lendingpool`)
**Use when:** supplying an asset to earn yield and/or enable it as collateral (Aave-v2 `deposit`, not
`supply`).

### params
- `asset` — the token address, resolved from the token book by symbol.
- `amount` — in the asset's decimals; scale from the token book, never a hardcoded 10^n.
- `onBehalfOf` — **MUST be the vault's own address.** `referralCode` — `0`.

### pitfalls
- Approve `asset` to the `lendingpool` first (approve leg must be in the plan).
- `onBehalfOf` ≠ self credits someone else's account — refuse.
- It's `deposit`, not `supply` — using the Aave-v3 name reverts (no such selector on the v2 pool).

### safety
- Depositing does not auto-enable collateral on every asset config; if borrowing against it, confirm the
  asset is collateral-enabled for the account.

## action: borrow
**Function:** `borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)`
**Contract:** role `lendingpool` (registry: `credit/radiant-v2/lendingpool`)
**Use when:** drawing a loan against supplied collateral.

### params
- `interestRateMode` — **2 = variable** (use variable). `referralCode` — `0`.
- `onBehalfOf` — the vault (whose account is debited; the borrowed tokens go to `msg.sender` = the vault).

### pitfalls
- Borrowing on behalf of another account requires a credit delegation you don't have — refuse unless self.

### safety
- After the borrow, the account **health factor MUST stay > 1** (with a buffer). Refuse a borrow that would
  drop HF to/near 1 — a price move liquidates the whole cross-collateral account.

## action: repay
**Function:** `repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf)`
**Contract:** role `lendingpool` (registry: `credit/radiant-v2/lendingpool`)
**Use when:** paying down debt to raise the health factor or close a position.

### params
- `amount` — pass `type(uint256).max` to repay the full debt (leaves no dust). `rateMode` — 2 (variable).
- `onBehalfOf` — the vault whose debt is reduced. Approve `asset` to the `lendingpool` first.

### pitfalls
- Repaying more than the debt with a fixed amount wastes the surplus; use the max sentinel for a full close.

### safety
- Repay before withdrawing the collateral that backs it, or the withdraw drops HF below 1 and reverts.

## action: withdraw
**Function:** `withdraw(address asset, uint256 amount, address to)`
**Contract:** role `lendingpool` (registry: `credit/radiant-v2/lendingpool`)
**Use when:** pulling supplied assets (and accrued yield) back out.

### params
- `amount` — pass `type(uint256).max` to withdraw the full rToken balance. `to` — **the vault.**

### pitfalls
- Withdrawing to a `to` other than the vault leaks funds — refuse.
- Withdrawing collateral while debt is open can drop HF < 1 and revert — repay first.

### safety
- Only withdraw down to the buffer above HF 1; a full withdraw requires the position's debt fully repaid.
