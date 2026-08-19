---
protocol: sushi
category: dex
chains: [1, 8453, 42161, 10]
archetype: aggregator_swap
executor: live
aliases:
  - "swap on sushi"
  - "sushi swap"
  - "sushiswap"
  - "trade on sushi"
  - "aggregator swap"
  - "best price swap"
  - "swap with best execution"
roles: [router]
actions: [swap]
tokens: [USDC, WETH]
---

# Sushi (aggregator)

Sushi's **Swap API** (`docs.sushi.com`) is a DEX-aggregation API — it routes a swap across Sushi's own AMM
pools and other on-chain liquidity for best execution and returns **ready, opaque calldata** in one call
(no separate route/build step). It is one candidate in the harness's **quote-off** against 0x, KyberSwap,
fly.trade, and Bebop — highest guaranteed `minOut` wins, chosen by measurement, not by the model.

The execution contract (Sushi's RedSnwapper / RouteProcessor) is **both** the transaction target and the
approve spender (a standard ERC20 `approve`, no Permit2) — deployed at the SAME address on every chain, and
**pinned to the vetted registry** (the `router` role; the API cannot redirect it). The built transaction
must **pass simulation** (recipient == wallet, output delta ≥ `minOut`, no residual approval) before it is
signed.

## action: swap

Swap `tokenIn` for `tokenOut` on a single chain, spending a fixed `amountIn`, with a slippage floor
(`maxSlippage`). Same-chain only — not for cross-chain (that is a bridge). Good general-purpose candidate
in the quote-off alongside the other three aggregators.
