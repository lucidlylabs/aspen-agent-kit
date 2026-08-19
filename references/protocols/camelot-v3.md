---
protocol: camelot-v3
category: dex
chains: [42161]
archetype: swap
executor: knowledge-only
aliases:
  - "swap on camelot"
  - "swap USDC for WETH on camelot"
  - "trade on camelot v3"
  - "buy GRAIL on arbitrum"
  - "market buy WETH on camelot"
  - "price a camelot swap"
roles: [router, quoter]
actions: [exactInputSingle, quoteExactInputSingle]
tokens: [USDC, WETH, ARB, GRAIL]
---

# Camelot v3

Camelot v3 is the leading Algebra-based concentrated-liquidity DEX on **Arbitrum** (chain 42161). Algebra
pools have a single **dynamic** fee (adaptive) — so the swap struct has **no `fee` field** and uses
`limitSqrtPrice` (not `sqrtPriceLimitX96`) and carries a `deadline`. We use the **SwapRouter** (role
`router`) to swap and the **QuoterV2** (role `quoter`) to price off-chain.

> **executor: knowledge-only.** No engine executor runs a Camelot / Algebra archetype yet (the live
> `swap_tp_sl` executor is bound to Uniswap-v3 addresses and its `fee`-tier struct). The harness will
> `needs_research` a Camelot request until an Algebra router is wired. This file is the knowledge that
> executor is built against.

## action: exactInputSingle
**Function:** `exactInputSingle((address tokenIn, address tokenOut, address recipient, uint256 deadline, uint256 amountIn, uint256 amountOutMinimum, uint160 limitSqrtPrice))`
**Contract:** role `router` (registry: `dex/camelot-v3/router`)
**Use when:** entering the position (spend `tokenIn`, receive `tokenOut`) and, symmetrically, exiting it.

### params
- `tokenIn` / `tokenOut` — resolved from the token book by symbol; `tokenIn != tokenOut`. **No `fee` field** —
  Algebra selects the single dynamic-fee pool for the pair automatically.
- `recipient` — **MUST be the trading wallet / vault itself.** Never a third party.
- `deadline` — a near-future timestamp; not `type(uint256).max`.
- `amountIn` — in `tokenIn`'s decimals; scale from the token book, never a hardcoded 10^n.
- `amountOutMinimum` — the slippage floor. Derive it from a fresh `quoter` read and `maxSlippageBps`;
  **never leave it at 0.**
- `limitSqrtPrice` — `0` to disable the price limit (rely on `amountOutMinimum` for protection).

### pitfalls
- Do NOT reuse a Uniswap-v3 struct (with `fee` / `sqrtPriceLimitX96`) — the Algebra field set differs; a
  mismatched ABI encodes garbage.
- `recipient` other than self donates the output — refuse.
- `amountOutMinimum = 0` is an unbounded-slippage swap — refuse; floor it from the quote.
- The entry approve (`tokenIn` → `router`) must be in the plan or the swap reverts / is default-DENYed.

### safety
- Price the exit with `quoter` immediately before sending; the adaptive fee makes stale quotes drift faster.
- The output token must be swept home to the vault on close.

## action: quoteExactInputSingle
**Function:** `quoteExactInputSingle(address tokenIn, address tokenOut, uint256 amountIn, uint160 limitSqrtPrice)`
**Contract:** role `quoter` (registry: `dex/camelot-v3/quoter`)
**Use when:** pricing the entry (to floor `amountOutMinimum`) and evaluating a take-profit / stop-loss on each tick.

### params
- `tokenIn` / `tokenOut` / `amountIn` as in the swap; **no `fee`** (dynamic-fee pool). Read-only. `limitSqrtPrice` — `0`.

### pitfalls
- The quoter is **read-only** (`eth_call`), never a signed-tx destination — do not add it to the plan targets.

### safety
- Quotes are point-in-time and the fee is adaptive; re-read on the tick you act on, not once at creation.
