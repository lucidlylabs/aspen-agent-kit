---
section: quant
group: data
title: Data quality and the errors that fake an edge
triggers: >-
  data cleaning, look ahead bias, survivorship bias, outliers, bad ticks,
  timestamp alignment, missing data, data validation, why does my backtest look too good
---

# Data quality and the errors that fake an edge

Every one of these produces a backtest that looks better than reality. That is not a coincidence:
errors that make results look worse get investigated and fixed; errors that make results look better
get celebrated and deployed. **You have to hunt for the flattering errors deliberately.**

## Look-ahead bias — the one that gets everyone

Using information at time *t* that was not available at time *t*.

The obvious forms are easy to avoid. These are the ones that actually happen:

- **Bar-close timestamps used as decision times.** A 1-hour bar stamped `10:00` usually *closes* at
  11:00. Trading "at 10:00" on that bar means acting on an hour of future information. Check whether
  your source stamps bars at open or close, and shift accordingly.
- **Indicator warm-up leaking.** Computing a rolling statistic over the whole series and then slicing
  it. Any centred window, any `.fillna(method='bfill')`, any normalisation using full-sample mean and
  standard deviation.
- **Resampling with a closed-right window** while treating the label as the decision time.
- **Restated or revised data.** Anything that gets corrected later — including venue metadata like
  leverage caps or fee tiers — must be used as-of, not as-now.
- **Symbol universes chosen with hindsight.** Selecting "the top 20 perps by volume" using today's
  volume ranking, then backtesting three years.
- **Resolution criteria known after the fact** on prediction markets. If you filter to markets with
  clean resolutions, you have used information from the future.

**The test:** at every decision point, could a program running live at that instant have computed
this number from data it already had? If you cannot answer instantly, you have a leak.

## Survivorship bias

Studying only what still exists.

- **Delisted perp markets.** Crypto venues delist markets that die. A momentum study on currently
  listed markets excludes every market that trended to zero and was removed.
- **Resolved prediction markets are the whole dataset.** Studying only *active* markets throws away
  all the labelled data and biases toward long-lived, unresolved questions.
- **Your own strategy history.** Evaluating the versions you kept.

Fix: build the universe **as of** each historical date, including things that later disappeared. If
your data source cannot tell you what was listed on a past date, that is a material limitation of
the source.

## Bad ticks, outliers, and the temptation to clean them

Real market data contains prints that are genuinely wrong — fat fingers, feed glitches, cross-venue
sync errors — and prints that look wrong but are real, like a liquidation cascade.

**The distinction matters enormously**, because the real extreme moves are where most strategies make
or lose their money. Aggressive outlier filtering systematically removes the moments that determine
your actual risk, and produces a backtest with a smooth equity curve and no tail.

Reasonable practice:

- Flag rather than delete. Keep a `suspect` column.
- Cross-check a suspicious print against another venue and against the book at that moment. A real
  move appears in both; a glitch does not.
- Use **median-based** filters (rolling median absolute deviation) rather than mean-and-standard-
  deviation, which is itself corrupted by the outliers you are trying to find.
- **Never wins-orize returns before measuring risk.** Measure risk on the raw series. If you clip
  tails for model stability, do it in the model, and report both.

## Timestamp alignment

The most under-appreciated source of fake signal.

- **Two series sampled on different clocks will manufacture correlation or destroy it**, depending on
  the offset. Resample both onto a common grid explicitly, using last-observation-carried-forward with
  an explicit staleness limit, before computing any spread, ratio or correlation.
- **Never forward-fill without a limit.** A stale price carried for six hours across a gap creates a
  flat series that looks low-volatility and mean-reverting. Both are artifacts.
- **Record venue event time and your receive time separately.** The gap is real data: it tells you
  your feed latency, and it is how you discover that an apparent signal was actually you seeing a
  stale book.
- **Beware asynchronous cross-venue data** in pairs and basis trades. If venue A's price is timestamped
  at the exchange and venue B's at your collector, the lead-lag relationship you "discover" may be
  entirely your own infrastructure.

## Volume, and what the number means

- Base units or quote value? Both are called "volume".
- Does it double-count (counting both sides of a trade)? Conventions differ across venues and vendors.
- Is reported venue volume comparable to on-chain settled volume? Usually not exactly.
- Wash trading exists, particularly around incentive programs and points seasons. Volume-based
  indicators on a market with an active incentive program are measuring the incentive, not interest.

## Prediction-market-specific traps

- **The NO series is not `1 − YES`.** Separate books, separate spreads.
- **Price history ends at resolution**, so any "current markets" pull silently excludes all labelled
  outcomes.
- **Position changes without trades.** Splits, merges, redemptions and neg-risk conversions move
  inventory with no book print. Reconstructing positions from trades alone drifts.
- **Neg-risk events split volume across legs**, so per-market liquidity understates event liquidity.
- **Placeholder outcomes ("Other") change meaning** as a field clarifies. A time series across that
  change is not one instrument.

## Perp-specific traps

- **Funding sign conventions differ by venue.** Get the sign wrong and your carry study has exactly
  the wrong answer. Validate against a period where you know who paid whom.
- **Funding is clamped on Lighter** with a floor at the interest-rate component. A cross-venue funding
  comparison that ignores the clamps overstates Lighter's carry in quiet regimes.
- **Mark vs last for triggers.** Backtesting stops on trade prices misstates both fills and
  liquidations.
- **Contract specification changes** — tick size, leverage caps, maintenance margin tiers — are not
  usually in historical data. A backtest at leverage the venue did not offer at the time is fiction.
- **Perp/spot balance separation** on Hyperliquid means "USDC balance" in a naive reconstruction may
  not have been usable margin at that moment.

## A validation pass worth running on every new dataset

1. Plot it. Actually look at it. Most corruption is visible.
2. Check monotonic, unique, gap-free timestamps at the expected frequency. Count and locate gaps.
3. Confirm `low ≤ open, close ≤ high` on every bar. Violations mean a broken source.
4. Distribution of returns: any return above ~10 sigma deserves individual inspection.
5. Count zero-volume and zero-range bars. A run of them is a feed outage, not a quiet market.
6. Cross-check a random sample of 20 points against a second source.
7. Confirm the series covers a period containing at least one violent regime change. A dataset with no
   crash in it cannot tell you anything about your tail risk.

## The meta-rule

**Reproduce your result on data you did not use to build it.** Different period, different market,
different source. Most data-quality problems and most overfitting reveal themselves the moment the
substrate changes. See [../validation/backtesting.md](../validation/backtesting.md).
