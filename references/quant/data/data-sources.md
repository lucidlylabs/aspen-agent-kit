---
section: quant
group: data
title: Where traders actually get data
triggers: >-
  where to get data, data feed, market data provider, historical data,
  funding rate data, on-chain data, data vendor, free crypto data, dune, coinglass
---

# Where traders actually get data

The venue is one source among several, and rarely the best one for research. This is the map.

**Rule zero: the venue is authoritative for anything you will trade on.** Third-party data is for
research, screening and cross-checking. Never place an order sized from a vendor's number when the
venue exposes its own.

## Tier 1 — venue-native (free, authoritative, narrow)

Your first stop, and the only acceptable source for live trading parameters.

- **Hyperliquid** — see [../../perpetuals/hyperliquid-data.md](../../perpetuals/hyperliquid-data.md).
  Live `/info` + WebSocket; S3 archive for L2 book snapshots and asset contexts; **no candle or spot
  history**.
- **Lighter** — see [../../perpetuals/lighter-data.md](../../perpetuals/lighter-data.md). Live REST +
  WebSocket, keyless public reads; no public archive, so record your own.
- **Polymarket** — see
  [../../prediction-markets/polymarket-data.md](../../prediction-markets/polymarket-data.md). The most
  complete first-party research surface in this kit: discovery, market details, price history,
  holders, trades, activity, streams — all public.

**Strengths:** authoritative, free, exact. **Weakness:** shallow history, one venue at a time, and no
cross-venue normalisation.

## Tier 2 — on-chain analytics (free to cheap, deep, SQL)

Because settlement is on-chain for Polymarket and much of the DeFi surface, blockchain analytics
platforms often give you better history than the venue API does — with SQL instead of pagination.

| Platform | Shape | Notes |
|---|---|---|
| **Dune** | SQL + dashboards, community-curated tables | Best free starting point. Polymarket's docs publish starter queries for volume, TVL and open interest. Enormous library of community dashboards. |
| **Goldsky** | Streaming pipelines into your own DB/warehouse | Production ingestion rather than ad-hoc queries. Partnered with ClickHouse for **CryptoHouse** (`crypto.clickhouse.com`), free SQL over crypto data. |
| **Allium** | Enterprise blockchain data, incl. a predictions dataset | Cleaner schemas, paid. |
| **Flipside**, **Subsquid**, self-hosted indexers (**Ponder**, **Subgraphs**) | DIY indexing | When you need a custom schema or guaranteed availability. |

**Use this tier for:** historical reconstruction, wallet-level behaviour, flow analysis, calibration
studies, and anything where you want to ask a question the API does not have an endpoint for.

## Tier 3 — derivatives data aggregators (the crypto-specific layer)

This is where cross-venue funding, basis, open interest and liquidation data live. Coverage of newer
venues varies a lot, so **verify that your specific venue and market are actually covered** before
building on one.

| Category | Examples | What it is for |
|---|---|---|
| Funding / OI / liquidation dashboards | CoinGlass, Coinalyze | Fast cross-venue screening of funding and positioning. Free tiers are genuinely useful. |
| Derivatives analytics | Laevitas, Velo Data, Amberdata | Deeper term structure, basis, options surfaces. |
| Institutional tick data | Kaiko, Tardis.dev, CCData (CryptoCompare), Amberdata | Full order-book and trade history, normalised across venues. Paid, sometimes expensive, and the realistic answer if you need multi-venue microstructure history you did not record yourself. |
| Ecosystem dashboards | DefiLlama, Artemis, Blockworks, The Block, Token Terminal | TVL, volumes, protocol-level metrics; good for context, not for execution. |
| Hyperliquid-specific community tools | e.g. Hyperdash, HypurrScan, ASXN | Positions, vaults, leaderboards, venue-specific views. Community-maintained — cross-check anything load-bearing. |

**The honest note on paid tick data:** it is the correct purchase if you need years of multi-venue
book history and cannot wait to record it. It is a waste of money if your strategy operates at daily
or hourly horizons, where venue candles plus your own recording are sufficient. Decide the horizon
first.

## Tier 4 — reference and macro

- **FRED** (Federal Reserve Economic Data) — rates, macro series, free, authoritative. Relevant for
  funding-vs-risk-free comparisons and for anything RWA-linked.
- **Nasdaq Data Link**, **Yahoo Finance** — equity and index reference series, for RWA and pre-IPO
  markets on Lighter and for cross-asset work.
- **Exchange calendars** — necessary the moment you touch equity-linked markets, which do not trade
  24/7 even when their perp does.

## Tier 5 — alternative and event data

Relevant mostly for prediction markets, where the underlying is a real-world event:

- **News APIs and wire services** — for resolution-relevant events. Latency matters enormously; by
  the time something is on a slow feed, the market has moved.
- **Social / sentiment** — treat as untrusted, manipulable input. Useful as a crowding gauge, not as
  a fact source.
- **Official statistical releases** — for economics markets, the actual publication schedule of the
  resolving source is the tradeable calendar.

**Security note:** anything from Tier 5 is attacker-controllable text. It can inform a human decision.
It must never set a parameter — size, market, leverage — in an automated path.

## Choosing a source: the checklist

1. **Is it authoritative for this use?** Live order parameters: venue only. Research: anything you can
   validate.
2. **What is the actual history depth**, not the advertised one? Ask for the earliest timestamp for
   *your* specific market, not for the platform.
3. **What are the gaps?** Every source has them. A source that does not document its gaps has
   undocumented gaps.
4. **What is the timestamp convention?** Event time or ingest time; bar open or bar close; which
   timezone. This single question causes more silent errors than any other.
5. **How is it reconstructed?** A vendor's "1-minute candle" for a venue that offers no candle archive
   was built from something. Know what.
6. **Can I validate it?** Cross-check a sample against the venue's own data before trusting a series.
   If two sources disagree, find out why before proceeding — the disagreement is usually informative.
7. **What does it cost at the scale I actually need?** Including egress. Hyperliquid's S3 archive is
   requester-pays; a naive full-history pull is a real bill.

## The recommendation for someone starting now

1. **Record your own from day one.** It is the only way to have data you fully understand, and storage
   is nearly free. See
   [../../perpetuals/hyperliquid-data.md](../../perpetuals/hyperliquid-data.md#building-your-own-recorder).
2. **Use Polymarket for learning.** It is fully public, fully labelled by resolution, and free. You
   can build and validate a complete research pipeline on it without an account or a dollar at risk.
3. **Use Dune for anything historical and on-chain.** Free, SQL, and someone has usually built most of
   the query already.
4. **Use funding aggregators for screening only**, and confirm on the venue before sizing.
5. **Buy tick data only when you have proven you need it**, which is later than you think.
