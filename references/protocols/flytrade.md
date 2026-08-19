---
protocol: flytrade
category: dex
chains: [1, 8453, 42161]
archetype: aggregator_swap
executor: live
aliases:
  - "fly.trade"
  - "flytrade"
  - "fly"
  - "magpie"
  - "aggregator swap"
  - "best price swap"
  - "swap with best execution"
roles:
  - dexAggregator
  - core
actions:
  - swap
tokens:
  - USDC
  - WETH
---

fly.trade (Magpie under the hood) is a DEX aggregator that routes a swap across venues for best execution.
It is one candidate in the harness's **quote-off** against 0x, KyberSwap, and Bebop — highest guaranteed
`minOut` wins, chosen by measurement, not by the model.

The Aggregator API returns **opaque calldata** (combined quote + transaction). Note: tokens must be approved
to **both** the DexAggregator and its Core contract (Magpie pulls funds through Core) — both are **pinned to
the vetted registry** (`dexAggregator` + `core` roles). The transaction target is pinned to the
DexAggregator, and the built transaction must **pass simulation** before it is signed.

## action: swap

Swap `tokenIn` for `tokenOut` on one chain for a fixed `amountIn` with a slippage floor. Same-chain only.
