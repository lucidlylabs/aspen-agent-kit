---
protocol: morpho-blue
category: credit
chains: [1, 8453, 42161]
archetype: lend_borrow
executor: knowledge-only
aliases:
  - "lever on morpho"
  - "borrow against my collateral"
  - "supply to morpho"
  - "supply wstETH and borrow USDC"
  - "post collateral on morpho blue"
  - "repay my morpho loan"
roles: [morpho]
actions: [supply, supplyCollateral, borrow, repay, withdraw, withdrawCollateral]
tokens: [USDC, WETH, wstETH]
---

# Morpho Blue

Morpho Blue is a minimal, isolated-market lending primitive. Every market is a fixed tuple
`(loanToken, collateralToken, oracle, irm, lltv)`; supply/borrow/repay/withdraw all go through the single
`morpho` singleton (role `morpho`) with the market tuple passed as an argument. There is no shared pool —
risk is isolated per market.

> **executor: knowledge-only.** No engine executor runs this archetype yet; the harness will
> `needs_research` a Morpho request until a `lend_borrow` executor exists. This file is the knowledge the
> author + future executor build against.

## action: supply
**Function:** `supply(MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data)`
**Contract:** role `morpho` (registry: `credit/morpho-blue/morpho`)
**Use when:** lending the market's loan token to earn the variable supply rate.

### params
- `marketParams` — the exact market tuple `(loanToken, collateralToken, oracle, irm, lltv)`.
- `assets` / `shares` — set exactly one and set the other to zero. Prefer `assets` for a precise token
  amount; use the position's full supply-share balance when a later full withdrawal must leave no dust.
- `onBehalf` — **MUST be the vault's own address.** Pass empty `data` when no callback is needed.

### pitfalls
- Approve the market's loan token to `morpho` first (approve leg must be in the plan).
- Supplying the collateral token instead of the loan token is a different operation and reverts.
- Supplying by `shares` can pull a rounded asset amount; prefer `assets` for user-specified deposits.

### safety
- `onBehalf` != self gives the supply shares to another account — refuse.
- The lender takes isolated-market oracle, collateral, LLTV, and liquidity risk; do not treat two markets
  with the same token pair but different parameters as interchangeable.

## action: withdraw
**Function:** `withdraw(MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)`
**Contract:** role `morpho` (registry: `credit/morpho-blue/morpho`)
**Use when:** withdrawing supplied loan tokens and accrued interest from a lending position.

### params
- `assets` / `shares` — set exactly one and set the other to zero. Use `assets` for a partial withdrawal;
  use the position's full supply-share balance for a clean full exit.
- `onBehalf` — the vault whose supply shares burn. `receiver` — **the vault**.

### pitfalls
- A withdrawal can revert when borrowers are using the market's liquidity, even when the account owns
  enough supply shares.
- Withdrawing a guessed asset amount for a full exit can fail from share-conversion rounding; use shares.

### safety
- `onBehalf` or `receiver` != self can require authorization or leak the withdrawn loan token — refuse.

## action: supplyCollateral
**Function:** `supplyCollateral(MarketParams marketParams, uint256 assets, address onBehalf, bytes data)`
**Contract:** role `morpho` (registry: `credit/morpho-blue/morpho`)
**Use when:** posting collateral before borrowing.

### params
- `marketParams` — the market tuple `(loanToken, collateralToken, oracle, irm, lltv)`.
- `assets` — in the **collateral token's** decimals; scale from the token book, never a hardcoded 10^n.
- `onBehalf` — **MUST be the vault's own address.** Anyone else donates your collateral.

### pitfalls
- Passing `onBehalf` ≠ self donates the collateral — refuse.
- The collateral token must be approved to the `morpho` contract first (approve leg must be in the plan).

### safety
- Collateral alone earns nothing on Morpho; it only backs a borrow. Pair it with a `borrow`.

## action: borrow
**Function:** `borrow(MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)`
**Contract:** role `morpho` (registry: `credit/morpho-blue/morpho`)
**Use when:** drawing the loan token against posted collateral.

### params
- `assets` — the loan-token amount to borrow (loan token's decimals). Set `shares = 0` when specifying `assets`.
- `onBehalf` — the vault (whose position is debited). `receiver` — the vault (where the borrowed tokens land).

### pitfalls
- Specify exactly one of `assets` / `shares` (the other 0), never both.
- Borrowing to a `receiver` other than the vault leaks the loan — refuse.

### safety
- After the borrow, the position's health factor MUST stay > 1 (below `lltv`). Refuse a borrow that
  crosses `lltv`, and leave a buffer — an oracle tick can otherwise liquidate you same-block.

## action: repay
**Function:** `repay(MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data)`
**Contract:** role `morpho` (registry: `credit/morpho-blue/morpho`)
**Use when:** paying down the loan token to reduce debt / raise the health factor.

### params
- `assets` / `shares` — again, set exactly one; use `shares` = the position's full debt shares to repay in full.
- `onBehalf` — the vault whose debt is reduced. Approve the loan token to `morpho` first.

### pitfalls
- Repaying by `assets` can dust-leave a few debt shares; repay by `shares` for a clean full close.

### safety
- Repay before `withdrawCollateral` when unwinding, or the collateral withdraw underflows the health factor.

## action: withdrawCollateral
**Function:** `withdrawCollateral(MarketParams marketParams, uint256 assets, address onBehalf, address receiver)`
**Contract:** role `morpho` (registry: `credit/morpho-blue/morpho`)
**Use when:** pulling collateral back out after debt is repaid.

### params
- `assets` — collateral amount (collateral decimals). `onBehalf` = vault, `receiver` = vault.

### pitfalls
- Withdrawing collateral while debt is open drops the health factor — refuse if it would cross `lltv`.

### safety
- Only withdraw down to the buffer above `lltv`; a full withdraw requires a full `repay` first.
