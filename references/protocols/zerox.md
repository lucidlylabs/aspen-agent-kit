---
protocol: zerox
category: dex
chains: [1, 8453, 42161, 10]
archetype: aggregator_swap
executor: live
aliases:
  - "0x"
  - "zeroex"
  - "0x swap"
  - "swap with best execution"
  - "aggregator swap"
  - "best price swap"
roles:
  - allowanceHolder
actions:
  - swap
tokens:
  - USDC
  - WETH
---

0x is a DEX aggregation API that routes a swap across many on-chain venues for best execution. Prefer an
aggregator like this over calling a single AMM pool directly: it splits and routes across liquidity sources
to return more output than any one pool. The venue is not a decision the model should make — the harness runs
a **quote-off** across all eligible aggregators (0x, KyberSwap, fly.trade, Bebop) and takes the highest
guaranteed `minOut`. 0x is one candidate in that race.

The v2 Swap API (AllowanceHolder flow) returns **opaque calldata**: the harness does not build the bytes, it
fetches them. Because of that, two guardrails are load-bearing — the swap target and approve spender are
**pinned to the vetted registry** (the `allowanceHolder` role; the API cannot redirect them), and the built
transaction must **pass simulation** (recipient == wallet, output delta ≥ `minOut`, no residual approval)
before it is signed.

## action: swap

Swap `tokenIn` for `tokenOut` on a single chain, spending a fixed `amountIn`, with a slippage floor. The
AllowanceHolder contract is both the approve spender and the transaction target. Use for any token-to-token
swap where best execution matters (size, long-tail pairs). Not for cross-chain — that is a bridge.
