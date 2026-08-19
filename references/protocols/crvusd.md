---
protocol: crvusd
category: credit
chains: [1]
archetype: cdp
executor: knowledge-only
aliases:
  - "mint crvUSD against ETH"
  - "borrow crvUSD on curve"
  - "open a crvusd loan"
  - "take a crvUSD loan against wstETH"
  - "add collateral to my crvusd loan"
  - "borrow more crvUSD"
  - "repay my crvUSD debt"
roles: [controller]
actions: [create_loan, add_collateral, borrow_more, repay]
tokens: [WETH, wstETH, WBTC, crvUSD]
---

# crvUSD

crvUSD is Curve's CDP stablecoin. Each collateral asset has its own **Controller** (role `controller`) paired
with a **LLAMMA** AMM. The distinctive mechanic is **soft liquidation**: instead of a hard liquidation at a
single price, LLAMMA spreads the collateral across a set of price **bands** and continuously converts
collateral↔crvUSD as price moves through them. The borrower picks `N`, the number of bands — wider bands
(higher N) soften liquidation but sit closer to the current price. A position lives entirely in its
collateral's controller; different collaterals are isolated controllers.

> **executor: knowledge-only.** No engine executor runs the `cdp` archetype yet; the harness will
> `needs_research` a crvUSD request until one exists. This file is the knowledge the author + future executor
> build against.

## action: create_loan
**Function:** `create_loan(uint256 collateral, uint256 debt, uint256 N)`
**Contract:** role `controller` (registry: `credit/crvusd/controller`) — the controller for the chosen collateral.
**Use when:** opening a new crvUSD loan: deposit collateral, mint crvUSD.

### params
- `collateral` — the collateral amount in the token's decimals (18 for WETH/wstETH, 8 for WBTC); scale from
  the token book, never a hardcoded 10^n.
- `debt` — the crvUSD to mint (18 decimals); must be ≥ the controller minimum and below the max borrowable for the collateral.
- `N` — number of LLAMMA bands (typically **4–50**); more bands = softer, wider liquidation range. The crvUSD is minted to `msg.sender` = **the vault.**

### pitfalls
- Approve `collateral` of the collateral token to the `controller` first (approve leg must be in the plan).
- Wrong controller = wrong collateral market — pin the controller to the collateral the user named.
- `debt` at the maximum leaves zero buffer — the loan opens already in soft-liquidation range.

### safety
- Borrow **well under** the max for the chosen `N` so price sits above the liquidation band range. Read the
  controller's `max_borrowable` / current health; never open at the borrow ceiling.

## action: add_collateral
**Function:** `add_collateral(uint256 collateral, address _for)`
**Contract:** role `controller` (registry: `credit/crvusd/controller`)
**Use when:** topping up collateral on an existing loan to raise health / step back from soft liquidation.

### params
- `collateral` — additional collateral (token decimals). `_for` — **the vault** (whose loan is topped up).

### pitfalls
- Approve the added collateral to the `controller` first.
- `_for` ≠ the vault adds collateral to someone else's loan — refuse.

### safety
- Adding collateral only improves health — the safe direction. Use it to recover a loan drifting into its bands.

## action: borrow_more
**Function:** `borrow_more(uint256 collateral, uint256 debt)`
**Contract:** role `controller` (registry: `credit/crvusd/controller`)
**Use when:** drawing more crvUSD (optionally adding collateral in the same call) against an existing loan.

### params
- `collateral` — extra collateral to add now (may be 0). `debt` — additional crvUSD to mint, to the vault.

### pitfalls
- Approve any added `collateral` first. Borrowing more without adding collateral pushes health toward the bands.
- The combined position must stay under the max borrowable for its band range — otherwise reverts.

### safety
- Any `borrow_more` **MUST leave health safely positive** with a buffer above the soft-liquidation range —
  refuse a draw that pushes the loan to the edge of its bands.

## action: repay
**Function:** `repay(uint256 _d_debt, address _for)`
**Contract:** role `controller` (registry: `credit/crvusd/controller`)
**Use when:** paying down crvUSD debt to raise health or close the loan.

### params
- `_d_debt` — the crvUSD amount to repay (18 decimals); pass the full debt to close the loan cleanly.
- `_for` — **the vault** (whose debt is reduced). Approve crvUSD to the `controller` first (needs crvUSD balance).

### pitfalls
- Repaying while in soft liquidation may settle partly in collateral — surface the realized state after.
- `_for` ≠ the vault repays someone else's loan — refuse.

### safety
- Repay before withdrawing collateral when unwinding; a full repay releases all collateral back to the vault.
