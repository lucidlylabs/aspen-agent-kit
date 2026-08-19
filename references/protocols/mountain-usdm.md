---
protocol: mountain-usdm
category: yield
chains: [1, 8453, 42161, 10]
archetype: deposit_vault
executor: knowledge-only
aliases:
  - "wrap USDM into wUSDM"
  - "put USDM in wUSDM for yield"
  - "earn yield on USDM"
  - "deposit USDM into wUSDM"
  - "hold a non-rebasing yield stablecoin"
  - "unwrap wUSDM back to USDM"
  - "redeem my wUSDM"
roles: [wrapper, token]
actions: [deposit, redeem, withdraw]
tokens: [USDM, wUSDM, USDC]
---

# Mountain USDM

**USDM** is Mountain Protocol's yield-bearing stablecoin, backed by short-term US Treasuries. USDM is a
**rebasing** token — the yield shows up as a growing USDM balance (like stETH), which many contracts handle
poorly. **wUSDM** (role `wrapper`) is the non-rebasing wrapper: a standard **ERC4626 vault** whose asset is
USDM, so yield accrues in the wUSDM share price and the balance is fixed. Wrapping into wUSDM is the
composable, DeFi-safe way to hold the position. Minting fresh USDM from USDC is gated (KYC on Mountain) and
is not an on-chain action here — acquire USDM, then wrap.

> **executor: knowledge-only.** No engine executor runs the `deposit_vault` archetype yet; the harness will
> `needs_research` a USDM request until one exists. This file is the knowledge the author + future executor
> build against.

## action: deposit
**Function:** `deposit(uint256 assets, address receiver)`
**Contract:** role `wrapper` (registry: `yield/mountain-usdm/wrapper`)
**Use when:** wrapping rebasing USDM into non-rebasing, yield-accruing wUSDM.

### params
- `assets` — the USDM amount in **18 decimals**; scale from the token book, never a hardcoded 10^n.
- `receiver` — **MUST be the vault's own address.** The minted wUSDM lands here.

### pitfalls
- Approve USDM to the `wrapper` (wUSDM) contract first (approve leg must be in the plan).
- Depositing raw USDC won't work — this vault's asset is **USDM**; the user must already hold USDM.
- `receiver` ≠ the vault mints wUSDM to someone else — refuse.

### safety
- Hold wUSDM (not raw USDM) anywhere the position touches other contracts — rebasing USDM breaks fixed-balance
  accounting. Yield is in the wUSDM share price; there is no claim step.

## action: redeem
**Function:** `redeem(uint256 shares, address receiver, address owner)`
**Contract:** role `wrapper` (registry: `yield/mountain-usdm/wrapper`)
**Use when:** unwrapping wUSDM back to USDM (yield included) — the clean full exit.

### params
- `shares` — the wUSDM amount to burn; pass the full wUSDM balance for a dustless exit.
- `receiver` — **the vault** (where USDM lands). `owner` — **the vault** (whose wUSDM is burned).

### pitfalls
- `receiver`/`owner` other than the vault leaks funds — pin both to the vault.

### safety
- `redeem(fullBalance)` returns all principal + accrued yield in USDM; convert USDM→USDC separately if needed.

## action: withdraw
**Function:** `withdraw(uint256 assets, address receiver, address owner)`
**Contract:** role `wrapper` (registry: `yield/mountain-usdm/wrapper`)
**Use when:** pulling a specific USDM amount out while keeping the rest wrapped.

### params
- `assets` — the exact USDM amount wanted out (18 decimals). The vault burns the needed wUSDM.
- `receiver` — **the vault.** `owner` — **the vault.**

### pitfalls
- The vault's wUSDM must cover the requested `assets` or it reverts; for a full exit prefer `redeem`.
- Withdrawing to a `receiver` other than the vault leaks funds — refuse.

### safety
- Use `redeem` for a full close (dustless); `withdraw` for a partial pull that leaves the remainder earning.
