---
protocol: aerodrome
category: dex
chains: [8453]
archetype: swap
executor: knowledge-only
aliases:
  - "swap on aerodrome"
  - "swap USDC for WETH on aerodrome"
  - "trade AERO on base"
  - "swap through a stable pool on aerodrome"
  - "provide liquidity on aerodrome"
  - "add liquidity to an aerodrome pair"
  - "remove liquidity from an aerodrome pool"
  - "stake my aerodrome LP tokens"
  - "stake AERO-USDC LP for emissions"
  - "unstake my aerodrome gauge position"
  - "claim my AERO rewards"
  - "earn AERO emissions on aerodrome"
roles: [router, factory, voter, gauge]
actions: [swapExactTokensForTokens, addLiquidity, removeLiquidity, stake, unstake, claimRewards]
tokens: [USDC, WETH, AERO]
---

# Aerodrome

Aerodrome is the dominant Solidly-fork DEX on **Base** (chain 8453), with both volatile and stable
(low-slippage, like-priced) pools. Swaps go through the **Router** (role `router`), which takes an
explicit `Route[]` path — each hop names the pair's `stable` flag and factory, so you must know whether
the pool is a stable or volatile pool. Every pool is ALSO its own ERC20 **LP token** (Solidly-style, like a
Uniswap V2 pair), and can OPT IN to AERO emissions via a per-pool **Gauge** spawned by the **Voter** (role
`voter`) — stake the LP token in the gauge to earn AERO, on top of swap fees.

> **executor: knowledge-only** for the harness's NL decomposer (no engine executor runs an Aerodrome
> archetype there yet — the live `swap_tp_sl` executor is Uniswap-v3-specific). **BUT the `lp` capability
> in `@aspen/sdk`'s generic compose engine is BUILT + offline-proven** (`compose/aerodromeBlocks.ts`):
> `add_liquidity` / `remove_liquidity` (via the Router) and `stake_lp` / `unstake_lp` / `claim_rewards`
> (via a pool's Gauge, resolved from the LP token symbol) are real, encodable graph primitives —
> `loadCatalog({ capabilities: ["lp"] })` opts them in. Two curated pools ship today (`AERO-USDC`,
> `USDC-WETH`, both VOLATILE — stable pools aren't wired yet), verified directly on-chain (not scraped);
> the long tail resolves via on-chain discovery (`compose/aerodromeDiscover.ts`, always `verified: false`
> until a pool is promoted into the curated registry). This file is the knowledge those blocks are built
> against; a plain-English Aerodrome prompt through the NL harness still `needs_research` until a decomposer
> executor is wired on top.

## action: swapExactTokensForTokens
**Function:** `swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, (address from, address to, bool stable, address factory)[] routes, address to, uint256 deadline)`
**Contract:** role `router` (registry: `dex/aerodrome/router`)
**Use when:** swapping an exact `amountIn` of one token for another along a `routes` path.

### params
- `routes` — the hop list; each `(from, to, stable, factory)` names the pair. `from`/`to` resolve from the
  token book; `stable` MUST match the actual pool type (stable vs volatile) or it routes to the wrong pool.
- `amountIn` — the input amount, in the first hop's `from` decimals; scale from the token book, never a hardcoded 10^n.
- `amountOutMin` — the slippage floor on the final output. Derive it from `getAmountsOut(amountIn, routes)`
  and `maxSlippageBps`; **never leave it at 0.**
- `to` — **MUST be the trading wallet / vault itself.** Never a third party.
- `deadline` — a near-future timestamp; not `type(uint256).max`.

### pitfalls
- Approve the first-hop `from` token to the `router` first (approve leg must be in the plan) or it reverts / is default-DENYed.
- A wrong `stable` flag routes to a non-existent or wrong pool and reverts or slips badly — resolve it per pair.
- `amountOutMin = 0` is an unbounded-slippage swap — refuse; floor it from a fresh `getAmountsOut`.
- `to` other than self donates the output — refuse.

### safety
- Re-read `getAmountsOut` immediately before sending; a stale quote widens real slippage past the bound.
- The output token lands with `to` = the vault; confirm it is the vault and swept home on close.

## action: addLiquidity
**Function:** `addLiquidity(address tokenA, address tokenB, bool stable, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`
**Contract:** role `router` (registry: `dex/aerodrome/router`)
**Use when:** depositing a token pair to mint LP tokens for a volatile or stable pool.

> The compose block (`add_liquidity`) currently hardcodes `stable=false` (VOLATILE pools only) — see
> "Compose blocks vs. this reference" below.

### params
- `tokenA` / `tokenB` — resolved from the token book. `stable` — MUST match the target pool type.
- `amountADesired` / `amountBDesired` — the amounts you'd contribute, each in its own decimals.
- `amountAMin` / `amountBMin` — the minimum actually deposited per side (slippage floors against a moving
  ratio). Derive from the pool reserves and the bound; **never both 0.**
- `to` — **the vault** (who receives the LP tokens). `deadline` — near-future.

### pitfalls
- Approve BOTH `tokenA` and `tokenB` to the `router` first.
- The router deposits at the current reserve ratio and refunds the excess side — size `amountAMin`/`amountBMin`
  to bound how much ratio drift you accept; zeroing them accepts any ratio.
- `to` other than the vault leaks the LP position — refuse.

### safety
- LP tokens are minted to `to` = the vault; confirm no third-party recipient.
- The unused portion of one side is refunded to the vault; account for it in the expected delta.

## action: removeLiquidity
**Function:** `removeLiquidity(address tokenA, address tokenB, bool stable, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`
**Contract:** role `router` (registry: `dex/aerodrome/router`)
**Use when:** burning LP tokens to withdraw the underlying `tokenA`/`tokenB` pair.

### params
- `tokenA` / `tokenB` / `stable` — must match the pool the LP token belongs to.
- `liquidity` — the LP token amount to burn, in the LP token's OWN decimals (18dp — the pool IS its own
  ERC20). Approve the LP token to the `router` first.
- `amountAMin` / `amountBMin` — the minimum you'll accept back per side; **never both 0.**
- `to` — **the vault**. `deadline` — near-future.

### pitfalls
- Approve the LP token (not `tokenA`/`tokenB`) to the `router` — a common mix-up.
- A wrong `tokenA`/`tokenB`/`stable` triple resolves to the WRONG pool's LP token and reverts.

### safety
- Underlying tokens land with `to` = the vault; confirm no third-party recipient.

## action: stake (gauge deposit)
**Function:** `deposit(uint256 amount)` (a `deposit(uint256, address)` variant stakes on behalf of a `recipient`)
**Contract:** role `gauge` — PER-POOL, resolved via `Voter.gauges(pool)` (registry: curated `<pair>-gauge`
rows, e.g. `dex/aerodrome/AERO-USDC-gauge`; long-tail pools resolve via on-chain discovery)
**Use when:** staking a pool's LP tokens into its Gauge to earn AERO emissions on top of swap fees.

### params
- `amount` — LP tokens to stake, in the LP token's decimals (18dp). Approve the LP token to the **gauge**
  first (not the router).

### pitfalls
- Staking into the WRONG pool's gauge (a mismatched LP token address) reverts — the gauge only accepts its
  own pool's LP token.
- A pool that never opted into emissions has no gauge at all (`Voter.gauges(pool) == address(0)`) — staking
  isn't possible; verify via discovery before attempting.

### safety
- The staked position still carries the pool's IL/price risk — the gauge only adds emissions, it doesn't
  reduce the underlying LP risk.

## action: unstake (gauge withdraw)
**Function:** `withdraw(uint256 amount)`
**Contract:** role `gauge` (same per-pool resolution as `stake`)
**Use when:** withdrawing staked LP tokens back to the wallet (does NOT auto-claim rewards — call
`claimRewards` separately, or before, to not leave AERO unclaimed).

### params
- `amount` — LP tokens to unstake, in the LP token's decimals. Burns your own gauge balance — no approval needed.

### safety
- Unstaking does not burn the LP position itself — you still hold the LP token afterward (call
  `removeLiquidity` on the router if you also want the underlying `tokenA`/`tokenB` back).

## action: claimRewards (gauge getReward)
**Function:** `getReward(address account)`
**Contract:** role `gauge` (same per-pool resolution as `stake`)
**Use when:** claiming accrued AERO emission rewards for a staked position.

### params
- `account` — **MUST be the trading wallet / vault itself.** Never a third party (rewards pay out to `account`).

### safety
- No approval needed; a claim for an account with zero accrued rewards is a harmless no-op.

## Compose blocks vs. this reference
`@aspen/sdk`'s `compose/aerodromeBlocks.ts` (the `lp` capability) encodes `addLiquidity`/`removeLiquidity`/
`stake`/`unstake`/`claimRewards` above as graph primitives (`add_liquidity`, `remove_liquidity`, `stake_lp`,
`unstake_lp`, `claim_rewards`). Two narrowings vs. the full reference, both documented as follow-ups in the
block source:
- **Volatile pools only** (`stable` is hardcoded `false`) — the generic encoder's `user-input` provenance
  has no representation for a bare ABI `bool`, only a `fixed` literal does; every pool curated today is
  volatile, so this costs nothing yet.
- **`amountAMin`/`amountBMin` and `deadline` are plain literals**, not reserve-derived/live values — no
  reserves-read seam exists yet (mirrors how LlamaLend's blocks also ship with literal amounts before an
  executor is wired).
