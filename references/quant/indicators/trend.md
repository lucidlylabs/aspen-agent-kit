---
section: quant
group: indicators
title: Trend indicators
triggers: >-
  moving average, SMA, EMA, WMA, MACD, ADX, donchian, ichimoku, supertrend,
  golden cross, trend following, crossover
---

# Trend indicators

**What they measure:** direction and persistence, by smoothing away high-frequency variation.

**The core trade-off, which every trend indicator is just a different answer to:** smoothing reduces
noise and adds lag. There is no setting that removes both. Everything below is a different point on
that curve.

## Moving averages

### Simple (SMA)

`SMA_n = mean(close, n)`. Equal weight to every observation in the window; zero weight outside it.

- **Lag ≈ n/2 bars.**
- The sharp cutoff at the window edge causes a real artifact: a large value dropping *out* of the
  window moves the average as much as a new value coming in. Price "moves" with no new information.

### Exponential (EMA)

`EMA_t = α·P_t + (1−α)·EMA_{t−1}`, with `α = 2/(n+1)`.

- Weights decay geometrically; no window-edge artifact.
- **Lag ≈ (n−1)/2**, comparable to SMA at the same *n*, but reacts faster to recent moves.
- Infinite memory in principle, which matters when you initialise it — seed with an SMA and discard
  a warm-up period, or your first few hundred values carry initialisation error.

### Others worth knowing

- **WMA** — linearly declining weights. Between SMA and EMA.
- **Hull MA (HMA)** — a WMA construction designed to cut lag substantially. Smoother and faster, at
  the cost of overshoot after sharp moves.
- **KAMA (Kaufman Adaptive)** — adjusts the smoothing constant by an efficiency ratio
  (net move / sum of absolute moves). Fast in trends, slow in chop. **This is the most useful
  variation for crypto**, where regime shifts between grinding and violent are extreme.
- **Ehlers filters** — moving averages designed with signal-processing methods to control lag and
  frequency response explicitly. Worth reading if you are going to build your own.

### Grade

**B for the crossover rule; A for the underlying time-series momentum effect.**

Simple MA rules had genuine documented predictive power (Brock, Lakonishok & LeBaron 1992), most of
which did not survive data-snooping correction (Sullivan, Timmermann & White 1999) — the rule was
selected from an enormous implicit search space. But the *effect* the rule crudely captures —
time-series momentum — is one of the best-documented phenomena in finance (Moskowitz, Ooi & Pedersen
2012), across dozens of instruments and many decades.

**The practical reading:** trend-following works; the specific crossover parameters people argue about
mostly do not matter and are usually overfit. Zakamulin's work on MA timing rules makes this point
carefully — many popular variants are mathematically near-identical, and their apparent differences
in backtests are noise.

### Using them properly

- **Slope, not crossover.** `MA_t − MA_{t−k}` normalised by volatility is a cleaner and more stable
  trend measure than a binary crossover, and it gives you a magnitude for sizing.
- **Normalise the distance.** `(price − MA) / ATR` is comparable across markets and regimes; raw
  distance is not.
- **Long lookbacks only, unless you have proven otherwise.** Trend effects are documented at horizons
  of roughly 1–12 months. Fast crossovers on 5-minute bars in crypto are a fee-generation machine
  ([../../perpetuals/fees.md](../../perpetuals/fees.md)).
- **Expect frequent small losses.** Trend following has a low win rate and positive skew: many small
  losses in chop, occasional large wins. If your equity curve does not look like that, you are not
  running a trend strategy.

## MACD

`MACD = EMA_fast − EMA_slow`; `signal = EMA(MACD, k)`; `histogram = MACD − signal`. Conventionally
12/26/9.

It is a **normalised difference of two moving averages** — an oscillator built from trend components,
which is why it is often misfiled as a momentum indicator. The histogram is the second derivative:
it measures whether the trend is accelerating.

- **Grade: C.** No robust standalone evidence; the 12/26/9 defaults are arbitrary artifacts of a
  pre-computer era. Useful as a compact, smooth trend-strength state variable.
- **Divergence** (price makes a new high, MACD does not) is popular and **weakly supported at best**.
  It has no natural false-positive control: in any extended trend, divergence appears repeatedly and
  most instances resolve by the indicator catching up, not by price reversing.

## ADX / DMI (Wilder)

Directional Movement measures whether the market is trending *at all*, without saying which way.
`+DI` and `−DI` measure directional pressure; **ADX measures trend strength regardless of direction**.

- Conventional reading: ADX > 25 trending, < 20 ranging. These thresholds are conventions, not
  findings — calibrate them per market on your own data.
- **Grade: C, and genuinely useful at C.** ADX is one of the better regime filters available. Its
  proper role is not "when to enter" but "which family of strategy is appropriate right now":
  trend-following in high-ADX regimes, mean-reversion or grid strategies in low-ADX regimes.
- ADX is lagging by construction (it is a smoothed average of smoothed values). It confirms regimes;
  it does not anticipate them.

## Donchian channels / breakout

The highest high and lowest low of the last *n* periods. A close above the upper channel is a
breakout.

- **Grade: B.** This is the core of the original Turtle system and its logic is sound: a breakout is
  a factual statement that price has exceeded all recent supply. It is essentially a non-parametric
  trend entry.
- Widely known and therefore crowded around round lookbacks (20, 55). Its edge has decayed but the
  underlying momentum effect it exploits has not.
- **False breakouts are the failure mode**, and they cluster in low-volatility regimes. Pairing a
  Donchian entry with a volatility or ADX filter addresses the main weakness.
- The natural companions are an **ATR-based stop** and **ATR-based position sizing** — the Turtle
  approach — which is really where that system's robustness came from. See
  [../risk/position-sizing.md](../risk/position-sizing.md).

## Ichimoku, SuperTrend, Parabolic SAR

- **SuperTrend** — an ATR-banded trend follower. Mechanically a trailing stop; reasonable as one.
  **Grade C.**
- **Parabolic SAR** (Wilder) — an accelerating trailing stop. Whipsaws badly in ranges by design.
  **Grade C**, and best understood as an exit rule rather than an entry signal.
- **Ichimoku** — a multi-component system (five lines) that bundles trend, momentum and support in one
  visual. Its components are moving averages of midpoints. **Grade D as a system**: the number of
  free parameters and interpretive rules makes it very hard to test honestly, and the standard
  settings derive from a 6-day trading week that no longer exists — least of all in 24/7 crypto.

## Practical guidance for these venues

- **On perps, trend strategies are the natural fit for the fee structure**: low turnover, long holds,
  fee drag near-irrelevant. The dominant cost is funding, not fees — a sustained long in a
  positive-funding regime pays carry continuously, which can quietly exceed the trend edge. Always
  compute expected funding over the intended hold ([crypto-native.md](crypto-native.md)).
- **Trend measures on prediction markets are usually a category error.** See
  [prediction-markets.md](prediction-markets.md).
