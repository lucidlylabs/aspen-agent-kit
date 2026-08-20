---
section: perpetuals
title: Perpetual futures
venues: [hyperliquid, lighter, polymarket-perps]
triggers: >-
  long/short a perp, leverage, funding rate, liquidation price, margin mode,
  "which venue should I trade on", cross-venue funding spread, basis
---

# Perpetual futures

## What a perp is, from first principles

A **perpetual future** is a contract that tracks an asset's price and never expires. That
combination is unstable on its own: an ordinary future converges to spot because it settles on a
date. Remove the date and nothing forces convergence.

So perps bolt on a tether: the **funding rate**, a payment made directly between traders on a
schedule. When the perp trades above spot, longs pay shorts. When it trades below, shorts pay
longs. The payment scales with the gap. Holding the expensive side costs money, holding the cheap
side earns it, and the perp is pushed back toward spot without anything ever settling.

Two consequences follow, and most perp opportunities are one of them:

1. **Funding is a real cash flow.** It is paid on a schedule whether or not the price moves. It can
   be harvested by a position that is hedged against direction.
2. **Funding is a crowding gauge.** A large positive rate is not an opinion. It is evidence that
   longs are crowded enough to pay to stay long.

Everything else about a perp — leverage, margin modes, liquidation — is the credit system that lets
you hold notional larger than your collateral. Leverage does not change expected return. It changes
the distance to a forced exit, and it multiplies every cost that is charged on notional.

## Official documentation

This kit is a layer *on top of* the venues' own docs, never a replacement for them. Every mechanical
claim here should be checked against the source below, and anything time-varying — fee tiers,
leverage caps, endpoints, market ids — must be read live rather than trusted from any document.

| Venue | Docs | Machine-readable index | API reference | Official code |
|---|---|---|---|---|
| Hyperliquid | https://hyperliquid.gitbook.io/hyperliquid-docs | `/llms.txt`, every page has a `.md` twin | docs → *For developers → API* | [hyperliquid-dex/hyperliquid-python-sdk](https://github.com/hyperliquid-dex/hyperliquid-python-sdk) |
| Lighter | https://docs.lighter.xyz | `/llms.txt`, every page has a `.md` twin | https://apidocs.lighter.xyz | [elliottech/lighter-agent-kit](https://github.com/elliottech/lighter-agent-kit) (official agent skill) |
| Polymarket | https://docs.polymarket.com | https://docs.polymarket.com/llms.txt, every page has a `.md` twin | docs → *API Reference* | official unified TypeScript + Python SDKs (docs → *Getting started*) |

All three publish an `llms.txt` documentation index and serve every page as raw Markdown by
appending `.md` to its URL. **Use those.** Fetching `https://docs.polymarket.com/trading/fees.md`
costs a fraction of scraping the rendered page and gives you the tables intact.

## The three venues at a glance

| | Hyperliquid | Lighter | Polymarket Perps |
|---|---|---|---|
| Architecture | Own L1 (HyperCore), off-chain CLOB, signed HTTP actions | ZK app-chain, off-chain matching, validity proofs to Ethereum | Off-chain CLOB, pUSD collateral |
| Order entry | Signed `/exchange` actions via an approved API wallet | Signed L2 txs via a registered API key | Signed orders via the perps API |
| Market id | integer asset id (index into `meta.universe`) | integer `market_index` | instrument symbol |
| Collateral | USDC (perp balance) | USDC (ETH usable as multi-asset margin) | pUSD |
| Base taker fee | 0.045% | 0% Standard / 0.028% Premium / 0.005% Plus | 0.040% |
| Base maker fee | 0.015% | 0% / 0.004% / 0.005% | 0.0125% |
| Funding cadence | hourly | hourly | see venue docs |
| Distinctive | HIP-3 builder markets, HIP-4 outcome markets, native spot | zero-fee tier priced in latency, RWA / pre-IPO markets | prediction markets on the same collateral |

**Read the fee row twice.** Lighter's Standard account charges nothing and imposes a 300ms taker
delay; Hyperliquid charges 4.5bp and imposes none. Those are not the same trade with different
prices, and the cheaper headline is not automatically the cheaper venue. See
[fees.md](fees.md), which is where that comparison is actually settled.

## What is in this section

- **[hyperliquid.md](hyperliquid.md)** — connecting, the surfaces (perps, HIP-3, spot), and the
  handful of mechanics that cause most integration bugs.
- **[hyperliquid-data.md](hyperliquid-data.md)** — every data feed the venue exposes, what the
  historical archive does and does not contain, and how to build the datasets it refuses to give you.
- **[lighter.md](lighter.md)** — the official Lighter agent kit is the execution layer; this covers
  what it does not, and what is structurally different about the venue.
- **[lighter-data.md](lighter-data.md)** — data surfaces and the archive problem.
- **[fees.md](fees.md)** — all three schedules, the all-in cost model, and the arithmetic that
  decides whether a strategy can survive its own turnover.
- **[risk-controls.md](risk-controls.md)** — margin, liquidation math, and the controls that must be
  code rather than intention.

## Routing

A venue question ("how do I set leverage on Lighter") goes to that venue's card. A *strategy*
question ("is this funding trade worth it") goes to [../quant/](../quant/README.md) — the venue
cards deliberately do not carry strategy, and the quant section deliberately does not carry API
surface.
