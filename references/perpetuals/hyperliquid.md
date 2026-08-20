---
venue: hyperliquid
section: perpetuals
title: Hyperliquid
surfaces: [perps, hip3-builder-perps, spot, hip4-outcome-markets]
docs: https://hyperliquid.gitbook.io/hyperliquid-docs
triggers: >-
  trade on hyperliquid, connect to hyperliquid, HL API wallet, agent wallet,
  asset id, szDecimals, HIP-3 builder market, hyperliquid spot, usdClassTransfer
---

# Hyperliquid

## Official documentation — read these first

| What | Where |
|---|---|
| Docs home | https://hyperliquid.gitbook.io/hyperliquid-docs |
| Documentation index for agents | `llms.txt` at the docs root; append `.md` to any page URL for raw Markdown |
| API reference | docs → **For developers → API** (`/exchange` and `/info` endpoints, WebSocket, rate limits) |
| Fees | docs → **Trading → Fees** |
| Historical data | docs → **Historical data** |
| Official Python SDK | https://github.com/hyperliquid-dex/hyperliquid-python-sdk |

Everything below is the layer the docs do not write down: what bites, what it costs, and what you
have to build yourself. Signatures and parameters come from the SDK and the API reference, not from
here — **this card names what to look up, it is not a substitute for looking it up.**

## The architecture, in one paragraph

Hyperliquid runs its own L1. The exchange is **HyperCore**, a fully on-book central limit order book
where matching happens off-chain relative to HyperEVM and is reached by **signed HTTP actions** to
the `/exchange` endpoint. It is not an EVM contract call, so there is no address to approve and no
gas to price — you sign an action and POST it. Reads go to the `/info` endpoint and a WebSocket.
**HyperEVM** is a separate general-purpose EVM environment on the same chain; a perp order never
touches it. Confusing the two is the most common architectural mistake in a first integration.

## Connecting

The venue's own SDK is the connection layer; do not hand-roll the signing. The two facts that
actually decide whether your integration works:

**1. You trade through an API wallet ("agent"), not your main key.** You approve a separate signing
key that can place and cancel orders for your account but **cannot withdraw or transfer funds**.
This is the single most important security property of the venue and you should treat it as
mandatory, not optional: the key your bot holds should be structurally incapable of moving money.
Approval must carry a **non-empty name** or actions are rejected. An account may hold one unnamed
plus a small number of named agents, and a named approval carries an expiry — check the current
limits and maximum validity window in the API reference, because both have changed.

**2. Margin lives on the perp side.** USDC on the spot book cannot margin a perp. Move it with
`usdClassTransfer` before you expect an order to fill, or the order simply fails for insufficient
margin while your balance page shows plenty.

## The mechanics that cause most bugs

- **Asset ids are integers, and the scheme is overloaded.** A first-party perp is its index in the
  perp `meta.universe`. Spot is `10000 + index` into `spotMeta.universe`. HIP-3 builder perps are
  `100000 + dex_index * 10000 + index_in_meta`. HIP-4 outcome markets use their own offset scheme
  with the Yes/No side encoded in the id. **Resolve the id from live metadata every time.** An id
  hardcoded at build time will eventually point at a different market, and the order will still be
  accepted.
- **Rounding is enforced.** Size rounds to the asset's `szDecimals`; price rounds to the tick and is
  additionally constrained to a limited number of significant figures. Un-rounded values are
  rejected outright — which is the good case. Read the current rules from the API reference.
- **TP/SL are separate trigger orders, not fields on the entry.** They are attached by an order
  `grouping`, and by default they **execute as market orders when triggered**, which makes every
  stop a taker fill. If your cost model assumed maker fees on exits, it is wrong.
- **`reduce_only` clamps, it never flips.** A reduce-only size larger than the open position shrinks
  to the position; it will not open the opposite side. This is the property that makes it a safe
  close primitive.
- **Trigger orders and liquidations use mark price, not last trade.** A wick on the book that never
  touches the mark does not fire your stop, and a mark that moves without a trade does.
- **Rate limits are weighted and partly address-based.** Budget them at design time; a market-making
  loop that reprices naively will hit them.

## The other surfaces on the same connection

**HIP-3 builder-deployed perps.** Anyone can deploy an independent perp DEX on the shared
infrastructure — equities, indices, commodities, FX, pre-IPO names — under namespaced symbols. The
order path is identical; only the asset id changes. What changes materially is the **trust model**:
the deployer sets the oracle, the leverage caps, and the margin rules, and can settle or delist. The
deployer posts a slashable stake, which bounds but does not eliminate the risk. Treat a builder
market as a higher trust assumption than a first-party one, and surface *whose* oracle you are
trading against before sizing. A builder may also charge a fee on top of the venue fee, so a builder
market is **never cheaper** than the same first-party market.

**Spot.** A native on-book spot market for HIP-1 tokens quoted against USDC. No leverage, no
liquidation. It matters here for one reason: it is the hedge leg for cash-and-carry and basis
trades. Note that the ticker is a display name and the on-chain hash is the unique id — two
different tokens can present the same ticker.

**HIP-4 outcome markets.** Binary, fully collateralized, settle in [0,1]. Covered under
[prediction markets](../prediction-markets/hip4.md), not here.

## What to verify live, every time

Asset ids and `szDecimals`. Tick rules. Max leverage per asset (it varies, and builders set their
own). Your current fee tier. The quote token on any HIP-4 market. Agent approval limits and expiry.
None of these are safe to cache across a deploy.
