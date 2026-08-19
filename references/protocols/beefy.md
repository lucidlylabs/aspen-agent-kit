---
protocol: beefy
category: vault
chains: [1, 8453, 42161, 10]
archetype: deposit_vault
executor: knowledge-only
aliases:
  - "deposit into a beefy vault"
  - "auto-compound my LP on beefy"
  - "put my tokens in a beefy moo vault"
  - "farm with beefy"
  - "withdraw from my beefy vault"
  - "withdraw all from beefy"
  - "beefy yield optimizer"
roles: [vault]
actions: [deposit, depositAll, withdraw, withdrawAll]
tokens: [USDC, WETH, USDT]
---

# Beefy

Beefy vaults are auto-compounding yield optimizers. You deposit a "want" token (a single asset or an LP
token) and receive **mooTokens** (vault shares); the vault farms an underlying pool and periodically
harvests + reinvests rewards, so the share price (`getPricePerFullShare`) rises. Each vault is its own
contract for one "want" token (role `vault`), resolved per want-token from the registry. Beefy's classic
vault is **ERC4626-like but not strict ERC4626**: `deposit`/`withdraw` take only an amount and act for
`msg.sender` — there is no `receiver`/`owner` argument, so the **caller (the vault) is always the holder**.

> **executor: knowledge-only.** No engine executor runs the `deposit_vault` archetype yet; the harness
> will `needs_research` a Beefy request until one exists. This file is the knowledge the author + future
> executor build against.

## action: deposit
**Function:** `deposit(uint256 _amount)`
**Contract:** role `vault` (registry: `vault/beefy/vault`)
**Use when:** putting a specific amount of the "want" token into a Beefy vault to auto-compound.

### params
- `_amount` — in the **want token's** decimals; scale from the token book, never a hardcoded 10^n.
- **No `receiver` argument** — mooTokens mint to `msg.sender`, which MUST be the vault. Never route a
  Beefy deposit through a caller other than the vault, since the shares follow the caller.

### pitfalls
- Approve the want token to the `vault` first (approve leg must be in the plan).
- The want token must equal the vault's `want()` — for LP vaults that means the exact pool LP token, not
  its underlyings; the LP must be acquired first. A wrong want-token reverts / is refused.

### safety
- Because the holder is `msg.sender`, the vault contract itself must be the caller — an agent-driven
  `vault.manage` satisfies this; any other caller keeps the shares — refuse.

## action: depositAll
**Function:** `depositAll()`
**Contract:** role `vault` (registry: `vault/beefy/vault`)
**Use when:** depositing the vault's entire want-token balance in one call.

### params
- No args — deposits `want.balanceOf(msg.sender)`. Approve the want token to the `vault` first.

### pitfalls
- Deposits the **full** balance; if you meant to keep a reserve, use `deposit(_amount)` instead.

### safety
- Same holder rule: `msg.sender` (the vault) holds the mooTokens.

## action: withdraw
**Function:** `withdraw(uint256 _shares)`
**Contract:** role `vault` (registry: `vault/beefy/vault`)
**Use when:** pulling out a specific number of **mooToken shares** (not want-token amount).

### params
- `_shares` — the **mooToken** amount to burn (share decimals), NOT the want-token amount. Read
  `balanceOf` and convert via `getPricePerFullShare` to reason about the want-token you'll receive.

### pitfalls
- Passing a want-token amount where shares are expected withdraws the wrong quantity — `withdraw` burns
  **shares**. Be explicit about which unit the number is in.

### safety
- The want token returns to `msg.sender` (the vault). Any other caller receives the funds — refuse.

## action: withdrawAll
**Function:** `withdrawAll()`
**Contract:** role `vault` (registry: `vault/beefy/vault`)
**Use when:** fully exiting — burns the caller's entire mooToken balance for a clean full close.

### params
- No args — burns `balanceOf(msg.sender)` and returns all want-token to the vault.

### safety
- Prefer `withdrawAll` over `withdraw` for a full exit — it leaves no share dust and needs no unit math.
