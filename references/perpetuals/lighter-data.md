---
venue: lighter
section: perpetuals
title: Lighter — data
kind: data-sourcing
docs: https://apidocs.lighter.xyz
triggers: >-
  lighter historical data, lighter candles, lighter funding history,
  lighter websocket, lighter order book data, record lighter data
---

# Lighter — getting data

**Source:** https://apidocs.lighter.xyz and https://docs.lighter.xyz (`llms.txt`; append `.md` to any
docs page for raw Markdown). The official agent kit already wraps most public reads — use its
scripts rather than writing your own client.

## Live data

Public reads are keyless. The surfaces that matter:

| You want | Surface |
|---|---|
| Market metadata, tick/size scaling, minimums | order book details / market metadata |
| Order book | order book endpoint, or the WebSocket book channel |
| Candles | candlestick endpoint |
| Funding | funding rate endpoint and per-market funding history |
| Recent trades | trades endpoint / WebSocket trade channel |
| Account state, positions, fills | account endpoints (requires API key) |

Rate limits are tier-dependent, and `sendTx` has its own budget separate from read requests. A Plus
account exists specifically to buy higher limits (order of 8,000 `sendTx`/min and 120,000 weighted
reads/min) at a flat half-basis-point fee — if you are building a high-message-rate system, that
tier is a data-infrastructure decision as much as a trading one.

**Always pull the per-market scaling from metadata.** Prices and sizes are integers scaled by
per-market decimals. This is the highest-severity gotcha on the venue: a wrong exponent does not
error, it trades the wrong size.

## Historical data

There is no equivalent of Hyperliquid's public S3 archive. **Plan to record your own from day one.**
Candles give you a bounded backfill and funding history is queryable, but book and trade granularity
beyond the API's retention is yours to capture or lose.

The same recorder discipline applies as in
[hyperliquid-data.md](hyperliquid-data.md#building-your-own-recorder): capture funding and market
context on a fixed cadence, stream trades, sample top-of-book, and store raw with both venue event
time and your receive time.

## The latency dimension is data

Lighter is the one venue in this kit where **your own account tier changes the data you see**. A
Standard account's 300ms taker delay and 200ms maker delay mean the book you acted on is not the book
you filled against. If you are researching anything execution-sensitive, log:

- venue event time, your receive time, your send time, and the fill time;
- the top-of-book at send versus the top-of-book at fill.

That difference *is* your true cost on this venue, and no fee schedule will show it to you. It is the
empirical input to the all-in cost model in [fees.md](fees.md).

## Cross-venue alignment

If you are comparing Lighter against Hyperliquid — for a funding spread, a basis trade, or just venue
selection — the two feeds are not natively aligned:

- **Funding conventions differ.** Lighter clamps and floors the rate and applies a per-market-class
  multiplier; Hyperliquid does not do it the same way. Convert both to a common unit (e.g. annualised
  percent) before comparing, and never compare raw published rates.
- **Timestamps differ in meaning.** Align on a common clock and resample both to the same bar
  boundaries before computing any spread series, or you will manufacture a signal out of sampling
  offset. See [../quant/data/data-quality.md](../quant/data/data-quality.md).
- **Symbols differ.** The same underlying can have different tick sizes, different leverage caps, and
  different liquidity profiles across the two. A spread is only tradable at the size the *thinner*
  side supports.
