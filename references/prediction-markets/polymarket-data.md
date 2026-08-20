---
venue: polymarket
section: prediction-markets
title: Polymarket — data
kind: data-sourcing
docs: https://docs.polymarket.com/resources/blockchain-data
triggers: >-
  polymarket data, price history, market discovery, gamma api, data api,
  dune polymarket, goldsky, allium, calibration, backtest prediction markets
---

# Polymarket — getting data

Polymarket is the **best-documented and most researchable venue in this kit**. Everything is public,
much of it is on-chain, and there is a mature third-party data ecosystem. If you want to learn
systematic trading with real data and no capital at risk, start here.

**Source:** docs → *Market Data* and *Resources → Data Resources*. Fetch as Markdown via
https://docs.polymarket.com/llms.txt and the `.md` twin of any page.

## First-party surfaces

Work in the order the data model implies: **discover an event → select a market → choose an outcome →
read or stream by token id.**

| You want | Surface |
|---|---|
| Find events/markets by topic, tag, volume, liquidity, status | market discovery endpoints |
| A market's outcomes, status, tick size, **fee parameters**, resolution criteria | market details |
| Current price, midpoint, spread, order book | prices and order books |
| **Historical price series per outcome token** | price history endpoint — the backtest substrate |
| Who holds and trades what: positions, top holders, trades, user activity | analytics / wallet activity endpoints |
| Live updates | market stream: `book`, `price_change`, `last_trade_price`, `tick_size_change` |
| Authenticated order/trade updates | real-time order updates stream |
| Chainlink TWAP prices | consumable directly or through the real-time data service |

**Public reads need no credentials.** You can build and validate an entire research pipeline without
an account.

## The on-chain data stack

Because settlement is on-chain, trades, positions, balances and redemptions are all queryable through
standard blockchain analytics — often more conveniently than through the API.

| Provider | What it gives you |
|---|---|
| **Goldsky** | Real-time streaming pipelines of Polymarket on-chain activity into your own database or warehouse. Partnered with ClickHouse for **CryptoHouse** (`crypto.clickhouse.com`), where you can query it with free SQL. |
| **Dune** | SQL + dashboards. The docs publish starter queries for volume, TVL, and open interest. |
| **Allium** | Historical predictions dataset (`predictions.allium.so`). |

Dashboards worth knowing: Blockworks, Artemis, DeFiLlama, The Block, Token Terminal, and Dune
community dashboards — notably `@hildobby`'s volume/OI/TVL work and **`@alexmccullaaa`'s "How accurate
is Polymarket"**, which is a public calibration study and the single most useful free artifact for
anyone building prediction-market strategy.

## Calibration: the dataset that makes this venue special

Every resolved market gives you a **(price, outcome)** pair. Nowhere else in trading do you get such
a clean, abundant, ground-truth-labelled dataset.

Take every market that resolved. Bucket by price at some horizon before resolution. Ask: **of the
contracts that traded at 30¢, what fraction resolved YES?** If the answer is 30%, the market is
calibrated at that price and there is no edge there. If it is 22%, longshots are systematically
overpriced and the tradable edge is *selling* them.

This is the empirical form of the **favorite-longshot bias**, one of the most durable findings in the
economics of betting markets (Thaler & Ziemba 1988; surveyed in Wolfers & Zitzewitz 2004). It is
worth measuring yourself rather than assuming, because its magnitude varies enormously by category,
by liquidity, and by time-to-resolution — and because on Polymarket the **fee structure interacts
with it directly** (see [fees.md](fees.md)).

Method notes that decide whether your calibration study is real:

- **Include resolved markets only, and include *all* of them.** Sampling live markets is survivorship
  bias in its purest form.
- **Bucket by time-to-resolution as well as price.** A 30¢ contract a month out and a 30¢ contract an
  hour out are different instruments.
- **Use the price you could have traded**, not the midpoint. Spread is a large fraction of edge in
  thin markets.
- **Weight by liquidity or exclude thin markets**, and report both. A calibration curve dominated by
  markets with $200 of depth describes a market you cannot trade.
- **Segment by category.** Sports, politics, crypto and culture markets have different participant
  mixes and different biases.

## Backtesting notes specific to this venue

- **The NO series is not `1 − YES`.** Both sides have their own book and their own spread. Backtest
  the token you would actually trade.
- **History ends at resolution.** Any pipeline that pulls "active markets" for statistics has already
  thrown away every market that resolved — which is all of the labelled data.
- **Include the fee explicitly**, using the market's own category rate. Because the fee is
  `C × rate × p × (1−p)`, a flat basis-point assumption is wrong at every price except one.
- **Prediction-market technical analysis is mostly a category error near expiry.** Prices live in
  (0,1) and converge; late-life momentum is time-decay, not sentiment. Mean-reversion behaves best
  mid-range and far from the end date. See
  [../quant/indicators/prediction-markets.md](../quant/indicators/prediction-markets.md).
- **Splits, merges, redemptions and neg-risk conversions move positions without any book trade.** A
  pipeline that infers positions from trades alone will mis-attribute them.
