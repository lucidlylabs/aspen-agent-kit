---
protocol: bebop
category: dex
chains: [1, 8453, 42161]
archetype: aggregator_swap
executor: live
aliases:
  - "bebop"
  - "bebop aggregation"
  - "bebop jam"
  - "solver auction swap"
  - "aggregator swap"
  - "best price swap"
  - "swap with best execution"
roles:
  - settlement
  - approvalTarget
actions:
  - swap
tokens:
  - USDC
  - WETH
---

Bebop's Aggregation (JAM) API runs a **solver auction** — multiple solvers compete to fill an order across
all available on-chain liquidity, giving broad token coverage. It is one candidate in the harness's
**quote-off** against 0x, KyberSwap, and fly.trade — highest guaranteed `minOut` wins.

Self-execution mode returns ready **opaque calldata**. The approve target (`approvalTarget` role) is
**distinct** from the settlement contract (`settlement` role) — both are **pinned to the vetted registry**
(Bebop may rotate them, so an unlisted address fails closed until the registry is updated). The built
transaction must **pass simulation** before signing.

## action: swap

Swap `tokenIn` for `tokenOut` on one chain for a fixed `amountIn` with a slippage tolerance. Good for
long-tail pairs (solver auction reaches liquidity a single pool cannot). Same-chain only.
