---
protocol: velodrome
category: dex
chains: [10]
archetype: swap
executor: knowledge-only
aliases:
  - "swap on velodrome"
  - "swap USDC for WETH on velodrome"
  - "trade VELO on optimism"
  - "swap through a stable pool on velodrome"
  - "provide liquidity on velodrome"
  - "add liquidity to a velodrome pair"
roles: [router]
actions: [swapExactTokensForTokens, addLiquidity]
tokens: [USDC, WETH, VELO]
---

# Velodrome

Velodrome is the dominant Solidly-fork DEX on **Optimism** (chain 10) — the same architecture Aerodrome
forked for Base, with volatile and stable pools. Swaps go through the **Router** (role `router`) using an
explicit `Route[]` path; each hop names the pair's `stable` flag and factory, so the pool type must be known.

> **executor: knowledge-only.** No engine executor runs a Velodrome archetype yet (the live `swap_tp_sl`
> executor is Uniswap-v3-specific). The harness will `needs_research` a Velodrome request until a
> Solidly-router executor exists. This file is the knowledge that executor is built against.

## action: swapExactTokensForTokens
**Function:** `swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, (address from, address to, bool stable, address factory)[] routes, address to, uint256 deadline)`
**Contract:** role `router` (registry: `dex/velodrome/router`)
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
**Contract:** role `router` (registry: `dex/velodrome/router`)
**Use when:** depositing a token pair to mint LP tokens for a volatile or stable pool.

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
