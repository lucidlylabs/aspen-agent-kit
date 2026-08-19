---
protocol: kyberswap
category: dex
chains: [1, 8453, 42161]
archetype: aggregator_swap
executor: live
aliases:
  - "swap on kyberswap"
  - "best price swap USDC to WETH"
  - "aggregate a swap across DEXes"
  - "route my swap for best execution"
  - "swap with the kyber aggregator"
roles: [router]
actions: [swap]
tokens: [USDC, WETH, wstETH]
---

# KyberSwap (aggregator)

KyberSwap's **MetaAggregationRouterV2** (role `router`) routes a swap across many liquidity sources for
best execution. Unlike a single-pool DEX, the route + the low-level `targetData` calldata are produced
**off-chain by the KyberSwap Aggregator API** (`https://docs.kyberswap.com/`); on-chain you call one
function, `swap`, with those params. The router is the single signed-tx target; the src-token approval
goes to it too.

> **executor: live.** The generic graph engine runs the `aggregator_swap` archetype via the
> `swap_via_aggregator` block: the harness picks KyberSwap only if it wins the live quote-off, and the
> swap is signed by the isolated burner ONLY after a mandatory fork-simulation proves the value outcome.
>
> **Note on the API dependency:** the routing `targetData` is opaque bytes from an off-chain quote. The
> executor fetches a FRESH quote at execution time and re-derives `minReturnAmount` from the slippage
> bound rather than trusting the API's echo — the "code decides the bound, not the model" rule extended to
> a third-party quote — then the fork-sim asserts the wallet actually receives ≥ that floor.

## action: swap
**Function:** `swap(SwapExecutionParams execution)`
where `SwapExecutionParams = (address callTarget, address approveTarget, bytes targetData, SwapDescriptionV2 desc, bytes clientData)`
and `SwapDescriptionV2 = (address srcToken, address dstToken, address[] srcReceivers, uint256[] srcAmounts, address[] feeReceivers, uint256[] feeAmounts, address dstReceiver, uint256 amount, uint256 minReturnAmount, uint256 flags, bytes permit)`
**Contract:** role `router` (registry: `dex/kyberswap/router`)
**Use when:** swapping one token for another at best aggregated price.

### params
- `desc.srcToken` / `desc.dstToken` — resolved from the token book by symbol; `srcToken != dstToken`.
- `desc.amount` — the input amount, in `srcToken`'s decimals; scale from the token book, never a hardcoded 10^n.
- `desc.dstReceiver` — **MUST be the trading wallet / vault itself.** Anyone else drains the output.
- `desc.minReturnAmount` — the slippage floor. **Derive it from the quote + `maxSlippageBps`; never 0.**
- `approveTarget` — where the `srcToken` approval is sent; for MetaAggregationRouterV2 this is the router
  itself. Approve exactly `desc.amount`, not unlimited.
- `targetData` / `clientData` — opaque bytes from the KyberSwap API quote. Do not hand-craft.

### pitfalls
- `dstReceiver` other than self donates the whole output — refuse. (This is the field the boring-vault
  decoder sanitizes, alongside `srcToken`/`dstToken`.)
- `minReturnAmount = 0` is an unbounded-slippage swap — refuse; floor it from a fresh quote.
- A stale `targetData` routes against moved liquidity and can revert or slip badly — re-quote at send time.
- Unlimited approval to `approveTarget` leaves a standing allowance on a mutable aggregator — approve the
  exact amount and sweep the allowance to 0 on close.

### safety
- The src-token approve (`srcToken` → `approveTarget`) must be in the plan or the swap reverts / is default-DENYed.
- Sweep the output token home to the vault on close.
