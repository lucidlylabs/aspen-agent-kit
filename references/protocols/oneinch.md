---
protocol: oneinch
category: dex
chains: [1, 8453, 42161, 10]
archetype: aggregator_swap
executor: knowledge-only
aliases:
  - "swap on 1inch"
  - "best price swap USDC to WETH"
  - "aggregate my swap across DEXes with 1inch"
  - "route my trade for best execution on 1inch"
  - "swap with the 1inch aggregator"
  - "smart order route this swap"
roles: [router, routerV5]
actions: [swap, uniswapV3Swap]
tokens: [USDC, WETH, USDe]
---
# 1inch

1inch is a DEX aggregator: it splits a single swap across many liquidity venues to get the best net output, then settles through its AggregationRouter. Aspen tracks the current router (V6, role `router`) and the still-widely-used prior router (V5, role `routerV5`); the V5 router shares one address across Ethereum, Base, Arbitrum, and Optimism, while V6 is registered on Ethereum. This is the `aggregator_swap` archetype: the route/calldata is produced off-chain by the 1inch API and the router only executes it under caller-supplied minimum-output protection.

> **executor: knowledge-only.** No engine executor runs the `aggregator_swap` archetype yet (the live `swap_tp_sl` executor is Uniswap-v3-specific). The harness will `needs_research` a 1inch request until a matching executor exists. This file is the knowledge that executor is built against.

## action: swap
**Function:** `swap(address executor, (address srcToken, address dstToken, address srcReceiver, address dstReceiver, uint256 amount, uint256 minReturnAmount, uint256 flags) desc, bytes permit, bytes data)`
**Contract:** role `router` (registry: `dex/oneinch/router`)
**Use when:** executing a full aggregated swap whose route was quoted by the 1inch API — the general case for "best price swap X to Y".
### params
- `desc.srcToken` / `desc.dstToken`: input and output tokens, resolved from the token registry by symbol (never model-supplied bytes).
- `desc.amount`: input amount, scaled by the source token's real decimals.
- `desc.minReturnAmount`: minimum acceptable output — the slippage seatbelt; must be positive, computed from a fresh quote minus tolerance, never 0.
- `desc.dstReceiver`: must be the vault/wallet itself; a foreign receiver is a red flag.
- `executor` + `data`: the opaque route payload from the 1inch API; treat as untrusted and validate by simulated effect, not by inspection.
### pitfalls
- The `executor` and `data` are opaque aggregator calldata — never let a model author them; only accept them from the 1inch quote API and re-price them.
- A minimum return of 0 disables slippage protection entirely; refuse to encode a swap without a positive floor.
- ERC20 approval must target the router (V6 vs V5 are different contracts) — approving the wrong router version silently fails.
### safety
- Simulate before send and assert Δbalances: source token decreases by `amount`, destination increases by at least the minimum return, and no third party receives funds.
- Bound the approval to exactly `amount`; do not leave a standing unlimited allowance on an aggregator router.

## action: uniswapV3Swap
**Function:** `uniswapV3Swap(uint256 amount, uint256 minReturn, uint256[] pools)`
**Contract:** role `router` (registry: `dex/oneinch/router`)
**Use when:** the 1inch quote resolves to a direct Uniswap-V3 path and returns the packed `pools` array — a cheaper, single-venue settlement than the full `swap`.
### params
- `amount`: input amount, scaled by the source token's real decimals.
- `minReturn`: minimum output; the slippage floor, must be positive.
- `pools`: packed pool identifiers from the 1inch quote — opaque, accept only from the API.
### pitfalls
- The source/destination tokens are implied by the packed `pools` array, not passed explicitly — you must confirm them against the quote before trusting the direction.
- A `minReturn` of 0 removes all protection; refuse.
### safety
- Simulate and assert the destination token increases by at least `minReturn` and the correct source token is the one spent; refuse on any unexpected token movement.
