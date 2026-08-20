---
section: quant
group: risk
title: Position sizing
triggers: >-
  how much should I bet, kelly criterion, position size, volatility targeting,
  risk per trade, leverage, bet sizing, fractional kelly
---

# Position sizing

**Sizing decides survival; signal decides return.** A mediocre signal sized well outperforms an
excellent signal sized badly, because the badly sized version does not survive to collect its edge.
This is the most under-studied part of trading relative to its importance.

## The core asymmetry

Losses and gains are not symmetric in their effect on capital. A 50% loss requires a 100% gain to
recover. A 90% loss requires 900%. **Compounding is destroyed by drawdowns far more than it is helped
by equivalent gains**, which is why the objective is not to maximise expected return but to maximise
the expected *growth rate* of capital.

## The Kelly criterion

Kelly (1956) gives the fraction of capital that maximises long-run growth.

**For a binary bet** (directly applicable to prediction markets):
```
f* = (p × b − q) / b        p = win probability, q = 1 − p, b = net odds received
```
Equivalently, for a contract at `price` with your probability `p`, `b = (1 − price)/price`.

**For continuous returns** (approximately, for perps):
```
f* ≈ μ / σ²                 μ = expected return, σ² = variance
```

Properties worth internalising:

- **Betting more than Kelly reduces growth *and* increases risk.** It is dominated in both dimensions —
  there is never a reason to do it. Beyond 2× Kelly, expected growth is negative even with a positive
  edge.
- **Kelly is extremely sensitive to your estimate of edge.** If you overestimate μ by 2×, Kelly
  overstates the optimal bet by 2×, and you are levered past the point of positive growth without
  knowing it.
- **Full Kelly drawdowns are brutal** — 50% drawdowns are routine at full Kelly even when everything
  is estimated correctly.

**Therefore: use fractional Kelly.** A quarter to a half is standard practice. Half-Kelly retains
roughly 75% of the growth rate with substantially less than half the drawdown. Given that your edge
estimate is uncertain, fractional Kelly is not conservatism — **it is the correct response to
estimation error.**

Where Kelly applies most directly here: **binary prediction-market bets**, where you have an explicit
probability and explicit odds. Use it, and use a fraction of it.

## Volatility targeting — the workhorse

For continuous instruments this is more practical than Kelly and does most of the work.

```
position_notional = (target_volatility / forecast_volatility) × capital
```

Scale positions so each contributes roughly equal risk, and so total portfolio volatility stays near
a target. The result: **you are automatically smaller when the market is dangerous and larger when it
is calm.**

This works because volatility is genuinely forecastable while returns are not
([../indicators/volatility.md](../indicators/volatility.md)). Applying volatility targeting to an
existing strategy typically improves its risk-adjusted return with no change to the signal — it is
the highest return-on-effort change available to most systems.

Practical form, per trade:
```
size = (equity × risk_fraction) / (N × ATR)
```
Risk a fixed fraction of equity (commonly 0.25%–1%) on an N-ATR adverse move. This is the Turtle
construction and it is hard to improve on for its simplicity.

## Sizing a perp: from risk to leverage

Do it in this order. Leverage is an *output*, never an input.

1. **Decide risk per trade** as a fraction of equity (e.g. 0.5%).
2. **Decide the invalidation distance** — where the thesis is wrong — in ATR units.
3. **Size = risk_capital / stop_distance.**
4. **Derive the implied leverage.** If it exceeds your cap or puts the liquidation price inside a
   plausible move, the trade is too large. Reduce size; do not widen the stop.
5. **Check the liquidation distance in volatility units.** At 10× with a 2.5% maintenance rate you have
   ~7.5% of room; if daily volatility is 5%, a 1.5-sigma day ends you
   ([../../perpetuals/risk-controls.md](../../perpetuals/risk-controls.md)).

**Never start from "I'll use 10× leverage."** That is choosing an output and hoping the inputs comply.

## Adjusting for the shape of the distribution

Kelly assumes you know the distribution. You do not, and the shape matters:

- **Negative skew** (mean reversion, selling longshots, grid trading, short volatility): many small
  wins, rare large losses. The historical Sharpe overstates the quality badly because the tail has not
  happened yet in your sample. **Size well below what the statistics suggest.**
- **Positive skew** (trend following, buying longshots): many small losses, rare large wins. The
  historical Sharpe understates it, and the strategy can tolerate more size — but expect long flat
  periods and do not cut the winners.
- **Fat tails.** Crypto returns have far fatter tails than a normal distribution. Any sizing derived
  from a Gaussian assumption understates tail risk. Use empirical quantiles from your own data, and
  include a regime that contained a crash.

## Portfolio-level sizing

Individual position sizing is not enough once you run more than one thing.

- **Correlation destroys diversification exactly when you need it.** Crypto assets converge toward
  correlation 1 in stress. A portfolio of ten perp positions in a drawdown is roughly one position.
  Size on **stressed** correlation, not on sample correlation.
- **Risk parity** — allocate so each position contributes equal risk (inverse-volatility weighting as
  the simple version) — is a reasonable default and better than equal notional.
- **Cap aggregate exposure** independently of what per-position sizing suggests. The sum of individually
  reasonable positions is frequently unreasonable.
- **Aggregate by underlying risk factor**, not by instrument. Ten prediction markets on one election,
  or five perps that are all beta to BTC, are each one position.

## Common sizing errors

1. **Fixed notional per trade.** Ignores volatility entirely; you take wildly different risk on
   different days without noticing.
2. **Leverage as an input.** Covered above.
3. **Sizing up after wins.** Sizing should scale with equity, not with confidence.
4. **Adding to losers without a cap.** The standard ruin mechanism, especially in mean reversion.
5. **Ignoring correlation.** The most common institutional-quality mistake made by individuals.
6. **Full Kelly on an estimated edge.** Kelly with an overestimated μ is a leveraged path to zero.
7. **Sizing on a sample with no crisis in it.** Your tail estimate is then not an estimate.

## The floor rule

Whatever the mathematics says, apply a hard constraint: **no single position may cause an
unrecoverable loss.** Define unrecoverable explicitly (say, 20% of capital) and enforce it in code
above every other sizing rule. Sizing models fail; the floor is what makes their failure survivable.
