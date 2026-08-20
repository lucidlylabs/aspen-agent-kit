---
venue: hyperliquid
section: perpetuals
title: Hyperliquid — data
kind: data-sourcing
docs: https://hyperliquid.gitbook.io/hyperliquid-docs/historical-data
triggers: >-
  hyperliquid historical data, candles, funding history, l2 book snapshots,
  backtest data, s3 archive, record market data, websocket feeds
---

# Hyperliquid — getting data

The venue gives you excellent **live** data and deliberately thin **historical** data. Understanding
exactly where that line falls is the difference between a research plan that works and one that
stalls three weeks in.

**Source:** docs → *Historical data* and *For developers → API*. Fetch them as Markdown by appending
`.md` to the page URL.

## Live data

Reads go to the `/info` endpoint (HTTP POST, keyless) and a WebSocket. The surfaces that matter for
research and for running a strategy:

| You want | Surface | Notes |
|---|---|---|
| OHLCV candles | `/info` candle snapshot | Bounded lookback per request. This is the **only** first-party candle source — there is no candle archive. |
| Current funding + open interest + mark/oracle px | `/info` meta and asset contexts | One call returns the whole universe. The cheapest useful poll on the venue. |
| Historical funding | `/info` funding history | Per-coin, time-ranged. Retrievable retroactively, so funding is the one series you do **not** have to record live. |
| Predicted / upcoming funding | `/info` predicted fundings | Includes other venues for comparison — useful for cross-venue funding spreads. |
| Order book | `/info` L2 book, or WS `l2Book` | Snapshot depth. Poll for research, subscribe for trading. |
| Trades (prints) | WS `trades` | **Not retrievable historically from the API.** Record it or lose it. |
| Best bid/offer | WS `bbo` | Lighter-weight than full book; enough for spread and mid series. |
| All mids | `/info` all mids, or WS | One call for every market's mid. Ideal low-cost universe snapshot. |
| Your fills | `/info` user fills | Your own execution history, for post-trade analysis. |
| Your fee tier | `/info` user fees | Returns your actual maker/taker rate and referral discount. **Use this instead of assuming base tier** — see [fees.md](fees.md). |

Names above are descriptive; take the exact request shapes from the API reference, which is
versioned and changes.

## Historical data: what the archive actually contains

Hyperliquid publishes an S3 archive. It is **requester-pays**, so you are billed for transfer.
Uploads happen roughly monthly, with **no guarantee of timeliness and known gaps**.

```
s3://hyperliquid-archive/market_data/[date]/[hour]/l2Book/[coin].lz4     L2 book snapshots
s3://hyperliquid-archive/asset_ctxs/[date].csv.lz4                       asset contexts (funding, OI, mark)
```

```bash
aws s3 cp s3://hyperliquid-archive/market_data/20230916/9/l2Book/SOL.lz4 /tmp/SOL.lz4 --request-payer requester
unlz4 --rm /tmp/SOL.lz4
```

Node-sourced datasets live in a separate bucket:

```
s3://hl-mainnet-node-data/node_fills_by_block     fills, matches the API format  (preferred)
s3://hl-mainnet-node-data/node_fills              older format
s3://hl-mainnet-node-data/node_trades             older AND a different schema — do not mix
s3://hl-mainnet-node-data/explorer_blocks         historical explorer blocks
s3://hl-mainnet-node-data/replica_cmds            L1 transactions
s3://hl-mainnet-node-data/misc_events_by_block    transfers, staking, funding events
```

## The gap that will define your project

> **There are no historical candles and no historical spot data in S3.** The docs say so plainly:
> "No other historical data sets are provided via S3 (e.g. candles or spot asset data). You can use
> the API to record additional historical data sets yourself."

So: **your candle history is whatever you started recording.** Three consequences worth internalising
before you plan any research:

1. **Start the recorder on day one**, before you know what you want to study. Storage is trivially
   cheap next to the cost of waiting three months to have three months of data. Record more markets
   and finer resolution than you think you need; you can always downsample, you can never upsample.
2. **Candle backfill is bounded.** The API's lookback per request limits how far back you can seed.
   Whatever the current bound is, it is finite and it is the ceiling on your history for any market
   you were not already recording.
3. **Funding is the exception** — it is queryable retroactively. If you are building funding-carry
   research, you can get real history today. If you are building anything that needs prints or fine
   candles, you cannot.

## Building your own recorder

The minimum viable capture, in priority order:

1. **Asset contexts, every minute.** One call, the whole universe, gives you funding, open interest,
   mark and oracle price per market. This single series supports most crypto-native indicator work
   ([../quant/indicators/crypto-native.md](../quant/indicators/crypto-native.md)) and it is small.
2. **Trades, streamed.** The one series that is genuinely unrecoverable. Append-only, one file per
   day per market.
3. **BBO or L2 top-of-book, streamed or sampled.** Needed for any honest cost model — you cannot
   estimate spread cost or slippage after the fact without it.
4. **Candles, hourly pull.** Cheap insurance and a reconciliation check against your own bars.

Store raw and immutable, derive everything else. Parquet partitioned by market and date is the
default worth having a reason to deviate from. Timestamp everything in UTC epoch milliseconds at the
source, and record **your** receive time alongside the venue's event time — the gap between them is
data, and it is how you later discover that a "signal" was actually a feed lag.

See [../quant/data/data-quality.md](../quant/data/data-quality.md) for what to check before trusting
any of it, and [../quant/data/reading-market-data.md](../quant/data/reading-market-data.md) for why
you may not want time-based bars at all.

## Third-party and community sources

- **Trade history export** — `trade-export.hypedexer.com`, built by the Enigma team. Independent and
  third-party; the venue links it but does not maintain it.
- **Running your own non-validating node** with fill streaming is the only way to get complete,
  low-latency historical fills without depending on archive cadence.
- General crypto data vendors and on-chain analytics platforms increasingly carry Hyperliquid. Verify
  their reconstruction against the S3 archive before you trust a vendor series for anything with
  money attached — vendor gaps and vendor timestamp conventions are the two most common sources of a
  backtest that cannot be reproduced live.
