---
section: quant
group: indicators
title: Indicators — what they are, and what the evidence says
triggers: >-
  technical indicators, which indicator should I use, do indicators work,
  indicator list, RSI MACD moving average, technical analysis
---

# Indicators — what they are, and what the evidence says

An indicator is a **deterministic function of past prices, volumes, or order flow**. That is all it
is. It contains no information that was not already in its inputs; it is a lens for making a
particular structure in the data visible and machine-readable.

This matters because it bounds what an indicator can do. A moving average cannot know anything the
price series does not already say. What it can do is give you a stable, testable definition of
"trending" so that a rule can be written, backtested, and executed without human judgment. **That is
the real function of indicators in systematic trading: they turn a vague description into code.**

## The four things indicators measure

Nearly every indicator in existence is a variation on one of four measurements:

| Family | Question it answers | Card |
|---|---|---|
| **Trend** | Which direction, and how persistently? | [trend.md](trend.md) |
| **Momentum / oscillators** | How fast, and how stretched? | [momentum.md](momentum.md) |
| **Volatility** | How much is it moving? | [volatility.md](volatility.md) |
| **Volume / flow** | How much conviction and from which side? | [volume-and-flow.md](volume-and-flow.md) |

Beyond those, two families use data that classical technical analysis never had:

| Family | Question | Card |
|---|---|---|
| **Microstructure** | What does the order book say about immediate pressure and cost? | [microstructure.md](microstructure.md) |
| **Crypto-native** | What do funding, basis, open interest and liquidations say about positioning? | [crypto-native.md](crypto-native.md) |

And prediction markets need their own treatment, because prices in (0,1) that converge to a boundary
behave nothing like prices in (0,∞) that do not:
[prediction-markets.md](prediction-markets.md).

## Evidence grading

Technical analysis has an unusually wide gap between what is popular and what is supported. This kit
grades every indicator so you know which you are using. The grades:

- **A — Robust.** Documented across markets, decades and independent researchers; survives
  out-of-sample and reasonable cost assumptions. Still not a guarantee of future profit.
- **B — Supported with caveats.** Real evidence exists, but it is regime-dependent, weakened by
  transaction costs, or has visibly decayed since publication.
- **C — Mechanically useful, not predictive.** The indicator measures something real and is valuable
  as a *state variable* — for sizing, filtering, or risk — but does not generate profitable entry
  signals on its own.
- **D — Folklore.** Popular, widely taught, and not supported by evidence that survives multiple
  testing correction and costs.

**Most classic chart indicators are C.** That is not a dismissal. A C-grade indicator used as a
volatility scaler or a regime filter can be worth far more than a B-grade one used as a trigger.

### What the literature actually found

Worth knowing, because it explains the grades:

- **Moving-average rules showed real predictive power in early studies** — Brock, Lakonishok &
  LeBaron (1992) found statistically significant results for simple MA and range-breakout rules on
  the Dow over 90 years.
- **Then data-snooping correction ate most of it.** Sullivan, Timmermann & White (1999) applied
  White's Reality Check across the *universe* of rules those studies had implicitly searched, and
  found the apparent significance largely disappeared once you account for how many rules were tried.
  This is the single most important methodological result in technical analysis, and it generalises:
  **if you searched, you must correct.**
- **The comprehensive survey is mixed.** Park & Irwin (2007) reviewed ~95 modern studies: a majority
  reported positive results, but with widespread methodological problems — data snooping, ex-post rule
  selection, and difficulties in estimating risk and transaction costs.
- **Momentum survived where chart patterns did not.** Jegadeesh & Titman (1993) documented
  cross-sectional momentum; Moskowitz, Ooi & Pedersen (2012) documented time-series momentum across
  58 instruments and multiple decades; Asness, Moskowitz & Pedersen (2013) found momentum and value
  across asset classes. This is the closest thing to an A grade in the whole space.
- **Some pattern recognition has genuine content.** Lo, Mamaysky & Wang (2000) formalised chart
  patterns with kernel regression and found several do convey incremental information — but
  *information* is not the same as a tradable edge after costs.
- **The bar for a new finding is high.** Harvey, Liu & Zhu (2016) argue that given the number of
  factors tested in the literature, a t-statistic of about 3.0 is a more appropriate threshold than
  the conventional 2.0. Apply the same logic to your own research.

Full citations in [../references.md](../references.md).

## How to actually use an indicator

**1. Start from the mechanism, not the indicator.** Decide what you believe is happening — "crowded
positioning unwinds", "liquidity providers demand compensation in volatile regimes" — then choose the
measurement that captures it. Choosing an indicator first and searching for where it works is the
definition of overfitting.

**2. Prefer indicators as state, not as trigger.** The highest-value use of most indicators is
answering "what regime am I in, and how big should I be?" rather than "should I buy now?" Volatility
in particular is far more reliably useful for sizing than for direction.

**3. Do not stack correlated indicators.** RSI, stochastic, CCI and Williams %R are near-identical
transformations of the same information. Three of them agreeing is one opinion repeated, not
confirmation. If you want confirmation, use indicators from *different families* — a trend measure
plus a flow measure plus a volatility measure.

**4. Normalise before comparing across markets.** A 20-point RSI move on BTC and on a thin altcoin
perp are not comparable. Convert to volatility-adjusted or percentile terms if the rule spans markets.

**5. Fewer parameters, always.** Each parameter multiplies the search space and therefore the
overfitting. A rule with one lookback tested on ten values is a different statistical object from a
rule with four parameters tested on ten values each.

**6. Test parameter stability, not parameter optimum.** If a lookback of 20 works and 18 and 22 fail,
you found noise. A real effect is a plateau, not a spike. **Always plot the parameter surface.**

**7. Model the cost of the turnover the indicator implies.** A fast indicator generates more signals
and therefore more cost. Compute the fee drag *before* evaluating the signal — see
[../../perpetuals/fees.md](../../perpetuals/fees.md). This kills most short-lookback strategies before
any statistics are needed.

## The honest summary

Indicators are a vocabulary, not a strategy. The edge, when it exists, comes from **a mechanism that
explains why someone is on the other side of your trade and why they will keep being there.**
Indicators make that mechanism measurable and executable. They do not supply it.

If you cannot state who is paying you and why, no indicator will fix that.
