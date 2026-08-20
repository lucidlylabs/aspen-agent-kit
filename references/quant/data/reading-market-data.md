---
section: quant
group: data
title: Reading market data
triggers: >-
  how to read a chart, candlestick, OHLCV, what is a candle, bars, tick bars,
  volume bars, dollar bars, resampling, log returns, mark price vs mid, stationarity
---

# Reading market data

Before any indicator, understand what you are looking at. Most bad quantitative work is not bad
modelling — it is confident modelling of a series the analyst had not thought carefully about.

## What actually exists

The market emits three things. Everything else is derived.

1. **Trades (prints).** A price, a size, a timestamp, and usually an aggressor side. This is the only
   record of transactions that actually happened.
2. **Quotes / the order book.** Resting intentions at each price level. Not transactions — offers,
   which can be withdrawn. The book is the market's *supply curve*, and most of it is not real in the
   sense of being available to you at size.
3. **Venue-computed reference prices.** Mark price, index price, oracle price, midpoint. These are
   constructions, each with a purpose.

**Which price to use, for what:**

| Price | Definition | Use it for |
|---|---|---|
| **Last trade** | price of the most recent print | almost nothing — it is stale and side-biased |
| **Mid** | (best bid + best ask) / 2 | valuation, PnL marking, spread measurement |
| **Micro-price** | size-weighted between bid and ask | short-horizon fair value; better than mid when the book is lopsided |
| **Mark** | venue's fair price, usually blending index and book | **liquidation and trigger logic** — this is what the venue uses |
| **Index / oracle** | external reference, often a basket of spot venues | funding calculations, basis measurement |

Using last-trade where the venue uses mark is a common and expensive error: your backtest fires stops
that reality would not have, and misses ones it would.

## What a candle is, and what it destroys

An OHLCV bar aggregates every print in an interval into five numbers: **open, high, low, close,
volume**. It is a lossy compression, and the losses are not random.

What survives: the range (high−low), the net move (close−open), and the activity level.

What is destroyed:
- **Path.** Whether price went up-then-down or down-then-up inside the bar. This is why you cannot
  honestly backtest an intrabar stop-and-target on candle data alone — you do not know which was hit
  first. This single ambiguity is responsible for an enormous fraction of backtests that look great
  and fail live.
- **Sequence and timing.** Fifty prints in the first second look identical to fifty spread evenly.
- **Side.** Whether volume was aggressive buying or aggressive selling.
- **Spread.** The bar tells you nothing about what it cost to transact.

### Reading a candle honestly

The folklore around candlestick shapes is mostly unfounded, but the *mechanical* content of a bar is
real and worth reading:

- **Body (open→close)** is net directional pressure over the interval.
- **Wicks (high/low beyond the body)** are prices that were reached and rejected. A long upper wick
  means sellers were willing to transact meaningfully above where the bar closed — genuine
  information about where supply sits.
- **Range relative to recent range** is the useful volatility read. A bar with 3× the recent average
  range is a regime signal regardless of its colour.
- **Volume relative to recent volume** tells you how much conviction is behind the move. Price moves
  on thin volume revert more often than moves on heavy volume.

What a single candle does **not** reliably tell you is direction. The named single-bar and two-bar
patterns (hammers, engulfings, dojis) have been tested extensively and do not survive transaction
costs as standalone signals. Use bar structure as *context* — where price was rejected, how volatile
the regime is — not as a trigger. See [../indicators/README.md](../indicators/README.md) on evidence
grading, and [../strategies/trend-momentum.md](../strategies/trend-momentum.md) for what does hold up.

## Time bars are a bad default

Sampling every *N* minutes is a convention inherited from open-outcry hours, not a statistical
choice. Markets do not deliver information at a constant rate: a 1-minute bar during a liquidation
cascade and a 1-minute bar at 4am contain wildly different amounts of information.

Consequences of time bars: heteroskedastic returns, fat tails, serial correlation in volatility, and
oversampling of quiet periods while undersampling exactly the moments that matter.

**Alternative bar types** (López de Prado, *Advances in Financial Machine Learning*, ch. 2):

| Bar type | New bar every… | Why |
|---|---|---|
| **Tick bars** | N transactions | samples by activity rather than clock |
| **Volume bars** | N units of base volume | closer to i.i.d. returns than tick bars |
| **Dollar bars** | N units of quote value traded | **usually the best default** — robust to price level changing over time, and to supply changes |
| **Imbalance / runs bars** | when signed order flow exceeds a threshold | samples when informed flow arrives |

Dollar bars in particular produce return series that are closer to normally distributed and closer to
serially independent than time bars — which matters because nearly every statistical test you will
run assumes something like that.

For crypto perps, which trade 24/7 with enormous variation in intensity, this is not a subtle
improvement. **If you are getting inconsistent results across timeframes, bar construction is one of
the first things to examine.**

That said: time bars are what venue candle endpoints give you, and they are fine for slow strategies
(daily carry, multi-day trend). Build dollar bars from your own trade recording when you are working
at intraday horizons.

## 24/7 markets, sessions, and boundaries

Crypto perps never close, which removes the overnight gap but creates its own problems:

- **There is no natural "day".** A daily bar depends entirely on where you cut it, and UTC midnight is
  a convention, not a fact. Test your strategy's sensitivity to the cut point; if it disappears when
  you shift the boundary by six hours, you found an artifact.
- **Activity is strongly periodic** by hour-of-day and day-of-week, tracking Asian, European and US
  waking hours. Any statistic computed without accounting for this will be dominated by when you
  sampled.
- **Funding timestamps are boundaries** that matter — positions held across them pay or receive.
- **RWA, pre-IPO and equity-linked markets on Lighter do have sessions**, and their price formation
  is not continuous. Do not apply 24/7 crypto intuitions to them.
- **Prediction markets have a terminal date**, which makes time-to-resolution a first-class variable
  rather than an afterthought.

## Returns, and why log

Work in **log returns** `r = ln(P_t / P_{t-1})` for analysis:

- They are additive across time — the sum of log returns is the log return of the period.
- They are roughly symmetric around zero, so a +10% and a −10% move are comparable in magnitude.
- They keep prices positive under any model you build on top.

Use **simple returns** when aggregating across positions in a portfolio at a point in time, because
those are the ones that add up across assets. Mixing the two silently is a common source of small,
persistent errors in performance figures.

**Volatility scales with the square root of time** under independence: an hourly vol of σ implies a
daily vol of roughly `σ × √24`. This is the standard convention for annualising and comparing, and
it is also an assumption that breaks precisely when volatility clusters — which it always does. Use
it to compare magnitudes, not to compute risk limits.

## Stationarity, and the trade-off nobody mentions

Most statistical methods assume stationarity — stable mean and variance. Prices are emphatically not
stationary; returns are much closer.

But differencing prices into returns destroys *memory*: the level information that says "we are near
the top of a three-month range" is gone. **Fractional differentiation** (López de Prado, ch. 5) takes
a fractional difference `d ∈ (0,1)` — the minimum needed to pass a stationarity test while retaining
as much memory as possible. It is one of the highest-value, least-used techniques for anyone feeding
price data into a statistical model.

## Labelling, if you are doing anything predictive

The naive target — "did price go up over the next N bars" — is a poor label. It ignores the path, and
in real trading the path decides whether you were stopped out before being right.

**Triple-barrier labelling** sets three exits: a profit target, a stop loss, and a time limit,
and labels each observation by which barrier was hit first. It is the label that actually corresponds
to how a trade resolves. Set the horizontal barriers as multiples of a **volatility estimate at the
time of the observation**, not as fixed percentages, or your labels mean different things in
different regimes.

Related: **sample weighting**. Overlapping labels (bar *t* and bar *t+1* both looking forward 20 bars)
are not independent observations, and treating them as such inflates every significance test you run.

## Checklist before you trust a series

- Do I know whether these timestamps are venue event time or my receive time?
- Are they all in one timezone, in UTC, and are they open-time or close-time on the bar?
- Is this mark, index, mid, or last — and is it the one the venue uses for what I am modelling?
- Are there gaps, and are the gaps real (no trading) or missing (feed dropped)?
- Does the volume figure mean base units or quote value?
- For a spread or a ratio between two series: are they sampled on the same clock?

Next: [data-sources.md](data-sources.md) for where to get it, and
[data-quality.md](data-quality.md) for what to check before trusting it.
