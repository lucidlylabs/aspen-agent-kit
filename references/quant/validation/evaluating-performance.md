---
section: quant
group: validation
title: Evaluating performance
triggers: >-
  sharpe ratio, sortino, calmar, drawdown, deflated sharpe, is my strategy good,
  performance metrics, statistical significance, how many trades do I need
---

# Evaluating performance

Return alone is meaningless without risk, and risk-adjusted return is meaningless without accounting
for how many strategies you tried. This card is about getting to an honest number.

## The metrics, and what each hides

**Sharpe ratio** = `(mean return − risk-free) / standard deviation`, annualised by `× √periods`.

The default, and it has three real problems:
- **It penalises upside volatility** identically to downside, which mis-ranks positive-skew strategies
  like trend following.
- **It assumes returns are roughly normal.** Crypto returns are not, and strategies with hidden tail
  risk (short volatility, grid, selling longshots) show *excellent* Sharpe right up until they do not.
  **A high Sharpe from a negatively skewed strategy is a warning, not a result.**
- **It is noisy.** The standard error of an estimated Sharpe is roughly `√((1 + S²/2)/n)`. With a year
  of daily data you cannot reliably distinguish a Sharpe of 0.5 from 1.5.

Rough interpretation for a *live, out-of-sample, fully costed* result: below 0.5 is not worth the
operational risk; 1–2 is a genuinely good systematic strategy; above 3 sustained is either
high-frequency, a very short sample, or a bug. **A backtest Sharpe above 3 should increase your
suspicion, not your confidence.**

**Marking frequency can manufacture a Sharpe outright.** A product that marks only at period
boundaries can report an annualised Sharpe near **19** while a fill-level reconstruction of the same
book shows intra-period drawdowns far larger than that volatility could produce. Nothing was
falsified; the reported series simply never sampled the risk. **Before comparing any Sharpe, ask at
what frequency the underlying series was marked** — a number computed from monthly or epoch-boundary
marks is not comparable to one computed from daily marks of the same strategy.

**Sortino** — same, but only downside deviation in the denominator. Better for asymmetric strategies.

**Calmar / MAR** = annualised return / maximum drawdown. Crude, and closest to what actually
determines whether you can keep running a strategy.

**Maximum drawdown** — the most practically important single number, because it determines survival
and whether you will abandon the strategy at the worst moment. Note that observed maximum drawdown is
a **downward-biased** estimate of what is possible: your sample almost certainly does not contain the
worst case.

**Profit factor** = gross profit / gross loss. Simple and hard to game. Below ~1.2 after real costs,
the edge is too thin to survive estimation error.

**Win rate is nearly useless on its own.** A 90% win rate with a catastrophic 10% is a losing
strategy; a 35% win rate is normal and healthy for trend following. Always pair it with average
win/loss.

## Deflated Sharpe: the number that accounts for your search

Bailey & López de Prado's **deflated Sharpe ratio** adjusts an observed Sharpe for:
- the **number of trials** you ran,
- the **variance of Sharpe ratios** across those trials,
- **non-normality** (skew and kurtosis) of the returns,
- the **length** of the track record.

It answers the question that matters: *given that I tried N things, how surprising is this result?*

Closely related is the **probability of backtest overfitting (PBO)**, estimated by combinatorially
splitting your data and asking how often the in-sample best performer underperforms out-of-sample. A
PBO above ~50% means your selection process is worse than random.

**If you take one thing from this card:** an unadjusted Sharpe from a search process is not a
statistic, it is the maximum of a sample of noise. Report the trial count alongside every result.

## How much data do you need?

More than you have. Some honest bounds:

- **Trade count matters more than calendar time.** Fewer than ~100 trades gives you essentially no
  statistical power. A few hundred is a minimum for a weak conclusion.
- **Regime coverage matters more than trade count.** A strategy tested over two years of a bull market
  has been tested on one observation of the thing that matters.
- **To distinguish a Sharpe of 1.0 from 0 at conventional significance takes roughly 4 years of
  daily data.** To distinguish 1.0 from 0.5 takes far longer. This is a hard bound and no amount of
  cleverness removes it.

The implication is uncomfortable and worth accepting: **for most retail-scale strategies you will
never have statistical certainty.** That is why the mechanism matters so much, why cost modelling
matters so much, and why fractional sizing matters so much. You are managing under irreducible
uncertainty, not resolving it.

## The metrics people forget

- **Turnover and holding period.** Compare live vs backtest. A live trade count double the backtest
  means something is structurally different.
- **Implementation shortfall vs modelled cost.** The direct test of whether your execution assumptions
  hold ([../execution/order-placement.md](../execution/order-placement.md)).
- **Capacity.** At what size does the edge disappear? Estimated from impact
  ([../indicators/microstructure.md](../indicators/microstructure.md#price-impact-and-kyles-lambda)).
- **Correlation to a simple benchmark.** If your strategy correlates 0.9 to long BTC, you have an
  expensive way to be long BTC. Compute the alpha net of that beta.
- **Time in market.** A 30% annualised return that is only deployed 20% of the time is a different
  proposition from one always deployed — better on a risk-adjusted basis, worse on capital efficiency.
- **Return per unit of margin actually locked**, not per unit of notional.

## Scoring rules for prediction markets

Where you make explicit probability forecasts, evaluate the *forecast* rather than the PnL — it is far
less noisy and gives you a verdict much sooner.

- **Log score** = `mean(−ln(p_assigned_to_actual_outcome))`. The proper scoring rule corresponding to
  Kelly growth. Use this to evaluate a model.
- **Brier score** = `mean((forecast − outcome)²)`. More intuitive; 0.25 is the always-say-50% baseline.

**Benchmark against the market price itself.** If your forecasts do not beat the market's own price as
a predictor, you have no edge — and you will know this after ~100 resolved markets, long before PnL
could tell you.

## A reporting template

For any strategy, report together:

```
period, number of markets, number of trades
gross return / net return (state cost assumptions explicitly)
Sharpe, Sortino, max drawdown, Calmar
skew and kurtosis of returns
number of trials run to arrive at this configuration
deflated Sharpe
correlation to benchmark; alpha net of beta
turnover, average holding period
estimated capacity
```

If the report omits the trial count and the cost assumptions, it is not a result. Those two are what
separate a finding from a story.
