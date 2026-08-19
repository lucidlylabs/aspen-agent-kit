---
protocol: odos
category: dex
chains: [1, 8453, 42161, 10]
archetype: swap
executor: knowledge-only
aliases:
  - "swap on odos"
  - "best price swap USDC to WETH"
  - "aggregate a swap across DEXes with odos"
  - "route my swap for best execution"
  - "swap with the odos aggregator"
  - "smart order route my trade"
roles: [router]
actions: [swap]
tokens: [USDC, WETH, USDT]
---

# Odos (aggregator)

Odos is a smart-order-routing DEX aggregator: its **OdosRouterV2** (role `router`) executes a route that
is computed **off-chain by the Odos API** (`https://docs.odos.xyz/`). The route lives in an opaque
`pathDefinition` blob plus an `executor` helper address; on-chain you call one function, `swap`, with a
`swapTokenInfo` struct that carries the input/output tokens, amounts, and the min-output floor.

> **executor: knowledge-only.** No engine executor runs the aggregator archetype yet (the live `swap_tp_sl`
> executor is Uniswap-v3-specific). The harness will `needs_research` an Odos request until an aggregator
> executor exists. This file is the knowledge that executor is built against.
>
> **Note on the API dependency:** `pathDefinition` and the `executor` address are opaque outputs of an
> off-chain quote. An aggregator executor must fetch a FRESH quote at execution time and MUST re-derive
> `outputMin` from the slippage bound rather than trusting the API's `outputQuote` echo — the same "code
> decides the bound, not the model" rule, extended to a third-party quote.

## action: swap
**Function:** `swap((address inputToken, uint256 inputAmount, address inputReceiver, address outputToken, uint256 outputQuote, uint256 outputMin, address outputReceiver) tokenInfo, bytes pathDefinition, address executor, uint32 referralCode)`
**Contract:** role `router` (registry: `dex/odos/router`)
**Use when:** swapping one token for another at best aggregated price across many DEXes.

### params
- `tokenInfo.inputToken` / `tokenInfo.outputToken` — resolved from the token book by symbol; `inputToken != outputToken`.
- `tokenInfo.inputAmount` — the input amount, in `inputToken`'s decimals; scale from the token book, never a hardcoded 10^n.
- `tokenInfo.outputReceiver` — **MUST be the trading wallet / vault itself.** Anyone else drains the output.
- `tokenInfo.outputMin` — the slippage floor. **Derive it from the fresh quote + `maxSlippageBps`; never 0.**
  Do not trust `outputQuote` (the API's estimate) as the floor.
- `pathDefinition` / `executor` — opaque route bytes + helper address from the Odos API quote. Do not hand-craft.
- `referralCode` — `0` unless a registered referral is intended.

### pitfalls
- `outputReceiver` other than self donates the whole output — refuse.
- `outputMin = 0` (or set equal to `outputQuote` with no slippage margin) is an unbounded/under-protected
  swap — refuse; floor it below the quote by the slippage bound.
- A stale `pathDefinition` routes against moved liquidity and can revert or slip badly — re-quote at send time.
- `inputReceiver` is the Odos-side pull target from the quote — approve exactly `inputAmount`, not unlimited.

### safety
- The src-token approve (`inputToken` → the router / `inputReceiver` per the quote) must be in the plan or
  the swap reverts / is default-DENYed. Approve the exact amount and sweep any standing allowance to 0 on close.
- The output token must be swept home to the vault on close.
