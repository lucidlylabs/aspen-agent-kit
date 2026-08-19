---
protocol: hyperliquid-hip4
category: prediction
chains: [999]
archetype: outcome_market
executor: knowledge-only
aliases:
  - "buy YES on a hyperliquid outcome market"
  - "trade a hyperliquid prediction market"
  - "bet on an event outcome on hyperliquid"
  - "sell NO shares on a HIP-4 market"
  - "place a limit on a hyperliquid outcome contract"
roles: [venue]
actions: [order, cancel, cancel_by_cloid, approve_builder_fee]
tokens: [USDC, USDH]
---
# Hyperliquid HIP-4 (Outcome Markets)
HIP-4 adds **fully collateralized outcome contracts** — binary instruments that settle within a fixed range **[0, 1]** — to Hyperliquid's engine, enabling prediction markets and bounded options-like instruments. It went live on Hyperliquid mainnet around May 2026. Each market has two sides, **Yes** and **No** tokens; at settlement Yes converts to `settleFraction` quote tokens and No to `1 - settleFraction` (credited automatically — no claim/redeem call). Unlike HIP-3 perps there is **no leverage and no liquidation** — every position is fully collateralized — and contracts are **dated** (fixed settlement) with non-linear payoffs. The Yes and No order books **merge to share liquidity**: buying Yes at price *p* is equivalent to selling No at *1 - p* (at a merged price level, resting sells sort before resting buys). It is an off-chain L1 venue reached through the same signed `/exchange` API actions via Aspen's HL agent, never an EVM `vault.manage`. **The quote/collateral token is PER-MARKET DATA** (`outcomeMeta` / the settled `spec.quoteToken`): the docs' examples quote in USDC, but live markets reportedly quote in **USDH** — never assume the quote token; read it from the venue (an unknown quote token fails a sizing decision closed). Builder codes work as in spot (builder earns fees on sell orders carrying the code); **fees apply only on close/burn/settlement — opening a position is fee-free** (the fee event is the exit). Per current docs, outcome-market fees are set to **zero for initial testing**; maker orders pay zero fees and there are no maker rebates.
> **executor: knowledge-only (SDK built + offline-proven; flips to `live` after the hip4 live-broadcast QA — the corpus gate requires a live card's roles/tokens to resolve in the address registry, and this off-chain venue's chain-999 quote tokens are not yet registry-verified).** HIP-4 rides the harness's `signed` modality behind the gated `"hip4"` catalog capability: `hip4_buy` / `hip4_sell` (signed actions emitting a `SignedOrderIntent`, venue `hyperliquid` + scope `prediction` — the venue-routing pair that tells it apart from Polymarket) plus `hip4_price_below` / `hip4_price_above` (outcome-book mid-probability guards) and `hip4_settled` (post-settlement housekeeping guard). The MARKET SYMBOL NAMES THE OUTCOME: `"<selector>:YES"` or `":NO"`, where the selector is `outcome-<int>` (pinned id), `<UNDERLYING>-<period>` (the currently-live recurring instance, e.g. `BTC-1d`), or `<UNDERLYING>-<period>-<YYYYMMDD-HHMM>` (a specific UTC expiry) — resolved against the live `outcomeMeta` per tick (recurring markets ROTATE: each instance is a NEW outcome integer, so ids are never pinned at compose time). Orders are the STANDARD signed `order` action on asset id `100_000_000 + 10*outcome + side` (side 0 = Yes, 1 = No); no leverage step, no reduce-only, no server-side triggers (probability TP/SL = guards + sell nodes). There is no on-chain address/role.
## action: order (outcome market)
**Function:** `order(name, is_buy, sz, limit_px, order_type, reduce_only=False, cloid=None, builder=None)` (`exchange.py`); trades the Yes/No side on the merged outcome book (`hip-4` docs)
**Contract:** role `venue` (off-chain — no registry address)
**Use when:** buying/selling a Yes or No outcome share on a HIP-4 market.
### params
- `name`/asset id — the outcome-market side (Yes or No token) on the builder's outcome dex.
- `limit_px` — price in **[0, 1]** (probability-like); buying Yes at *p* is equivalent to selling No at *1 - p*.
- `sz` — number of contracts; each is fully collateralized (max loss = collateral, no margin call).
- `order_type` — limit `{tif}`; no perp-style leverage/trigger-margin semantics.
### pitfalls
- **No leverage / no liquidation, but not risk-free** — a losing side settles to **0**; the position can go fully worthless at settlement.
- Yes and No books are **merged** — a Yes buy may match against a No sell; reason in the *p / 1-p* duality, not two independent books.
- **Dated contracts** — positions auto-settle at the market's date via `settleFraction`; there is no perpetual roll.
- Builder-deployed and builder-operated (like HIP-3) — the deployer/settlement source is a trust assumption; surface it.
### safety
- Same engine kill switch + trade-only HL agent; per-market quote-token collateral (USDC/USDH — read from the venue), no on-venue custody by Aspen.
- Because payoff is binary and dated, the consent screen must show max loss (= collateral) and the settlement date/source; per-user isolation bounds exposure.
