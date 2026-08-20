---
section: quant
group: validation
title: Backtesting without fooling yourself
triggers: >-
  backtest, overfitting, walk forward, out of sample, cross validation,
  paper trading, why did my strategy fail live, data snooping, purged CV
---

# Backtesting without fooling yourself

**A backtest is not evidence that a strategy works. It is evidence that a strategy would have worked
on the data you used to build it** — which is a much weaker claim, and often no claim at all.

The purpose of a backtest is to **reject** strategies. Treat a good result with suspicion and a bad
result as information. Most people do the opposite, which is why most backtests are optimistic.

## The three errors, in order of damage

### 1. Overfitting

You tried many things. One worked. You cannot tell whether it worked because it is real or because
you tried many things.

This is not a matter of degree — it is the default outcome of any search process, and it happens even
when you are careful, because **every decision is a hypothesis test**: the lookback, the threshold,
the universe, the timeframe, the entry filter, the exit rule, the markets you tried and abandoned.

The formal result: Sullivan, Timmermann & White (1999) showed that the apparent significance of
classic technical trading rules largely disappears once you account for the full universe of rules
being implicitly searched. Bailey and López de Prado formalised the same idea for backtests — with
enough trials, an impressive Sharpe ratio arises with certainty from noise alone.

**Defences:**
- **Count your trials. Honestly.** Including the ones you abandoned. This number is an input to every
  subsequent statistic.
- **Use the deflated Sharpe ratio**, which adjusts for the number of trials and for non-normal returns
  ([evaluating-performance.md](evaluating-performance.md)).
- **Raise your significance bar.** Harvey, Liu & Zhu (2016) argue for a t-statistic near 3.0 rather
  than 2.0 given the amount of testing in the literature. The same logic applies to you.
- **Prefer fewer parameters.** Each one multiplies the search space.
- **Demand a parameter plateau, not a peak.** Plot the performance surface across parameter values. A
  real effect is a broad region that works. A spike surrounded by failure is noise. **This single plot
  kills more bad strategies than any statistical test.**
- **Have the mechanism first.** A strategy derived from an economic story and then tested is a
  fundamentally different statistical object from one found by search.

### 2. Look-ahead

Using information you would not have had. Covered in detail in
[../data/data-quality.md](../data/data-quality.md#look-ahead-bias--the-one-that-gets-everyone).

The test: **at every decision point, could a program running live at that instant have computed this
from data it already had?** The most common leaks are bar-close timestamps used as decision times,
full-sample normalisation, and universes selected with hindsight.

### 3. Unrealistic execution

Covered in [../execution/order-placement.md](../execution/order-placement.md#modelling-execution-in-a-backtest).
Filling at the close, ignoring spread, constant slippage, assuming limit orders fill, and charging
maker fees on stops. Each one flatters. Together they can invert a result.

## Validation that actually tests something

**In-sample / out-of-sample split** is the minimum, and it is weak: once you look at the out-of-sample
result and adjust anything, it is in-sample.

**Walk-forward analysis** is the standard: fit on a window, test on the next period, roll forward.
Reports a series of genuinely out-of-sample results and shows whether parameters are stable over time.
Parameter instability across windows is itself a finding — it means there is nothing to fit.

**Purged, embargoed cross-validation** (López de Prado) is the correct approach for time series with
overlapping labels. Standard k-fold CV leaks badly on financial data because observations near a fold
boundary share information. **Purge** training observations whose labels overlap the test set;
**embargo** a gap after the test set to prevent serial-correlation leakage.

**Combinatorial purged CV** goes further, generating many train/test splits to produce a *distribution*
of performance rather than one number — which is what you actually want, since the single number is
noise.

## The tests that matter more than the equity curve

Run these before you look at returns:

1. **Parameter sensitivity.** Plot the surface. Demand a plateau.
2. **Different market.** Does it work on another perp? If it only works on one, you fit that one.
3. **Different period.** Especially a period with a different regime.
4. **Randomisation.** Shuffle the signal while keeping the trade timing and cost structure. Compare
   your result against that null distribution. If you cannot beat shuffled signals convincingly, you
   have a trade-frequency artifact.
5. **Cost sensitivity.** Double your cost assumptions. If the strategy dies, it was never viable —
   your cost estimate is not precise enough to bet on the difference.
6. **Trade-count check.** Fewer than a few hundred trades means almost no statistical power, whatever
   the Sharpe says.
7. **Remove the best month.** If the entire result comes from one period, you have one observation.

## Paper trading — the step that catches what backtests cannot

A backtest cannot catch: API behaviour, rate limits, partial fills, rejected orders, latency, feed
gaps, reconciliation drift, or your own bugs. **Paper trading catches all of them.**

**Lighter's official agent kit simulates against live order books** — use it. It is the most valuable
feature in that kit and the most ignored.

Run paper long enough to see a volatile period, then compare the paper results to your backtest over
the same window. **Divergence is a bug, not noise**, and finding it there costs nothing.

Then run live at minimum size. Live-small catches the last category — actual fills, actual slippage,
actual funding — and it costs a small, bounded amount to learn it.

## Why strategies fail live after a good backtest

In rough order of frequency:

1. **Overfitting** — there was never an edge.
2. **Costs** — the edge existed and was smaller than the costs.
3. **Execution** — you could not get the fills the backtest assumed.
4. **Look-ahead** — a subtle leak.
5. **Regime change** — the edge was real and the market changed.
6. **Capacity** — it worked at backtest size and not at your size.
7. **Operational failure** — the strategy was fine and the system was not.

Note that only #5 is bad luck. **The rest are all detectable before deployment**, and that is the
point of this card.

## The honest standard

Before deploying, you should be able to answer:

- What is the mechanism, and who is on the other side?
- How many things did I try before this one?
- Does it survive a doubling of costs?
- Does it work on a market and a period I did not use to build it?
- Is the parameter surface a plateau?
- What would make me turn it off?

If any answer is uncomfortable, the strategy is not ready — and no amount of additional backtesting
will fix it, because more backtesting on the same data is more overfitting.
