---
section: quant
group: indicators
title: Volatility indicators and estimators
triggers: >-
  ATR, bollinger bands, keltner, realized volatility, parkinson, garman klass,
  yang zhang, GARCH, volatility clustering, vol targeting, standard deviation
---

# Volatility indicators and estimators

**This is the most useful family in the toolkit**, and the one most often misused as a direction
signal. Volatility does not tell you which way price will go. It tells you **how big to be**, where
to put a stop, and which strategy family is currently appropriate — and it does those things better
than anything else you have.

## Why volatility is the highest-value measurement

Two facts, both robust:

1. **Volatility clusters.** Large moves follow large moves (Mandelbrot 1963; formalised by Engle 1982
   and Bollerslev 1986 in ARCH/GARCH). Volatility is genuinely, strongly predictable at short
   horizons — far more so than returns.
2. **Returns are barely predictable.** Whatever edge you have in direction is small.

So you have one quantity you can forecast well and one you can forecast badly. **Build your system so
the well-forecast quantity does the heavy lifting.** That means volatility-based sizing, volatility-
scaled signals, and volatility-based stops. This one idea improves more strategies than any entry
signal.

## ATR — Average True Range (Wilder, 1978)

True Range for a bar is `max(high−low, |high−prev_close|, |low−prev_close|)`. ATR is its smoothed
average (Wilder's smoothing, ~ an EMA).

The `prev_close` terms matter: they capture gaps. In 24/7 crypto gaps are rare, so ATR ≈ average
range — but on Lighter's RWA, pre-IPO and equity-linked markets, which do gap, the distinction is
real.

**Grade: A as a state variable.** Not a direction signal; not intended as one.

Uses, all of them good:

- **Position sizing.** Size so that an *N*-ATR adverse move costs a fixed fraction of equity. This is
  the Turtle approach and it is the single most valuable use of any indicator:
  `size = (equity × risk_per_trade) / (N × ATR)`.
- **Stop placement.** Stops at a fixed percentage are wrong in both directions: too tight in volatile
  regimes (stopped out by noise), too loose in quiet ones (risking more than intended). ATR-based
  stops adapt automatically.
- **Normalisation.** `(price − MA) / ATR` makes a distance comparable across markets and time.
- **Regime classification.** ATR relative to its own longer-run average distinguishes quiet from
  violent regimes.

**Watch out:** ATR is an absolute quantity in price units. Use `ATR / price` when comparing across
assets or across a long history where price level changed materially.

## Bollinger Bands

`MA ± k × rolling_std(close, n)`, conventionally n=20, k=2.

- **Grade: C.** Popular, mechanically informative, no robust standalone edge.
- **The most common misuse:** "price touched the upper band, sell." In a trending market price walks
  the band for extended periods. This is the RSI failure mode again with a different picture.
- **The genuinely useful derivative is bandwidth:** `(upper − lower) / MA`. Low bandwidth = a
  volatility contraction. Volatility clustering means contraction tends to be followed by expansion —
  this is one of the few *predictive* uses of a classical indicator, and it forecasts **magnitude,
  not direction**. It is a legitimate way to time when to *arm* a breakout strategy.
- **%B** — `(price − lower) / (upper − lower)` — is where price sits in the band, i.e. a z-score in
  disguise. Just use the z-score.

## Keltner Channels

`EMA ± k × ATR`. Bollinger with ATR instead of standard deviation.

Because ATR includes gaps and is less sensitive to a single outlier bar than standard deviation,
Keltner channels are typically **more stable** than Bollinger bands. The "squeeze" (Bollinger bands
inside Keltner channels) is a widely used volatility-contraction signal; it is a reasonable
contraction detector and a poor direction signal. **Grade C.**

## Realised volatility: use a better estimator

Close-to-close standard deviation of returns throws away most of the information in a bar. If you
have OHLC, use a range-based estimator — they are dramatically more efficient (lower variance for the
same sample size), which matters enormously when you are estimating on short windows.

| Estimator | Uses | Efficiency vs close-to-close | Note |
|---|---|---|---|
| **Close-to-close** | C | 1× | The default. The worst option when OHLC is available. |
| **Parkinson (1980)** | H, L | ~5× | Assumes no drift, no gaps. Underestimates when there is a trend. |
| **Garman–Klass (1980)** | O, H, L, C | ~7× | More efficient still; assumes no gaps. |
| **Rogers–Satchell (1991)** | O, H, L, C | ~6× | **Handles drift** — important for trending crypto. |
| **Yang–Zhang (2000)** | O, H, L, C | ~8–14× | Handles both drift and overnight gaps. Generally the best choice when you have clean OHLC. |

**Practical guidance:** Yang–Zhang or Rogers–Satchell for crypto perps, where drift within a bar is
common. All range estimators **underestimate** true volatility somewhat because the observed high and
low are sampled discretely — the effect grows as bars get shorter or markets thinner.

**Even better, if you have trade data:** realised volatility as the sum of squared high-frequency
returns over the period (Andersen & Bollerslev 1998). This is the modern standard and it is a direct
measurement rather than an estimate. Beware microstructure noise at very high sampling frequencies —
sample at 1–5 minutes rather than tick-by-tick, or use a noise-robust estimator.

## Forecasting volatility

- **EWMA** — `σ²_t = λσ²_{t−1} + (1−λ)r²_t`. One parameter, no fitting, and a genuinely strong
  baseline. Start here.
- **GARCH(1,1)** — the classical model; captures clustering and mean-reversion in volatility. Rarely
  beaten by much for one-step-ahead forecasting, and hard to beat convincingly.
- **HAR-RV** (Corsi 2009) — a simple regression of realised volatility on its daily, weekly and
  monthly averages. Excellent forecasts for very little complexity if you have realised volatility.

For most trading purposes **EWMA is sufficient**, and the effort is better spent elsewhere. The
forecast horizon should match your holding period; a 1-day volatility forecast is not the right
scaler for a 3-week position.

## Volatility as a regime switch

The practical payoff. Different strategy families work in different volatility regimes, and volatility
is forecastable, so this is actionable:

| Regime | Works | Fails |
|---|---|---|
| **Low vol, low ADX** | Mean reversion, grid, market making, carry | Breakouts (false), trend |
| **Rising vol / expansion** | Breakout, trend entry | Grid (range breaks), short-vol anything |
| **High vol, trending** | Trend following with wide stops | Mean reversion, grid, tight stops |
| **High vol, no trend** | Reduce size or stand aside | Nearly everything |

**The rule that matters most:** volatility targeting. Scale position size inversely to forecast
volatility so risk contribution stays roughly constant. Doing only this to an existing strategy
typically improves its risk-adjusted return, because it stops the strategy from taking its largest
risk exactly when the market is most dangerous. See
[../risk/position-sizing.md](../risk/position-sizing.md).

## Crypto-specific notes

- **Volatility is strongly periodic** by hour of day and day of week. A volatility estimate that
  ignores this will systematically over-size during quiet hours and under-size during active ones.
- **Perp volatility and liquidation cascades are reflexive.** High leverage in the system means a
  large move triggers liquidations which cause a larger move. Volatility is not exogenous — see the
  open-interest and liquidation discussion in [crypto-native.md](crypto-native.md).
- **Implied volatility** is available from options venues for major assets and is a forward-looking
  measure your price history cannot give you. The spread between implied and realised volatility is
  itself a tradable signal and a useful regime indicator even if you never trade options.
