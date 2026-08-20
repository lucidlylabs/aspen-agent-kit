---
section: quant
group: strategies
title: Strategy archetypes
triggers: >-
  trading strategy, strategy ideas, what strategies work, funding arb, grid bot,
  mean reversion, market making, pairs trading, trend following
---

# Strategy archetypes

Each card here is a **specification**, not a recipe: the mechanism, the entry and exit conditions, the
sizing rule, the failure modes, and the decisions that must be deterministic code rather than model
judgment. Read the mechanism first. If you cannot state who is on the other side and why they keep
being there, the rest does not matter.

## The archetypes

| Strategy | Type | Edge source | Fee sensitivity | Card |
|---|---|---|---|---|
| Funding carry | Carry | Perp funding paid to the unpopular side | **Low** | [funding-carry.md](funding-carry.md) |
| Basis / cash-and-carry | Convergence | Perp or future trading away from spot | **Low** | [basis-and-cash-carry.md](basis-and-cash-carry.md) |
| Trend / momentum | Direction | Documented return continuation | Low–medium | [trend-momentum.md](trend-momentum.md) |
| Mean reversion | Direction | Overreaction and liquidity provision | **High** | [mean-reversion.md](mean-reversion.md) |
| Stat-arb / pairs | Convergence | Temporary divergence in a linked pair | Medium–high | [stat-arb-pairs.md](stat-arb-pairs.md) |
| Grid / range | Direction (short vol) | Being paid for providing liquidity in chop | **Very high** | [grid-and-range.md](grid-and-range.md) |
| Market making | Liquidity provision | Spread + rebates minus adverse selection | Fees are the *business* | [market-making.md](market-making.md) |
| Prediction markets | Mixed | Calibration error, convergence, cross-venue | Medium | [prediction-markets.md](prediction-markets.md) |

## Choosing one honestly

Match the strategy to your actual constraints, not to what sounds sophisticated.

**If you have a small account and pay retail fees**, carry and convergence strategies are the only
categories where the arithmetic is comfortably on your side. They hold for days or weeks, so the fee
term is negligible, and their edge does not depend on forecasting. Start there.

**If you have latency and infrastructure**, market making and microstructure strategies are available
to you and are not available to most people. That is a real, defensible edge.

**If you have neither**, trend at long horizons is the most robust remaining option, and you should
expect a low win rate, long flat periods, and returns that come from a small number of large moves.

**If you are drawn to high-frequency mean reversion or grid trading**, compute the fee drag first
([../../perpetuals/fees.md](../../perpetuals/fees.md)). Most such strategies are arithmetically dead
before their signal is evaluated, and this is the single most common way a plausible idea turns out
to be a guaranteed loser.

## What every strategy card assumes

1. **Costs are modelled before the signal is evaluated.** Fees, spread, slippage at real depth, and
   funding over the holding period.
2. **Sizing is volatility-scaled**, not fixed notional
   ([../risk/position-sizing.md](../risk/position-sizing.md)).
3. **The exit is defined at entry.** A strategy without a pre-committed exit is a position with a
   story.
4. **Risk limits are code** ([../risk/risk-management.md](../risk/risk-management.md)).
5. **The backtest is not trusted** until it survives [../validation/backtesting.md](../validation/backtesting.md).

## The decisions that must be code, never judgment

Across every archetype, these must be deterministic and covered by tests that assert the failure case:

- **Direction selection on a hedged pair.** A sign error in a delta-neutral trade converts a carry
  harvest into paying the carry at double exposure. This is the highest-frequency catastrophic bug in
  this whole space.
- **Leg sizing symmetry.** "Delta-neutral" that is 10% off is a directional position you did not
  intend and are not monitoring.
- **Sign conventions on funding.** Who pays whom, per venue, validated against a known historical
  period.
- **Position and leverage caps.**
- **Stale-data refusal.** No fresh mark, no order.

Never let a language model choose any of these at runtime.
