---
protocol: origin-ether
category: yield
chains: [1, 8453]
archetype: deposit_vault
executor: knowledge-only
aliases:
  - "mint OETH with my ETH"
  - "get origin ether"
  - "earn the OETH yield"
  - "redeem my OETH back to ETH"
  - "wrap my OETH into wOETH"
  - "convert OETH to wOETH"
  - "unwrap wOETH"
roles: [vault, wrapper]
actions: [mint, redeem, wrap]
tokens: [WETH, OETH, wOETH]
---

# Origin Ether

Origin Ether (OETH) is a yield-bearing ETH token. You mint OETH by depositing a supported collateral
(e.g. WETH) into the **OETH Vault** (role `vault`); OETH is a **rebasing** token whose balance grows as
the vault's strategies earn yield. Redeeming burns OETH for a proportional mix of the vault's backing
assets. For contexts that need a **non-rebasing** balance (accounting, composability), OETH is wrapped
1-way into **wOETH**, an ERC4626 wrapper (role `wrapper`) whose share price rises instead of the balance.

> **executor: knowledge-only.** No engine executor runs the `deposit_vault` archetype yet; the harness
> will `needs_research` an Origin Ether request until one exists. This file is the knowledge the author +
> future executor build against.

## action: mint
**Function:** `mint(address _asset, uint256 _amount, uint256 _minimumOusdAmount)`
**Contract:** role `vault` (registry: `yield/origin-ether/vault`)
**Use when:** depositing a supported collateral to mint OETH and start earning the OETH yield.

### params
- `_asset` — the collateral token address (e.g. WETH), resolved from the token book by symbol; it must be
  a supported mint asset for the vault.
- `_amount` — in the collateral token's decimals; scale from the token book, never a hardcoded 10^n.
- `_minimumOusdAmount` — the min OETH to accept — a slippage floor. **Derive from a quote + slippage
  bound; never 0.** OETH mints to `msg.sender`, which MUST be the vault.

### pitfalls
- Approve the collateral to the `vault` first (approve leg must be in the plan).
- An unsupported `_asset` reverts — confirm the token is a mint asset before building the call.
- `_minimumOusdAmount = 0` is an unbounded mint — refuse; floor it.

### safety
- There is no `receiver` argument — OETH credits `msg.sender` (the vault); any other caller keeps the
  minted OETH, so the vault must be the caller.

## action: redeem
**Function:** `redeem(uint256 _amount, uint256 _minimumUnitAmount)`
**Contract:** role `vault` (registry: `yield/origin-ether/vault`)
**Use when:** burning OETH to withdraw a proportional basket of the vault's backing assets.

### params
- `_amount` — the **OETH** amount to burn (18 decimals). Use the full `balanceOf` for a full exit.
- `_minimumUnitAmount` — the min total unit value out — a slippage floor. **Never 0.**

### pitfalls
- `redeem` returns a **mix** of the vault's backing assets (a redeem basket), not necessarily pure WETH;
  if a single asset is required, a follow-on swap is needed — surface the expected basket.
- Large redeems can hit the vault's redeem-fee / buffer limits — size accordingly.

### safety
- The basket credits `msg.sender` (the vault). `_minimumUnitAmount = 0` accepts any value out — refuse.

## action: wrap
**Function:** `deposit(uint256 assets, address receiver)`
**Contract:** role `wrapper` (registry: `yield/origin-ether/wrapper`)
**Use when:** wrapping OETH into non-rebasing **wOETH** (ERC4626) — or unwrapping via `redeem`.

### params
- `assets` — the **OETH** amount to wrap (18 decimals). Approve OETH to the `wrapper` first.
- `receiver` — **MUST be the vault** (the wOETH shares mint to the wrapper's caller-of-record).
- To unwrap, call the wrapper's ERC4626 `redeem(uint256 shares, address receiver, address owner)` with
  `receiver` and `owner` both the vault.

### pitfalls
- Wrapping stops the rebase — wOETH balance stays flat while its **share price** rises; don't read a flat
  wOETH balance as "no yield."

### safety
- `receiver` (or `owner` on unwrap) ≠ the vault leaks the position — refuse.
