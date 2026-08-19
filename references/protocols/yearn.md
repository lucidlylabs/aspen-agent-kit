---
protocol: yearn
category: yield
chains: [1]
archetype: vault
executor: knowledge-only
aliases:
  - "deposit into yearn"
  - "put USDC in yearn"
  - "earn yield on yearn"
  - "mint yvUSDC"
  - "stake USDC in yearn"
  - "farm yield with yearn"
  - "withdraw from yearn"
  - "redeem yvUSDC"
  - "get yvUSDC"
  - "unstake from yearn"
roles: [yvUSDC]
actions: [mint, redeem]
tokens: [USDC, yvUSDC]
---

# Yearn

Yearn (docs.yearn.fi) is a yield-aggregator protocol: it runs a large family of **per-asset, per-chain V3
vaults**, each an independent **ERC4626** contract that auto-allocates deposits across one or more
underlying strategies (lending markets, LP positions, other vaults) and auto-compounds the yield into the
vault's rising share price. Unlike Ethena/Sky/Cap — each a single canonical stablecoin vault — Yearn has
**no one vault**: there is a distinct vault per asset, and often several competing vaults for the SAME
asset (different strategy mixes, different risk). **Only one vault is registered here: `yvUSDC` — the
"USDC-1" V3 vault**, the highest-TVL, Yearn-endorsed USDC vault on Ethereum. A request naming a different
Yearn vault (a different asset, a different USDC vault, or Yearn on another chain) must `needs_research`
until that vault is verified and added the same way — never assume a sibling vault shares this one's
address or behavior.

Two vault "kinds" exist in V3: **Allocator Vaults** (deposit an asset, the vault allocates across an array
of strategies — what `yvUSDC` is) and **Tokenized Strategies** (a single yield source, itself also
ERC4626 and directly depositable). Both expose the identical `deposit`/`mint`/`withdraw`/`redeem` ERC4626
surface, so this card's actions apply to either kind — only the registry role differs per vault.

> **executor: knowledge-only.** The `yearn_mint`/`yearn_redeem` actions below ARE already composable graph
> blocks (`compose/vaultBlocks.ts`, gated behind `loadCatalog({ capabilities: ["vault"] })`, the same
> pattern as Ethena/Sky/Cap) — they just have no live composer/engine executor entry point yet. A Yearn
> request `needs_research`s until one exists.

## action: mint
**Function:** `deposit(uint256 assets, address receiver)`
**Contract:** role `yvUSDC` (registry: `yield/yearn/yvUSDC`)
**Use when:** depositing USDC into the vault to mint yvUSDC and start earning the vault's yield.

### params
- `assets` — the **USDC** amount to deposit (USDC decimals = 6); scale from the token book, never a
  hardcoded 10^n.
- `receiver` — **MUST be the vault's own address** (the minted yvUSDC must land with the depositor).

### pitfalls
- Approve USDC to the `yvUSDC` contract first (approve leg must be in the plan).
- yvUSDC is the receipt — it is not USDC 1:1; the rate (`pricePerShare`) rises as the underlying strategies
  report gains, and can also **fall** if a strategy reports a loss (see `## action: redeem` below).
- A vault can be **deposit-capped** (a configurable `deposit_limit` / deposit-limit module) — a deposit
  above the remaining headroom reverts rather than partially filling; don't assume an arbitrary amount lands.

### safety
- `receiver` ≠ self mints the yvUSDC elsewhere — refuse.

## action: redeem
**Function:** `redeem(uint256 shares, address receiver, address owner, uint256 maxLoss)` — the EXTENDED
Yearn V3 selector (not the bare 3-arg ERC4626 `redeem`; see the pitfall below for why).
**Contract:** role `yvUSDC` (registry: `yield/yearn/yvUSDC`)
**Use when:** burning yvUSDC shares for the USDC (principal + accrued yield) they're currently worth.

### params
- `shares` — the **yvUSDC** amount to redeem (6 decimals, matching USDC); use the full `balanceOf` for a
  clean full exit.
- `receiver` / `owner` — **MUST both be the vault's own address**: `owner` = self-redeem (no ERC20/share
  approval needed when `msg.sender == owner`); `receiver` is where the released USDC lands.
- `maxLoss` — basis points of acceptable loss versus the share's ideal value, **pinned to `0` by the
  compose block** (no loss tolerated) — see the pitfall below. This mirrors Yearn's own `withdraw()`
  default, not `redeem()`'s.

### pitfalls
- **The plain 3-arg ERC4626 `redeem(shares, receiver, owner)` is dangerous on a Yearn V3 vault.** Vyper's
  default-argument overloading means that selector still exists and is callable, but it implicitly fills
  `maxLoss` with `MAX_BPS` (10000 = **accept up to 100% loss**) — the opposite of `withdraw()`, whose
  default is `0`. The wired block therefore ALWAYS encodes the explicit 4-arg selector with `maxLoss` fixed
  at `0`; never reach for the bare 3-arg selector on this protocol.
- A `maxLoss` of `0` means the redeem **reverts** if the vault would realize any loss at withdrawal time
  (e.g. an underlying strategy is mid-loss and hasn't been reported/covered yet) — this is a deliberate
  fail-closed choice, not a bug; a stuck redeem should be retried later, not reissued with a looser
  tolerance.
- Redeeming can pull from **multiple underlying strategies** to fill a large request — normal for a
  multi-strategy vault, no action needed by the caller.

### safety
- `receiver`/`owner` ≠ the vault leaks the redeemed USDC or someone else's shares — refuse.
- **Never encode a non-zero `maxLoss` from a model-supplied number.** The value is a protocol-safety
  parameter, not a strategy input — it is fixed by the block, not user- or model-suppliable.
- Yearn vaults are third-party-strategy risk: unlike Ethena/Sky's single well-audited mechanism, `yvUSDC`'s
  yield comes from a rotating set of underlying strategies (lending markets, other vaults) that can, in
  principle, report a loss — the `maxLoss:0` pin is the load-bearing protection against silently eating one.
