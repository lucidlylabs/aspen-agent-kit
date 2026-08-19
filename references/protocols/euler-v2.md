---
protocol: euler-v2
category: credit
chains: [1, 8453, 42161]
archetype: lend_borrow
executor: knowledge-only
aliases:
  - "supply USDC to euler"
  - "earn yield on euler v2"
  - "borrow against my collateral on euler"
  - "lever up on an euler vault"
  - "repay my euler loan"
  - "withdraw from euler v2"
  - "deposit into an euler earn vault"
roles: [evault, evc]
actions: [deposit, withdraw, borrow, repay]
tokens: [USDC, USDT, WETH, wstETH]
---

# Euler v2 (EVK)

Euler v2 is built on the **Euler Vault Kit**: every market is its own ERC4626 **EVault** (role `evault`) for a
single underlying, and vaults are composed through the **Ethereum Vault Connector** (**EVC**, role `evc`),
which tracks each account's enabled **collaterals** and its one **controller** (the vault it borrows from).
You lend by depositing into a vault; you borrow by enabling that vault as your controller (via the EVC),
enabling one or more collateral vaults, then calling `borrow`. Health is evaluated by the controller across
the account's enabled collaterals.

> **executor: knowledge-only.** No engine executor runs this archetype yet; the harness will
> `needs_research` a Euler request until a `lend_borrow` executor exists. This file is the knowledge the
> author + future executor build against.

## action: deposit
**Function:** `deposit(uint256 amount, address receiver)`
**Contract:** role `evault` (registry: `credit/euler-v2/evault`)
**Use when:** lending an asset for yield, or supplying it to be used as collateral.

### params
- `amount` — in the underlying's decimals; scale from the token book, never a hardcoded 10^n. Pass
  `type(uint256).max` to deposit the vault's full balance of the asset.
- `receiver` — **MUST be the vault** (receives the minted eTokens/shares).

### pitfalls
- Approve the underlying to the `evault` first (ERC4626 pulls on `deposit`).
- Depositing alone is not collateral — to back a borrow you must also `enableCollateral` for this vault on
  the EVC.

### safety
- `receiver` ≠ the vault mints shares elsewhere — refuse.

## action: borrow
**Function:** `borrow(uint256 amount, address receiver)`
**Contract:** role `evault` (registry: `credit/euler-v2/evault`)
**Use when:** drawing a loan from a vault you've enabled as your controller.

### params
- `amount` — in the borrowed asset's decimals.
- `receiver` — **the vault** (where the borrowed tokens land).

### pitfalls
- Reverts unless, **on the EVC first**, this vault is `enableController`-ed for the account and the backing
  collateral vault(s) are `enableCollateral`-ed — those EVC calls must precede the borrow in the plan.
- An account may have only **one** controller at a time; a second concurrent borrow-vault will revert.

### safety
- `receiver` other than the vault leaks the loan — refuse.
- After the borrow the account **must stay above the controller's liquidation LTV** with a buffer; refuse a
  borrow that leaves health near the threshold.

## action: repay
**Function:** `repay(uint256 amount, address receiver)`
**Contract:** role `evault` (registry: `credit/euler-v2/evault`)
**Use when:** paying down debt on your controller vault to raise health or close the position.

### params
- `amount` — pass `type(uint256).max` to repay the **full** outstanding debt (no dust).
- `receiver` — the account whose debt is reduced: **the vault.** Approve the underlying to the `evault` first.

### pitfalls
- After a full repay, `disableController` on the EVC to free the account — otherwise it stays gated to that
  controller.

### safety
- Repay before withdrawing the collateral that backs it, or the withdraw breaches LTV and reverts.

## action: withdraw
**Function:** `withdraw(uint256 amount, address receiver, address owner)`
**Contract:** role `evault` (registry: `credit/euler-v2/evault`)
**Use when:** redeeming lent assets or un-posting collateral (plus accrued yield).

### params
- `amount` — amount of **underlying** to pull, in the asset's decimals; cap to the redeemable balance.
- `receiver` — **the vault.** `owner` — **the vault** (whose shares are burned).

### pitfalls
- Withdrawing collateral while the account has open debt reduces health and can **revert** — repay first.
- `owner` ≠ the vault needs an ERC4626 allowance you don't have — refuse.

### safety
- `receiver` other than the vault leaks funds — refuse; only withdraw down to the buffer above liquidation
  LTV while debt is open.
