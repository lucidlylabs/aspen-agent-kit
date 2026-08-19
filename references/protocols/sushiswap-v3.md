---
protocol: sushiswap-v3
category: dex
chains: [1, 8453, 42161, 10]
archetype: swap
executor: knowledge-only
aliases:
  - "swap on sushiswap"
  - "swap USDC for WETH on sushi"
  - "trade on sushiswap v3"
  - "buy SUSHI with USDC"
  - "market buy WETH on sushi"
  - "price a sushiswap swap"
  - "provide liquidity to USDC/WETH on sushiswap v3"
  - "add liquidity to a sushiswap v3 pool"
  - "open an LP position on sushiswap"
  - "top up my sushiswap LP position"
  - "remove liquidity from my sushiswap position"
  - "collect my sushiswap LP fees"
  - "close my sushiswap LP position"
roles: [router, quoter, npm]
actions: [exactInputSingle, quoteExactInputSingle, mint, increaseLiquidity, decreaseLiquidity, collect, burn]
tokens: [USDC, WETH, SUSHI]
---

# SushiSwap v3

SushiSwap v3 is a concentrated-liquidity DEX (a Uniswap-v3 fork) deployed across many chains. We use the
v3 **SwapRouter** (role `router`) to execute a single-hop swap and **QuoterV2** (role `quoter`) to price
it off-chain. Sushi's SwapRouter uses the original Uniswap-v3 struct — it **includes a `deadline` field**.

> **executor: knowledge-only.** No engine executor runs a SushiSwap archetype yet (the live `swap_tp_sl`
> executor is bound to Uniswap-v3 addresses). The harness will `needs_research` a SushiSwap request until
> its router is wired. This file is the knowledge that executor is built against.
>
> **LP actions (`mint`/`increaseLiquidity`/`decreaseLiquidity`/`collect`/`burn`) — the COMPOSE BLOCKS are
> built and offline-proven** (2026-07-15, `compose/clBlocks.ts` — the SAME generic factory Uniswap V3
> uses, `makeConcentratedLiquidityBlocks()`, since SushiSwap V3's NonfungiblePositionManager is a
> byte-identical Uniswap V3 fork — confirmed against the `sushi` npm package's own `TICK_SPACINGS`/fee-tier
> map). `loadCatalog({ capabilities: ["lp"] })` opts `sushiswap-v3_mint` etc. in; there is still NO ENGINE
> EXECUTOR (same gap as Uniswap V3's LP actions — see `skills/uniswap-v3.md` for the full design
> writeup: full-range-only `mint`, the token0/token1 address-sort, the NFT-tokenId tracking gap). The
> `npm` role is registry-verified on all 4 chains (double-verified against the `sushi` npm package's
> published config AND each chain's block-explorer verified-contract name, 2026-07-15).

## action: exactInputSingle
**Function:** `exactInputSingle((address tokenIn, address tokenOut, uint24 fee, address recipient, uint256 deadline, uint256 amountIn, uint256 amountOutMinimum, uint160 sqrtPriceLimitX96))`
**Contract:** role `router` (registry: `dex/sushiswap-v3/router`)
**Use when:** entering the position (spend `tokenIn`, receive `tokenOut`) and, symmetrically, exiting it.

### params
- `tokenIn` / `tokenOut` — resolved from the token book by symbol; `tokenIn != tokenOut`.
- `fee` — the pool fee tier (500 = 0.05%, 3000 = 0.30%, 10000 = 1.00%); resolve to a pool with liquidity.
- `recipient` — **MUST be the trading wallet / vault itself.** Never a third party.
- `deadline` — a near-future timestamp; not `type(uint256).max`. (Sushi's struct carries `deadline`, unlike
  Uniswap's SwapRouter02.)
- `amountIn` — in `tokenIn`'s decimals; scale from the token book, never a hardcoded 10^n.
- `amountOutMinimum` — the slippage floor. Derive it from a fresh `quoter` read and `maxSlippageBps`;
  **never leave it at 0.**
- `sqrtPriceLimitX96` — `0` to disable the price limit (rely on `amountOutMinimum`).

### pitfalls
- The struct field order differs from Uniswap's SwapRouter02 (`deadline` is present) — encode against the
  actual Sushi ABI, not the Uniswap one.
- `recipient` other than self donates the output — refuse.
- `amountOutMinimum = 0` is an unbounded-slippage swap — refuse; floor it from the quote.
- The entry approve (`tokenIn` → `router`) must be in the plan or the swap reverts / is default-DENYed.

### safety
- Price the exit with `quoter` immediately before sending; a stale quote widens real slippage past the bound.
- The output token must be swept home to the vault on close.

## action: quoteExactInputSingle
**Function:** `quoteExactInputSingle((address tokenIn, address tokenOut, uint256 amountIn, uint24 fee, uint160 sqrtPriceLimitX96))`
**Contract:** role `quoter` (registry: `dex/sushiswap-v3/quoter`)
**Use when:** pricing the entry (to floor `amountOutMinimum`) and evaluating a take-profit / stop-loss on each tick.

### params
- Same tuple shape as the swap, minus `recipient`/`deadline`/`amountOutMinimum`. Read-only; `fee` must match
  the pool you'll trade.

### pitfalls
- The quoter is **read-only** (`eth_call`), never a signed-tx destination — do not add it to the plan targets.

### safety
- Quotes are point-in-time; re-read on the tick you act on, not once at creation.

## action: mint
**Function:** `mint((address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address recipient, uint256 deadline))`
**Contract:** role `npm` (registry: `dex/sushiswap-v3/npm`, NonfungiblePositionManager — same struct shape
as Uniswap V3's own NPM, unlike the swap router's reordered struct)
**Use when:** opening a new LP position — deposits `token0`+`token1` into a fresh pool position and mints
an NFT (`tokenId`) representing it.

See `skills/uniswap-v3.md`'s `## action: mint` for the full params/pitfalls/safety writeup — byte-identical
semantics (token0/token1 must be address-sorted ascending, resolved by code; tickLower/tickUpper must be
multiples of the fee tier's tickSpacing; amount mins must never both be 0; recipient MUST be the wallet).

## action: increaseLiquidity
**Function:** `increaseLiquidity((uint256 tokenId, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, uint256 deadline))`
**Contract:** role `npm` (registry: `dex/sushiswap-v3/npm`)
**Use when:** adding more `token0`/`token1` to an existing position (same `tokenId`, same tick range/fee
tier as when it was minted). See `skills/uniswap-v3.md` for the full writeup.

## action: decreaseLiquidity
**Function:** `decreaseLiquidity((uint256 tokenId, uint128 liquidity, uint256 amount0Min, uint256 amount1Min, uint256 deadline))`
**Contract:** role `npm` (registry: `dex/sushiswap-v3/npm`)
**Use when:** withdrawing liquidity from a position — the first of a two-step removal (`collect` below is
the step that sends the released tokens to the wallet). See `skills/uniswap-v3.md` for the full writeup.

## action: collect
**Function:** `collect((uint256 tokenId, address recipient, uint128 amount0Max, uint128 amount1Max))`
**Contract:** role `npm` (registry: `dex/sushiswap-v3/npm`)
**Use when:** claiming tokens already owed on a position (released principal and/or accrued fees).
`amount0Max`/`amount1Max` = `type(uint128).max` is the standard "collect everything" idiom, not a
slippage floor. `recipient` MUST be the wallet.

## action: burn
**Function:** `burn(uint256 tokenId)`
**Contract:** role `npm` (registry: `dex/sushiswap-v3/npm`)
**Use when:** closing out a fully-emptied position — reverts unless liquidity is 0 AND both
`tokensOwed0`/`tokensOwed1` are 0 (a full `decreaseLiquidity` + `collect` must run first).
