---
protocol: llamalend
category: credit
chains: [1]
archetype: lend_borrow
executor: knowledge-only
aliases:
  - "borrow crvUSD against wstETH on llamalend"
  - "borrow crvUSD against WBTC"
  - "open a llamalend loan"
  - "lever up on curve lending"
  - "lend crvUSD on llamalend to earn"
  - "supply crvUSD to a curve lending vault"
  - "add collateral to my llamalend loan"
  - "borrow more crvUSD on llamalend"
  - "withdraw collateral from my curve loan"
  - "repay my llamalend loan"
  - "curve lending"
tokens: [crvUSD, WETH, wstETH, WBTC, tBTC, sUSDe, sfrxUSD, CRV]
roles: [controller, vault]
actions: [supply, create_loan, borrow_more, add_collateral, remove_collateral, repay, withdraw_supply]
---

# LlamaLend (Curve Lending)

LlamaLend is Curve's **permissionless, isolated** lending protocol built on the same **LLAMMA** soft-liquidation
AMM as crvUSD (see [[crvusd]]). Every market is a **one-way pair**: a borrower deposits ONE collateral token and
borrows ONE other token — for the flagship markets that borrowed token is **crvUSD** ("Borrow crvUSD (X
collateral)"). Markets are **isolated**: a bad debt in the WBTC market cannot touch the wstETH market, unlike the
cross-collateral pooled model of [[aave-v3]]. There is **no singleton entrypoint** — each market is its OWN pair
of contracts spawned by the OneWayLendingFactory:

- a **Controller** (role `controller`) — the **borrower** side (create/modify/repay a loan), paired 1:1 with a
  LLAMMA AMM that holds the collateral across price bands.
- an ERC4626 **Vault** (role `vault`) — the **lender** side: deposit the borrowed token (crvUSD) to earn the
  borrowers' interest.

Because there is one Controller + one Vault **per collateral**, the address is resolved PER-MARKET from the
registry as `<collateral>-controller` / `<collateral>-vault` (e.g. `wstETH-controller`) — the collateral SYMBOL
picks the market. Reference layer: `github.com/curvefi/curve-llamalend.js`.

> **Soft liquidation (the defining mechanic).** Instead of a single hard-liquidation price, LLAMMA spreads the
> collateral over a set of price **bands** (`N`, chosen at loan creation, typically **4–50**). As price falls
> through the band range the AMM continuously converts collateral → crvUSD (and back if price recovers). A loan
> is only HARD-liquidatable once price has fallen entirely below its bands and health goes negative. More bands
> = softer/wider liquidation but a range that starts closer to the current price (and more AMM slippage cost).

> **executor: knowledge-only.** No engine executor runs the `lend_borrow` archetype yet; the harness will
> `needs_research` a LlamaLend request until one exists. This file + the registry rows are the groundwork the
> future executor builds against. All borrower actions are on the **Controller**; the lender deposit is on the
> **Vault**. Every write signs as `msg.sender` = **the vault/burner** (the "own loan" single-arg variants).

## action: supply
**Function:** `deposit(uint256 assets, address receiver)` — ERC4626.
**Contract:** role `vault` (registry: `credit/llamalend/<collateral>-vault`) — the market's lending vault.
**Use when:** LENDING crvUSD into a market to earn the borrowers' interest (the passive/lender side).

### params
- `assets` — crvUSD to deposit (18 decimals); scale from the token book, never a hardcoded 10^n.
- `receiver` — **MUST be the vault's own address** (shares mint to the depositor). Anyone else receives the shares.

### pitfalls
- Approve `crvUSD` to the `vault` first (approve leg must be in the plan).
- The vault's underlying is the **borrowed** token (crvUSD), NOT the collateral — depositing the collateral token reverts.
- Lender liquidity can be fully borrowed; a withdraw then waits for repayments or new deposits (utilisation risk).

### safety
- `receiver` ≠ self mints shares to someone else — refuse.
- Pick the market by collateral, but the lender only ever holds/earns crvUSD; APY floats with utilisation.

## action: create_loan
**Function:** `create_loan(uint256 collateral, uint256 debt, uint256 N)`
**Contract:** role `controller` (registry: `credit/llamalend/<collateral>-controller`) — the chosen collateral's market.
**Use when:** opening a NEW loan: deposit collateral, borrow crvUSD. Reverts if a loan already exists (use `borrow_more`).

### params
- `collateral` — collateral amount in the collateral token's decimals (18 for WETH/wstETH/CRV/sUSDe/sfrxUSD, 8 for
  WBTC/tBTC); scale from the token book, never a hardcoded 10^n.
- `debt` — crvUSD to borrow (18 decimals); must be ≤ the controller's `max_borrowable(collateral, N)`.
- `N` — number of LLAMMA bands (**4–50**); more bands = softer liquidation but a range nearer today's price. The
  crvUSD is minted to `msg.sender` = **the vault.**

### pitfalls
- Approve the `collateral` token to the `controller` first (approve leg must be in the plan).
- **Wrong controller = wrong collateral market** — pin the controller to the collateral the user named (the
  `<collateral>-controller` role); a mismatch is refused, never guessed.
- Borrowing at `max_borrowable` opens the loan already in soft-liquidation range.

### safety
- Borrow **well under** `max_borrowable` for the chosen `N` so price sits above the band range. Read the
  controller's health / `max_borrowable`; never open at the borrow ceiling. Isolated ≠ safe — a fast collateral
  crash still liquidates through the bands.

## action: borrow_more
**Function:** `borrow_more(uint256 collateral, uint256 debt)`
**Contract:** role `controller` (registry: `credit/llamalend/<collateral>-controller`)
**Use when:** drawing MORE crvUSD against an existing loan (optionally adding collateral in the same call).

### params
- `collateral` — extra collateral to add now (may be `0`). `debt` — additional crvUSD to mint, to the vault.

### pitfalls
- Approve any added `collateral` to the `controller` first. Borrowing more without adding collateral pushes health
  toward the bands.
- The combined position must stay under `max_borrowable` for its band range — otherwise reverts.

### safety
- Any `borrow_more` **MUST leave health safely positive** with a buffer above the band range — refuse a draw that
  pushes the loan to the edge of soft liquidation.

## action: add_collateral
**Function:** `add_collateral(uint256 collateral)` (own loan; `add_collateral(uint256, address _for)` tops up another borrower).
**Contract:** role `controller` (registry: `credit/llamalend/<collateral>-controller`)
**Use when:** topping up collateral to raise health / step back from soft liquidation.

### params
- `collateral` — additional collateral in the collateral token's decimals. Use the single-arg form so the vault
  tops up its OWN loan.

### pitfalls
- Approve the added collateral to the `controller` first.
- The 2-arg `add_collateral(uint256, address)` with `_for` ≠ the vault adds collateral to someone else's loan — refuse.

### safety
- Adding collateral only improves health — the safe direction. Use it to recover a loan drifting into its bands.

## action: remove_collateral
**Function:** `remove_collateral(uint256 collateral)` (a `remove_collateral(uint256, bool)` variant toggles the callback path).
**Contract:** role `controller` (registry: `credit/llamalend/<collateral>-controller`)
**Use when:** WITHDRAWING collateral from a healthy loan (pulling excess collateral back to the vault).

### params
- `collateral` — collateral to remove (collateral-token decimals); the collateral is returned to `msg.sender` = the vault.

### pitfalls
- Removing collateral **lowers health** — it is the risk-increasing direction; the controller reverts a removal that
  would drop the loan into liquidation.
- While a loan is in soft liquidation the collateral is partly crvUSD (held in LLAMMA) — a removal may be limited.

### safety
- Only remove down to a buffer above the band range; never strip a loan to the edge of soft liquidation. Refuse a
  removal that would leave health non-positive.

## action: repay
**Function:** `repay(uint256 debt)` (own loan; `repay(uint256, address _for)` / `repay(uint256, address, int256)` variants repay for a borrower / with a band limit).
**Contract:** role `controller` (registry: `credit/llamalend/<collateral>-controller`)
**Use when:** paying down crvUSD debt to raise health, or closing the loan (full debt releases all collateral).

### params
- `debt` — crvUSD to repay (18 decimals); pass the full outstanding debt to close the loan cleanly. Approve `crvUSD`
  to the `controller` first (needs a crvUSD balance).

### pitfalls
- Repaying while in soft liquidation may settle partly in collateral — surface the realized state after.
- A `repay(uint256, address _for)` with `_for` ≠ the vault repays someone else's loan — refuse.

### safety
- Repay **before** `remove_collateral` when unwinding; a full repay releases all collateral back to the vault.
- `repay` (reducing debt) always improves health — allowed through the kill switch as a de-risking action.

## action: withdraw_supply
**Function:** `withdraw(uint256 assets, address receiver)` / `redeem(uint256 shares, address receiver)` — ERC4626, the LENDER exit.
**Contract:** role `vault` (registry: `credit/llamalend/<collateral>-vault`)
**Use when:** a LENDER pulls supplied crvUSD (plus accrued interest) back out.

### params
- `assets` (withdraw) or `shares` (redeem) — prefer `redeem` with the full share balance for a clean full exit.
- `receiver` — **the vault** (where the crvUSD lands).

### pitfalls
- If borrowers have drawn most of the liquidity, a withdraw is capped at the vault's idle crvUSD (`maxWithdraw`) —
  size to it or wait for repayments.
- `receiver` ≠ the vault leaks funds — refuse.

### safety
- Redeeming realizes the current share price (principal + accrued interest); there is no principal loss absent bad
  debt in that isolated market.
