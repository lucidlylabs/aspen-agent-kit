---
protocol: uniswap-v3
category: dex
chains: [1, 10, 8453, 42161]
archetype: swap_tp_sl
executor: live
aliases:
  - "buy ETH with USDC"
  - "swap USDC for WETH"
  - "go long ETH and take profit"
  - "buy the dip with a stop loss"
  - "market buy WETH, take profit at 1%"
  - "long WETH close at +0.5%"
  - "provide liquidity to USDC/WETH on uniswap"
  - "add liquidity to a uniswap v3 pool"
  - "open an LP position on uniswap"
  - "top up my uniswap LP position"
  - "remove liquidity from my uniswap position"
  - "collect my uniswap LP fees"
  - "close my uniswap LP position"
roles: [router, quoter, npm]
actions: [exactInputSingle, quoteExactInputSingle, mint, increaseLiquidity, decreaseLiquidity, collect, burn]
tokens: [USDC, WETH]
---

# Uniswap v3

Uniswap v3 is a concentrated-liquidity DEX. On Base we use **SwapRouter02** (role `router`) to execute a
single-hop swap and **QuoterV2** (role `quoter`) to price it off-chain. This is the protocol behind the
live `swap_tp_sl` archetype: buy one token with another at market, then watch and close on a
take-profit / stop-loss / deadline condition.

> **LP actions below (`mint`/`increaseLiquidity`/`decreaseLiquidity`/`collect`/`burn`) — the COMPOSE
> BLOCKS are built and offline-proven (2026-07-15, `compose/clBlocks.ts`), but there is still NO ENGINE
> EXECUTOR.** `loadCatalog({ capabilities: ["lp"] })` opts them into the graph checker/encoder (proven
> byte-exact against the real NPM ABI, `clBlocks.dryrun.ts`), but the strategy-engine driver doesn't yet
> tick a stored LP graph — the harness still `needs_research`s an "add liquidity" prompt until that
> lands (mirrors how `lend_borrow`'s blocks landed before its engine wiring — see
> `docs/adding-a-primitive-or-protocol.md`). The **`npm` role** (NonfungiblePositionManager) is
> registry-verified on all four chains (double-checked against
> `developers.uniswap.org/contracts/v3/reference/deployments` **and** the `INonfungiblePositionManager`
> interface source, 2026-07-15).
>
> **Why this isn't a drop-in `makeVaultBlocks()`-style factory.** Two things a fungible-share ERC4626
> vault doesn't have: (1) a position here is an **NFT** (`tokenId`), not a fungible balance — the engine
> has no NFT-output tracking yet, so `tokenId` is a LITERAL the caller must already know on
> `increaseLiquidity`/`decreaseLiquidity`/`collect`/`burn` (a `{ref}` from `mint`'s output is refused,
> fail-closed, until that tracking lands); (2) `mint` needs a **token0/token1 ADDRESS SORT** (Uniswap's
> own convention — which of tokenA/tokenB is token0 differs per chain) with the amount args permuted in
> tandem — a cross-arg dependency the generic per-arg provenance resolver can't express, so `mint`/
> `increaseLiquidity` use a bespoke `cl-liquidity` encode kind instead of the plain `abi` struct system
> (see `compose/primitive.ts`). `mint` is **FULL-RANGE ONLY** for now (`tickLower`/`tickUpper` computed
> by code from the fee tier's fixed `tickSpacing` — no price read needed); a narrower, price-centered
> range needs a live pool-price `runtime` seam, like the swap quoter's `minOut`, and is a follow-up.

## action: exactInputSingle
**Function:** `exactInputSingle((address tokenIn, address tokenOut, uint24 fee, address recipient, uint256 amountIn, uint256 amountOutMinimum, uint160 sqrtPriceLimitX96))`
**Contract:** role `router` (registry: `dex/uniswap-v3/router`)
**Use when:** entering the position (spend `tokenIn`, receive `tokenOut`) and, symmetrically, exiting it.

### params
- `tokenIn` / `tokenOut` — resolved from the token book by symbol; `tokenIn != tokenOut`.
- `fee` — the pool fee tier (500 = 0.05%, 3000 = 0.30%, 10000 = 1.00%). Default 500.
- `recipient` — **MUST be the trading wallet itself** (the funded dangling wallet / vault). Never a third party.
- `amountIn` — in `tokenIn`'s decimals; scale from the token book, never a hardcoded 10^n.
- `amountOutMinimum` — the slippage floor. Derive it from a fresh `quoter` read and `maxSlippageBps`;
  **never leave it at 0.**

### pitfalls
- `recipient` other than self donates the output — refuse.
- `amountOutMinimum = 0` is an unbounded-slippage swap — refuse; floor it from the quote.
- The entry approve (`tokenIn` → `router`) must be in the plan or the swap reverts / is default-DENYed.

### safety
- Price the exit with `quoter` immediately before sending; a stale quote widens real slippage past the bound.
- The output token must be swept home to the vault on close (`autoSweepOnClose`).

## action: quoteExactInputSingle
**Function:** `quoteExactInputSingle((address tokenIn, address tokenOut, uint256 amountIn, uint24 fee, uint160 sqrtPriceLimitX96))`
**Contract:** role `quoter` (registry: `dex/uniswap-v3/quoter`)
**Use when:** pricing the entry (to floor `amountOutMinimum`) and evaluating the take-profit / stop-loss on each tick.

### params
- Same tuple shape as the swap, minus `recipient`/`amountOutMinimum`. Read-only.

### pitfalls
- The quoter is **read-only** (`eth_call`), never a signed-tx destination — it is deliberately NOT in the
  transaction allowlist. Do not add it to the plan targets.

### safety
- Quotes are point-in-time; re-read on the tick you act on, not once at creation.

## action: mint
**Function:** `mint((address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address recipient, uint256 deadline))`
**Contract:** role `npm` (registry: `dex/uniswap-v3/npm`, NonfungiblePositionManager — Base uses a
**distinct** address from the other three chains; verified per-chain, not assumed shared)
**Use when:** opening a new LP position — deposits `token0`+`token1` into a fresh pool position and
mints an NFT (`tokenId`) representing it.

### params
- `token0` / `token1` — **MUST be sorted by address, ascending** (`token0 < token1` as `uint160`).
  Uniswap's own convention, not user intent — a pair can flip which symbol is `token0` **per chain**,
  since the same symbol's address differs across chains. This is a code-level sort at encode time
  (compare the two resolved addresses), never a static per-block mapping.
- `fee` — the pool's fee tier (500 / 3000 / 10000); must match a pool that actually exists, or `mint`
  reverts (or silently deploys a fresh, liquidity-less pool at that tier — check `token0`/`token1`/`fee`
  resolves to a known/verified pool, not "any tier the model names").
- `tickLower` / `tickUpper` — must be **multiples of the fee tier's `tickSpacing`** (10 for 500, 60 for
  3000, 200 for 10000) or `mint` reverts. Full-range = `MIN_TICK`/`MAX_TICK` (`-887272`/`887272`)
  rounded to the nearest valid multiple of `tickSpacing` — a fixed constant per tier, no price read
  needed. A **narrower, price-centered** range needs a live pool-price read (the tick equivalent of the
  swap quoter) to place bounds around the current price; don't compute ticks from a guessed price.
- `amount0Desired` / `amount1Desired` — in each token's own decimals; the pool only pulls the ratio the
  current price implies, so the unused side is refunded, not force-spent.
- `amount0Min` / `amount1Min` — the slippage floor on each side; **never leave both at 0** on a pool with
  live trading between the quote and the send.
- `recipient` — **MUST be the trading wallet itself** — the position NFT (and later
  `increaseLiquidity`/`decreaseLiquidity`/`collect`/`burn` authority) mints there.
- `deadline` — a near-future timestamp; a stale mint reverts rather than executing at a moved price.

### pitfalls
- Approve **both** `token0` and `token1` to the `npm` contract first (two approve legs).
- Passing `token0`/`token1` in the wrong (unsorted) order reverts.
- `amount0Min`/`amount1Min` both `0` is an unbounded-slippage LP entry — refuse.
- The returned `tokenId` is the ONLY handle for every later action on this position — it must be
  recorded (the compose engine's node-output tracking, not a fungible balance).

### safety
- `recipient` other than the wallet gives a third party sole control (increase/decrease/collect/burn
  authority) over the position — refuse.
- A pool with abnormally low liquidity/skewed price is a common LP-drain vector; don't mint into a pool
  that hasn't been sanity-checked against a reference price.

## action: increaseLiquidity
**Function:** `increaseLiquidity((uint256 tokenId, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, uint256 deadline))`
**Contract:** role `npm` (registry: `dex/uniswap-v3/npm`)
**Use when:** adding more `token0`/`token1` to an **existing** position (same `tokenId`, same tick range
and fee tier as when it was minted — the range itself can't change).

### params
- `tokenId` — the position to top up; fed from the `mint` node's output, not a literal.
- `amount0Desired` / `amount1Desired`, `amount0Min` / `amount1Min`, `deadline` — same semantics as `mint`.

### pitfalls
- The caller must be the `tokenId`'s owner/approved — only works on a position this wallet minted.
- Same unbounded-slippage risk as `mint` if both mins are left at 0.

### safety
- Commits fresh capital into an already-open position (contract + price risk) — treat like `mint`.

## action: decreaseLiquidity
**Function:** `decreaseLiquidity((uint256 tokenId, uint128 liquidity, uint256 amount0Min, uint256 amount1Min, uint256 deadline))`
**Contract:** role `npm` (registry: `dex/uniswap-v3/npm`)
**Use when:** withdrawing liquidity from a position — full or partial exit, the first of a two-step
removal (this only moves the underlying tokens from "locked in the position" to "owed and claimable";
`collect` below is the step that actually sends them to the wallet).

### params
- `tokenId` — fed from the `mint` node's output.
- `liquidity` — the amount of the position's **liquidity units** to remove, not a token amount (read the
  position's current `liquidity` via `positions(tokenId)` for a full exit; there's no "percent" arg).
- `amount0Min` / `amount1Min` — slippage floor on the amounts released; never both 0.
- `deadline` — as above.

### pitfalls
- `decreaseLiquidity` does **not** transfer tokens — they accrue as `tokensOwed0`/`tokensOwed1` on the
  position until `collect` is called. A close sequence is `decreaseLiquidity` → `collect`, always both.
- `liquidity` greater than the position currently holds reverts.

### safety
- De-risking (returns capital toward the exit) — `intent: reduce`, always allowed through the kill switch.

## action: collect
**Function:** `collect((uint256 tokenId, address recipient, uint128 amount0Max, uint128 amount1Max))`
**Contract:** role `npm` (registry: `dex/uniswap-v3/npm`)
**Use when:** claiming tokens already owed on a position — released principal from a prior
`decreaseLiquidity`, and/or accrued trading fees, without touching remaining liquidity.

### params
- `tokenId` — fed from the `mint` node's output.
- `recipient` — **MUST be the trading wallet itself**.
- `amount0Max` / `amount1Max` — the cap on what to collect; `type(uint128).max` on each = "collect
  everything owed" (this is the standard "collect all" idiom, not an unbounded-slippage floor — there's
  no price/slippage involved in a collect, only a withdrawal cap).

### pitfalls
- `recipient` other than the wallet donates the claimed tokens/fees — refuse.
- Collecting fees alone (no prior `decreaseLiquidity`) is valid and doesn't touch the position's liquidity.

### safety
- Pure withdrawal of already-owed funds — `intent: reduce`, always allowed through the kill switch.

## action: burn
**Function:** `burn(uint256 tokenId)`
**Contract:** role `npm` (registry: `dex/uniswap-v3/npm`)
**Use when:** closing out a fully-emptied position — burns the NFT itself, the last step after a full
`decreaseLiquidity` + `collect`.

### params
- `tokenId` — fed from the `mint` node's output.

### pitfalls
- **Reverts unless the position's liquidity is 0 AND both `tokensOwed0`/`tokensOwed1` are 0** — a full
  `decreaseLiquidity` (all liquidity) followed by a full `collect` must run first, in that order.

### safety
- Pure cleanup of an already-emptied position, no funds move — `intent: reduce`.
