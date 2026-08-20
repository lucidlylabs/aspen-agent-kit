---
section: quant
group: strategies
title: Mean reversion
type: direction
triggers: >-
  mean reversion, z-score, RSI oversold, bollinger reversion, fade the move,
  overreaction, buy the dip strategy
---

# Mean reversion

## Mechanism

Prices overshoot. A liquidity-demanding participant who must trade now pushes price beyond fair value,
and it recovers when patient capital steps in. **You are being paid to provide liquidity to someone in
a hurry.**

That is the honest framing, and it has a real consequence: **you are on the other side of urgency, and
sometimes urgency is informed.** The person dumping might know something. Mean reversion is short a
free option on information, which is why its return distribution has a long left tail — many small
wins, occasional large losses.

**Grade: B, and heavily conditional.** The effect is real at short horizons and in ranging regimes. It
is also the strategy family most reliably destroyed by transaction costs.

## Read this before building one

Compute the fee drag first ([../../perpetuals/fees.md](../../perpetuals/fees.md)).

Mean reversion is high-turnover by construction and small-edge by construction — the edge is small
*because* the mispricing is small, which is why it exists at all. That combination is the worst
possible one for a fee-paying account:

> A strategy trading every 15-minute candle at 10× with 10% of equity pays ~8.6% of bankroll per day
> in fees on Hyperliquid at base tier. Its signal must beat that before it earns anything.

**Most retail mean-reversion strategies are arithmetically dead before their signal is evaluated.**
If you build one, it must be low-frequency, maker-only, or both.

## Construction

Use a z-score, not an oscillator ([../indicators/momentum.md](../indicators/momentum.md#the-z-score-the-oscillator-worth-using)):

```
z_t = (price_t − rolling_mean(price, n)) / rolling_std(price, n)
entry:  |z| > entry_threshold        (long if z < 0, short if z > 0)
exit:   |z| < exit_threshold, or a stop, or a time limit
```

Critical prerequisite: **the series must actually be mean-reverting.** A z-score of a trending
(non-stationary) series is meaningless — it will tell you to short every new high in a bull market.
Test for stationarity (ADF, KPSS, or a Hurst exponent below 0.5) on the specific series, over the
specific period, before trusting the construction.

This is why mean reversion works far better on **spreads** than on outright prices. A spread between
two linked instruments has an economic reason to revert; an outright price does not. See
[stat-arb-pairs.md](stat-arb-pairs.md).

## Regime conditioning is mandatory

Mean reversion and trend are the same market viewed in different regimes, and running the wrong one is
worse than running nothing.

- **Only enter when a trend filter says the market is not trending.** Low ADX, or price contained
  within a range, or a Hurst exponent below 0.5.
- **Stand down in volatility expansion.** Rising volatility is when overshoots keep overshooting.
- **Never fade a fresh breakout of a well-defined range.** That is the highest-probability
  continuation setup in the market and the worst possible mean-reversion entry.

## Exit and the stop problem

Mean reversion has an uncomfortable structural property: **the natural stop is where the thesis is
most wrong, which is also where the signal is strongest.** As price moves against you, z-score rises,
and the strategy wants to add.

Resolve it explicitly, in code, before deploying:

- **A hard stop at a level where the thesis is invalidated** (regime change, not just a bigger z).
- **A time stop.** If reversion has not occurred within the horizon it usually occurs in, exit. This is
  the most under-used and most effective exit in this family.
- **A cap on adds**, if you scale in at all, with the total position respecting your per-market limit.

Without a hard limit, "adding to a mean-reversion loser" is the mechanism by which accounts end.

## Sizing

Volatility-scaled, and **smaller than a trend position at the same nominal risk**, because the payoff
is negatively skewed. Fractional Kelly on a negatively skewed distribution should be more conservative
than the point estimate suggests ([../risk/position-sizing.md](../risk/position-sizing.md)).

## Failure modes

1. **Fees.** The first and most common cause of death. Compute before building.
2. **Trending regimes.** Fading a trend loses continuously with a high win rate right up until it does
   not — the equity curve looks great and then gives everything back.
3. **The informed counterparty.** Sometimes the dump is information. No filter removes this; sizing is
   the only defence.
4. **Adding to losers without a limit.** Ruin mechanism.
5. **Non-stationary series.** The z-score is measuring nothing.
6. **Parameter overfitting.** Entry and exit thresholds plus a lookback is already three parameters on
   a small-edge strategy — a large search space against a weak signal.

## Where it actually works on these venues

- **On spreads, not outrights** — cross-venue price differences on the same asset, where convergence
  has a mechanism.
- **After liquidation cascades**, where forced sellers are provably price-insensitive. The mechanism is
  visible and real. The difficulty is that execution happens during the worst liquidity of the day, so
  model slippage brutally.
- **Mid-range prediction markets** far from resolution, where genuine disagreement moves prices on
  noise ([prediction-markets.md](prediction-markets.md)).
- **As a maker**, resting bids below and offers above, which converts the fee term from a cost into a
  rebate and changes the arithmetic entirely — at which point you are market making
  ([market-making.md](market-making.md)).
