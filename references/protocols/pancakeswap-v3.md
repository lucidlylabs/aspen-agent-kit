---
protocol: pancakeswap-v3
category: dex
chains: [1, 56, 8453, 42161]
archetype: swap
executor: knowledge-only
aliases:
  - "swap on pancakeswap"
  - "swap USDC for WETH on pancakeswap"
  - "buy CAKE with USDC"
  - "trade on pancakeswap v3"
  - "market buy WETH on pancakeswap"
  - "price a pancakeswap swap"
  - "provide liquidity to USDC/WETH on pancakeswap v3"
  - "add liquidity to a pancakeswap v3 pool"
  - "open a concentrated liquidity position on pancakeswap"
  - "top up my pancakeswap v3 lp position"
  - "remove liquidity from my pancakeswap position"
  - "collect my pancakeswap lp fees"
  - "close my pancakeswap v3 position"
roles: [router, quoter, npm, factory]
actions: [exactInputSingle, quoteExactInputSingle, mint, increaseLiquidity, decreaseLiquidity, collect, burn]
tokens: [USDC, WETH, CAKE]
---

# PancakeSwap v3

PancakeSwap v3 is a concentrated-liquidity DEX (a Uniswap-v3 fork) with its own fee tiers. We use the
**SmartRouter / SwapRouter** (role `router`) to execute a single-hop swap and **QuoterV2** (role `quoter`)
to price it off-chain. The `exactInputSingle` struct matches Uniswap's SwapRouter02 shape (no `deadline`
field in the struct).

> **executor: knowledge-only.** No engine executor runs a PancakeSwap archetype yet (the live `swap_tp_sl`
> executor is bound to Uniswap-v3 addresses). The harness will `needs_research` a PancakeSwap request until
> its router is wired. This file is the knowledge that executor is built against.
>
> **LP actions (`mint`/`increaseLiquidity`/`decreaseLiquidity`/`collect`/`burn`) — the COMPOSE BLOCKS are
> built and offline-proven** (`compose/clBlocks.ts` — the SAME generic factory Uniswap V3 / SushiSwap V3
> use, `makeConcentratedLiquidityBlocks()`, since PancakeSwap V3's NonfungiblePositionManager is a
> byte-identical Uniswap V3 fork). `loadCatalog({ capabilities: ["lp"] })` opts `pancakeswap-v3_mint` etc.
> in; there is still NO ENGINE EXECUTOR (same gap as Uniswap/Sushi V3 LP). The **ONE divergence** is the
> fee-tier map: PancakeSwap replaces Uniswap's 0.30% tier with its own **0.25% tier (fee 2500 → tickSpacing
> 50**, VERIFIED on-chain via `PancakeV3Factory.feeAmountTickSpacing(2500) = 50`), wired centrally in
> `compose/clMath.ts`'s `CL_TICK_SPACING`. `npm` + `factory` are registry-verified on ETH/Base/Arbitrum (a
> live `eth_call` of `NonfungiblePositionManager.factory()` matched the registered Factory on each).

## action: mint
**Function:** `mint((address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address recipient, uint256 deadline))`
**Contract:** role `npm` (registry: `dex/pancakeswap-v3/npm`, NonfungiblePositionManager — same struct
shape as Uniswap V3's own NPM, unlike the swap router's reordered struct)
**Use when:** opening a new LP position — deposits `token0`+`token1` into a fresh pool position and mints
an NFT (`tokenId`) representing it.

See `skills/uniswap-v3.md`'s `## action: mint` for the full params/pitfalls/safety writeup — byte-identical
semantics (token0/token1 must be address-sorted ascending, resolved by code; tickLower/tickUpper must be
multiples of the fee tier's tickSpacing — note PancakeSwap's 2500→50 tier; amount mins must never both be
0; recipient MUST be the wallet).

## action: increaseLiquidity
**Function:** `increaseLiquidity((uint256 tokenId, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, uint256 deadline))`
**Contract:** role `npm` (registry: `dex/pancakeswap-v3/npm`)
**Use when:** adding more `token0`/`token1` to an existing position (same `tokenId`, same tick range/fee
tier as when it was minted). See `skills/uniswap-v3.md` for the full writeup.

## action: decreaseLiquidity
**Function:** `decreaseLiquidity((uint256 tokenId, uint128 liquidity, uint256 amount0Min, uint256 amount1Min, uint256 deadline))`
**Contract:** role `npm` (registry: `dex/pancakeswap-v3/npm`)
**Use when:** withdrawing liquidity from a position — the first of a two-step removal (`collect` sends the
released tokens to the wallet). See `skills/uniswap-v3.md` for the full writeup.

## action: collect
**Function:** `collect((uint256 tokenId, address recipient, uint128 amount0Max, uint128 amount1Max))`
**Contract:** role `npm` (registry: `dex/pancakeswap-v3/npm`)
**Use when:** claiming tokens already owed on a position (released principal and/or accrued fees).
`amount0Max`/`amount1Max` = `type(uint128).max` is the standard "collect everything" idiom, not a
slippage floor. `recipient` MUST be the wallet.

## action: burn
**Function:** `burn(uint256 tokenId)`
**Contract:** role `npm` (registry: `dex/pancakeswap-v3/npm`)
**Use when:** closing out a fully-emptied position — reverts unless liquidity is 0 AND both
`tokensOwed0`/`tokensOwed1` are 0 (a full `decreaseLiquidity` + `collect` must run first).

## action: exactInputSingle
**Function:** `exactInputSingle((address tokenIn, address tokenOut, uint24 fee, address recipient, uint256 amountIn, uint256 amountOutMinimum, uint160 sqrtPriceLimitX96))`
**Contract:** role `router` (registry: `dex/pancakeswap-v3/router`)
**Use when:** entering the position (spend `tokenIn`, receive `tokenOut`) and, symmetrically, exiting it.

### params
- `tokenIn` / `tokenOut` — resolved from the token book by symbol; `tokenIn != tokenOut`.
- `fee` — the pool fee tier (PancakeSwap v3 tiers: 100 = 0.01%, 500 = 0.05%, 2500 = 0.25%, 10000 = 1.00%).
  Resolve to a pool that actually has liquidity — the tiers differ from Uniswap's.
- `recipient` — **MUST be the trading wallet / vault itself.** Never a third party.
- `amountIn` — in `tokenIn`'s decimals; scale from the token book, never a hardcoded 10^n.
- `amountOutMinimum` — the slippage floor. Derive it from a fresh `quoter` read and `maxSlippageBps`;
  **never leave it at 0.**
- `sqrtPriceLimitX96` — `0` to disable the price limit (rely on `amountOutMinimum` for protection).

### pitfalls
- Picking a `fee` tier with no/low liquidity reverts or slips badly — resolve to a funded pool.
- `recipient` other than self donates the output — refuse.
- `amountOutMinimum = 0` is an unbounded-slippage swap — refuse; floor it from the quote.
- The entry approve (`tokenIn` → `router`) must be in the plan or the swap reverts / is default-DENYed.

### safety
- Price the exit with `quoter` immediately before sending; a stale quote widens real slippage past the bound.
- The output token must be swept home to the vault on close.

## action: quoteExactInputSingle
**Function:** `quoteExactInputSingle((address tokenIn, address tokenOut, uint256 amountIn, uint24 fee, uint160 sqrtPriceLimitX96))`
**Contract:** role `quoter` (registry: `dex/pancakeswap-v3/quoter`)
**Use when:** pricing the entry (to floor `amountOutMinimum`) and evaluating a take-profit / stop-loss on each tick.

### params
- Same tuple shape as the swap, minus `recipient`/`amountOutMinimum`. Read-only; `fee` must match the pool you'll trade.

### pitfalls
- The quoter is **read-only** (`eth_call`), never a signed-tx destination — do not add it to the plan targets.
- Quoting a different `fee` tier than the swap prices the wrong pool — keep them consistent.

### safety
- Quotes are point-in-time; re-read on the tick you act on, not once at creation.
