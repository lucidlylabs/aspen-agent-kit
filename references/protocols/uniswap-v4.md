---
protocol: uniswap-v4
category: dex
chains: [1, 8453, 42161, 10]
archetype: liquidity
executor: knowledge-only
aliases:
  - "open a uniswap v4 position"
  - "provide liquidity on uniswap v4"
  - "mint a v4 liquidity position"
  - "add liquidity to a uniswap v4 pool"
roles: [poolManager, positionManager, permit2]
actions: [mint]
tokens: [USDC, WETH]
---

# Uniswap v4

Uniswap v4 is architecturally unrelated to v2/v3: ALL pools live inside one singleton, hooks-enabled
**PoolManager** (role `poolManager`) — you never call a pool or a per-protocol NFT contract directly.
Liquidity actions go through the periphery **PositionManager** (role `positionManager`), which batches
one or more `Actions` (byte codes) with their ABI-encoded params into a single `modifyLiquidities(bytes
unlockData, uint256 deadline)` call; the PoolManager's `unlock()` requires every currency's net delta to
be zero (settled or taken) by the time the call ends, or the whole transaction reverts atomically.

> **executor: knowledge-only** for the harness's NL decomposer. **BUT the `lp` capability in
> `@aspen/sdk`'s generic compose engine has a `mint` block, built + offline-proven** (2026-07-15,
> `compose/v4Blocks.ts` + a dedicated `v4-mint` encode kind in `compose/encode.ts`) —
> `loadCatalog({ capabilities: ["lp"] })` opts `uniswap-v4_mint` in. There is still NO ENGINE EXECUTOR
> (same gap as Uniswap V3/SushiSwap V3's LP blocks). **Only `mint` is wired** — `increaseLiquidity`/
> `decreaseLiquidity`/`burn` need their own action-bundle verification (V4 typically pairs a removal with
> `TAKE_PAIR` to actually receive tokens, since nothing can be left mid-settled at the end of `unlock()`)
> and are a documented follow-up, not a silent gap. A wrong action bundle fails SAFE here — V4's
> zero-delta invariant means an incomplete sequence reverts atomically, it cannot half-execute.
>
> **No SushiSwap V4.** Sushi's lineup is V2 (classic AMM) + V3 (a Uniswap-v3-style concentrated-liquidity
> fork) — there is no third version. Don't conflate a request for "Sushi V4" with this protocol.

## action: mint
**Function:** `modifyLiquidities(bytes unlockData, uint256 deadline)` where `unlockData` encodes
`(bytes actions, bytes[] params)` — for a mint, `actions = 0x020d` (`MINT_POSITION` then `SETTLE_PAIR`,
from the `Actions` library) and `params[0]`/`params[1]` are each action's own ABI-encoded params:
- `MINT_POSITION` params: `(PoolKey poolKey, int24 tickLower, int24 tickUpper, uint256 liquidity, uint128 amount0Max, uint128 amount1Max, address owner, bytes hookData)`
  where `PoolKey = (address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks)`.
- `SETTLE_PAIR` params: `(address currency0, address currency1)` — the same pair, pays in whatever the
  mint actually owes for each side (no separate amount — it settles the position's own live delta).

**Contract:** role `positionManager` (registry: `dex/uniswap-v4/positionManager`)

**Use when:** opening a new liquidity position — mints an NFT (`tokenId`).

### params
- `currency0` / `currency1` — **MUST be sorted by address, ascending**, exactly like Uniswap V3's
  `token0`/`token1` — resolved by CODE, never the model. "Currency" here also covers native ETH
  (`address(0)` as `currency0`) — **this harness scopes that out**; ERC20/ERC20 pools only for now.
- `fee` — the pool fee tier; `tickSpacing` is a SEPARATE, independently-set field in V4 (pools with custom
  tickSpacing exist) — this harness derives it from `fee` via the conventional Uniswap tier map
  (100→1, 500→10, 3000→60, 10000→200), which assumes the pool was created with the standard spacing for
  that tier. A pool with a nonstandard tickSpacing needs it as an explicit param (not yet supported).
- `hooks` — the hook contract address for this pool; **this harness only mints into no-hook pools**
  (`address(0)`). A hook can arbitrarily change swap/liquidity behavior — never guess or default to a
  nonzero hooks address.
- `tickLower` / `tickUpper` — full-range only for now (computed by code from `tickSpacing`, same as
  Uniswap V3's full-range mint).
- `liquidity` — **V4's mint takes a target liquidity value DIRECTLY**, unlike V3's amount-denominated
  `mint` — there is no `amount0Desired`/`amount1Desired` here. Computing the "correct" liquidity for a
  desired token spend needs the pool's LIVE price (a `runtime` seam this harness doesn't have yet), so
  today it's a raw literal the caller supplies.
- `amount0Max` / `amount1Max` — **the REAL safety bound.** Whatever `liquidity` is requested, `_pay` (via
  Permit2) can never pull more than these. Must be > 0 on both sides.
- `owner` — **MUST be the trading wallet itself** (the minted position's owner).

### pitfalls
- **Funds move via Permit2, not a plain ERC20 allowance.** `_pay` calls `permit2.transferFrom(payer,
  poolManager, amount, token)` — the wallet needs BOTH a standing `ERC20.approve(permit2Address, amt)`
  AND a `Permit2.approve(token, positionManager, amt, expiration)` (Permit2's own, time-bound allowance)
  before `modifyLiquidities` will succeed. A plain `approve(positionManager, amt)` does nothing here.
- `currency0`/`currency1` in the wrong (unsorted) order reverts (PoolKey validation).
- A `liquidity` value whose required token amounts exceed `amount0Max`/`amount1Max` reverts — safe (no
  funds move), but size `liquidity` conservatively without a live price read.
- Minting into a pool with a nonzero `hooks` address you haven't verified could behave arbitrarily on
  liquidity add — only mint into pools you've confirmed are hookless.

### safety
- `owner` other than the wallet gives a third party control over the position — refuse.
- `amount0Max`/`amount1Max` both being generous "just in case" numbers defeats the point of the bound —
  size them to what you actually intend to spend.
