---
section: quant
group: indicators
title: Momentum indicators and oscillators
triggers: >-
  RSI, stochastic, CCI, williams %R, rate of change, oscillator, overbought,
  oversold, divergence, momentum, cross sectional momentum
---

# Momentum indicators and oscillators

Two different things share this name, and conflating them is a common and costly error.

1. **Momentum as a return-continuation effect** — "what went up keeps going up". Documented,
   persistent, exploited by large systematic funds. **Grade A.**
2. **Oscillators** — bounded transforms of recent price position, used to call "overbought" and
   "oversold". Popular, and mostly the *opposite* of the first thing. **Grade C.**

The first is trend. The second is mean-reversion in a trench coat. Know which you are using.

## Momentum, the effect (Grade A)

**Cross-sectional momentum** (Jegadeesh & Titman 1993): rank assets by trailing return over 3–12
months, go long the top, short the bottom. Documented in equities, then in currencies, commodities,
bonds and indices (Asness, Moskowitz & Pedersen 2013).

**Time-series momentum** (Moskowitz, Ooi & Pedersen 2012): an instrument's own past 12-month excess
return predicts its next-month return, across 58 instruments over decades. This is the effect
underlying managed futures as an industry.

**How to use it on perps:**

```
signal_i = trailing_return_i(lookback) / realised_volatility_i(lookback)
```

Rank the perp universe by that; go long the top *k*, short the bottom *k*, sized inversely to
volatility. That is the whole strategy, and its robustness comes from breadth and from
volatility-normalisation, not from clever entry timing.

Caveats that matter in crypto:

- **The documented horizons are 1–12 months.** Intraday "momentum" is a different phenomenon with a
  different mechanism (order flow and liquidity) and it is priced by microstructure, not by this
  literature.
- **Crypto perp universes are small and highly correlated.** A long-top/short-bottom book on 20 perps
  that all correlate 0.8 to BTC is close to a leveraged bet on dispersion, not a market-neutral book.
  Measure the residual beta and hedge it explicitly.
- **Momentum crashes.** The effect has severe, rapid drawdowns at regime turns — precisely when
  positioning is most crowded. Funding is your crowding gauge here
  ([crypto-native.md](crypto-native.md)); rich funding on the side you are already long is a warning.
- **Skip the most recent period.** The standard construction (e.g. 12-month return skipping the last
  month) exists because very-short-horizon returns tend to reverse.

## RSI (Wilder, 1978)

`RSI = 100 − 100/(1 + RS)`, where `RS` = average gain / average loss over *n* periods (Wilder's
smoothing, not a simple mean). Bounded 0–100. Default *n* = 14.

**What it actually measures:** the proportion of recent movement that was upward. That is all.

- **Grade: C.** No robust standalone evidence. The conventional 70/30 thresholds are arbitrary.
- **The critical failure mode:** RSI stays "overbought" for the entire duration of a strong trend.
  Selling at RSI 70 in a bull market is a systematic way to be short a trend. **RSI as a
  counter-trend trigger is one of the most reliable ways for a retail strategy to lose money.**
- **Better uses:**
  - As a **regime-conditional** signal: mean-revert on RSI extremes *only* when a trend filter (ADX
    low, or price inside a range) says the market is not trending.
  - **Normalised across markets** — RSI is already bounded, which makes it one of the few indicators
    directly comparable across instruments without rescaling.
  - As a **feature**, not a rule, if you are fitting a model.
- **Divergence:** popular, weakly supported. In a strong trend it fires repeatedly and resolves by the
  oscillator catching up. If you use it, you must define and test a false-positive control.

## Stochastic oscillator

`%K = 100 × (close − low_n) / (high_n − low_n)`; `%D = SMA(%K, 3)`. Position of the close within the
recent range.

- **Grade: C.** Nearly the same information as RSI. Reacts faster and is noisier.
- "Fast" vs "slow" stochastic is just how much smoothing you apply.
- Same trend failure mode as RSI, more pronounced.

## CCI, Williams %R, ROC

- **CCI** — `(typical price − SMA) / (0.015 × mean deviation)`. Unbounded in principle. A
  normalised distance-from-mean, i.e. a z-score with an odd constant. **Grade C.**
- **Williams %R** — stochastic inverted and rescaled to −100..0. Mathematically almost the same
  indicator. **Grade C.**
- **Rate of Change / Momentum** — `P_t / P_{t−n} − 1`. The rawest form, and honestly the most useful
  of this group precisely because it is untransformed: it is the actual return, which is the quantity
  the momentum literature is about. **Grade A when used at documented horizons**, C at short ones.

## The redundancy problem

RSI, stochastic, CCI, Williams %R and MACD histogram are highly correlated by construction. They are
different normalisations of "where is price relative to its recent range and how fast did it get
there".

**Three of them agreeing is one opinion stated three times.** A confirmation stack built from this
family gives you false confidence and no additional information. If you want genuine confirmation,
combine across families: a trend measure ([trend.md](trend.md)), a flow measure
([volume-and-flow.md](volume-and-flow.md)), and a positioning measure
([crypto-native.md](crypto-native.md)) are genuinely different views.

## The z-score: the oscillator worth using

If you want a bounded measure of "how stretched is this", use a z-score of the quantity you actually
care about rather than a named indicator:

```
z_t = (x_t − rolling_mean(x, n)) / rolling_std(x, n)
```

Advantages over RSI and friends: it is interpretable in standard deviations, directly comparable
across markets and across quantities, has one parameter, and applies to spreads, ratios and funding
rates just as easily as to price.

This is the standard construction underlying pairs trading and statistical arbitrage
([../strategies/stat-arb-pairs.md](../strategies/stat-arb-pairs.md)) and it is what a mean-reversion
strategy should be built on. **Grade B**, with the crucial caveat that a z-score of a
**non-stationary** series is meaningless — the mean you are reverting to must actually exist. Test
for it (ADF/KPSS) rather than assuming.

## Applying momentum on these venues

- **Perps:** the funding cost of holding a momentum position for weeks can exceed the momentum edge.
  A crowded trend has rich funding by definition. Net the two before concluding the trade is good.
- **Prediction markets:** momentum in probability space is largely information arrival plus time
  decay, not the return-continuation effect. See [prediction-markets.md](prediction-markets.md).
