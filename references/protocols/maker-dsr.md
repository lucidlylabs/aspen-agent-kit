---
protocol: maker-dsr
category: yield
chains: [1, 8453]
archetype: deposit_vault
executor: knowledge-only
aliases:
  - "earn the dai savings rate"
  - "put DAI in the DSR"
  - "deposit DAI into sDAI"
  - "earn yield on my DAI"
  - "stake DAI for the savings rate"
  - "redeem sDAI back to DAI"
  - "withdraw from the DSR"
  - "convert DAI to sDAI"
roles: [savings, dsrManager]
actions: [deposit, redeem, join]
tokens: [DAI, sDAI, USDC]
---

# Maker DSR

The Maker **Dai Savings Rate (DSR)** pays a variable rate on DAI parked in the protocol's `pot`. The
DeFi-native way in is **sDAI** — an **ERC4626 vault** (role `savings`) whose asset is DAI: deposit DAI, mint
sDAI, and the DSR accrues in the sDAI share price (no claim step). An alternative, non-tokenized path is the
**DSR Manager** (role `dsrManager`), which joins/exits the `pot` directly and tracks a per-address DAI
balance. sDAI is the recommended path; the DSR Manager is documented for parity.

> **executor: knowledge-only.** No engine executor runs the `deposit_vault` archetype yet; the harness will
> `needs_research` a DSR request until one exists. This file is the knowledge the author + future executor
> build against.

## action: deposit
**Function:** `deposit(uint256 assets, address receiver)`
**Contract:** role `savings` (registry: `yield/maker-dsr/savings`)
**Use when:** parking DAI to earn the DSR via the tokenized sDAI vault.

### params
- `assets` — the DAI amount in **18 decimals**; scale from the token book, never a hardcoded 10^n.
- `receiver` — **MUST be the vault's own address.** The minted sDAI lands here.

### pitfalls
- Approve DAI to the `savings` (sDAI) contract first (approve leg must be in the plan).
- This vault takes **DAI**, not USDC — swap/PSM USDC→DAI first if the user holds USDC.
- `receiver` ≠ the vault mints sDAI to someone else — refuse.

### safety
- DSR yield is in the sDAI share price; there is no claim. `redeem` realizes it.

## action: redeem
**Function:** `redeem(uint256 shares, address receiver, address owner)`
**Contract:** role `savings` (registry: `yield/maker-dsr/savings`)
**Use when:** exiting the DSR — burn sDAI for DAI + accrued yield.

### params
- `shares` — the sDAI amount to burn; pass the full sDAI balance for a dustless full exit.
- `receiver` — **the vault** (where DAI lands). `owner` — **the vault** (whose sDAI is burned).

### pitfalls
- `receiver`/`owner` other than the vault leaks funds — pin both to the vault.
- To pull a precise DAI amount instead, use `withdraw(uint256 assets, address receiver, address owner)`.

### safety
- `redeem(fullBalance)` is the clean close; a fixed `withdraw` amount leaves residual shares.

## action: join
**Function:** `join(address dst, uint256 wad)`
**Contract:** role `dsrManager` (registry: `yield/maker-dsr/dsr-manager`)
**Use when:** using the non-tokenized DSR Manager path instead of sDAI.

### params
- `dst` — **MUST be the vault** (the account credited with the DSR position).
- `wad` — the DAI amount (18 decimals). Approve DAI to the `dsrManager` first.
- Exit later with `exit(address dst, uint256 wad)` or `exitAll(address dst)`, `dst` = the vault.

### pitfalls
- `dst` ≠ the vault credits the DSR balance to another account — refuse.
- The DSR Manager balance is NOT an ERC20 (unlike sDAI) — it cannot be used as collateral elsewhere.

### safety
- Prefer sDAI (`savings`) unless a caller specifically needs the pot-direct path; it is composable and dustless.
