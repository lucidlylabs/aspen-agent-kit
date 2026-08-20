---
section: perpetuals
title: Perp fees and the all-in cost of a trade
kind: economics
docs: >-
  https://hyperliquid.gitbook.io/hyperliquid-docs/trading/fees ;
  https://docs.lighter.xyz/trading/trading-fees ;
  https://docs.polymarket.com/perps/learn-about-trading/fees
triggers: >-
  trading fees, fee tiers, maker taker, rebates, cost of trading, fee drag,
  is this strategy worth it, turnover, which venue is cheaper
---

# Perp fees and the all-in cost of a trade

Fee schedules are the most-quoted and least-understood number in trading. The schedule is not the
cost. This card gives you all three schedules, then the model that turns them into the only number
that matters: **how much edge a strategy must have per trade to break even.**

> Schedules change. Verify against the venue docs — and on Hyperliquid, read your *actual* rate from
> the user-fees info endpoint rather than assuming base tier. The tables below were read from the
> official docs and are a starting point, not a source of truth.

## The three schedules

### Hyperliquid

Tiered on rolling 14-day volume, assessed daily at UTC close. One tier applies across perps, HIP-3
perps and spot. Weighted volume counts **spot double**: `14d weighted = perps + 2 × spot`.

| 14d weighted volume | Taker | Maker |
|---|---|---|
| base | 0.045% | 0.015% |
| > $5M | 0.040% | 0.012% |
| > $25M | 0.035% | 0.008% |
| > $100M | 0.030% | 0.004% |
| > $500M | 0.028% | 0.000% |
| > $2B | 0.026% | 0.000% |
| > $7B | 0.024% | 0.000% |

Stacked on top: **HYPE staking discounts** (5% at >10 staked, rising to 40% at >500,000) and referral
discounts on early volume. Separately, high-share makers earn **rebates** (down to −0.003% at >3% of
14d weighted maker volume). Spot is a different and more expensive schedule (base 0.070% / 0.040%).
HIP-3 builder markets multiply the fee by the deployer's configured share, except in "growth mode"
where all-in taker can fall to roughly 0.0045%–0.009%.

### Lighter

Three account types. This is the important one to understand structurally.

| Account | Maker | Taker | Taker latency | Maker / cancel latency |
|---|---|---|---|---|
| **Standard** (default) | 0% | 0% | ~300 ms | ~200 ms |
| **Premium** (opt-in) | 0.0040% | 0.0280% | ~200 ms | none added |
| **Plus** (opt-in) | 0.005% | 0.005% | ~300 ms | ~200 ms |

Premium fees fall with staked LIT — 2.5% off at 1,000 staked, up to 30% off at 500,000
(0.0028% / 0.0196%, ~140ms). Staking tiers aggregate across an L1 address and its sub-accounts. Plus
buys much higher rate limits (order of 8,000 `sendTx`/min) at the flat rate.

### Polymarket Perps

`Fee = |Price × Quantity| × Rate`, in pUSD. Tiered on trailing 30-day volume, re-evaluated daily UTC.

| 30d volume ≥ | Taker | Maker |
|---|---|---|
| $0 | 0.0400% | 0.0125% |
| $1M | 0.0370% | 0.0100% |
| $5M | 0.0350% | 0.0080% |
| $25M | 0.0300% | 0.0050% |
| $100M | 0.0270% | 0.0020% |
| $500M | 0.0250% | 0.0000% |
| $1B | 0.0200% | −0.0050% (rebate) |

(Prediction-market fees on Polymarket work completely differently — see
[../prediction-markets/fees.md](../prediction-markets/fees.md).)

## Zero fees are not free

Lighter's Standard account charges nothing and delays your taker by ~300ms while makers quote and
cancel at ~200ms. **You are not getting free execution. You are paying in adverse selection.**

Think about what a 100ms asymmetry is worth to the counterparty. A resting maker can observe a price
move and pull the quote before your marketable order arrives. The fills you *do* get are
disproportionately the ones the maker no longer wanted — they filled you because the move went
against you, and cancelled when it went your way. That is a real, negative expected value on every
taker fill, and it is charged in slippage, which no fee schedule reports and no fee-based backtest
models.

The right comparison is therefore never "0% vs 0.045%". It is:

```
all-in cost per fill  =  explicit fee
                      +  half-spread paid (taker) or earned (maker)
                      +  market impact at your size
                      +  adverse selection from latency disadvantage
```

The last term is empirical. **Measure it**: log top-of-book at send and at fill, and compute the
average signed difference across a few hundred fills. If your average taker fill arrives 1.5bp worse
than the mid you saw at send, your true Standard-account taker cost is 1.5bp, not zero — and
Hyperliquid at 4.5bp with no delay may or may not beat it depending on your order type and horizon.

Two practical corollaries:

- **The zero-fee tier is strongest for makers and for patient, low-urgency flow**, where latency
  disadvantage costs little and the fee saving is real.
- **It is weakest for latency-sensitive taking** — stop-loss triggers, momentum entries, liquidation
  avoidance, anything cross-venue. Precisely the strategies that look best on paper under a "fees =
  0" assumption.

## Fee drag: the arithmetic that kills most strategies

Fees are charged on **notional**, not on margin. Leverage multiplies them.

```
daily fee drag (% of equity)
    ≈ trades_per_day × 2 fills × (position size as % of equity) × leverage × taker_rate
```

Candles per day, for a strategy that acts on every close:

| interval | 1m | 5m | 15m | 1h | 4h | 1d |
|---|---|---|---|---|---|---|
| candles/day | 1440 | 288 | 96 | 24 | 6 | 1 |

**Worked example.** "Flip long/short on every 15-minute candle, 10× leverage, 10% of account per
trade," on Hyperliquid at base tier:

```
96 × 2 × 0.10 × 10 × 0.00045  ≈  8.6% of bankroll per day, in fees alone
```

Charged whether the signal wins or loses. To break even the strategy needs an edge above
**8.6% per day**. A red/green candle heuristic does not have that. The same strategy on a 1-minute
interval costs ~130%/day: ruin is arithmetic, not bad luck.

**Funding is separate and additive.** A directional position pays or earns funding hourly. A few
basis points per hour at 10× is another ~1%/day. Quote it alongside fees whenever the user intends
to *hold* rather than flip.

## The break-even edge, and what to do about it

Turn the cost into the number that governs strategy design:

```
required edge per round trip  >  2 × fee_rate + spread_crossed + slippage + funding_over_holding_period
```

At Hyperliquid base taker, that floor is ~9bp before spread. A strategy whose average winning trade
captures 15bp is not a 15bp strategy; it is a 6bp strategy, and one bad week of slippage makes it
negative.

The levers that actually move the number, in order of effect:

1. **Trade less.** Linear in turnover, and the only lever with no downside other than fewer
   opportunities. Doubling your holding period halves your fee drag.
2. **Use maker orders.** Roughly 3× cheaper per fill on Hyperliquid, free-to-negative at scale, and
   on Lighter Premium the maker rate is 7× below taker. The cost is fill uncertainty — a resting
   order that does not fill is a missed trade, and adverse selection means the ones that *do* fill
   skew against you. Model both.
3. **Lower leverage.** Linear. Halving leverage halves fee drag for the same bankroll.
4. **Size smaller per trade.** Linear, and also reduces impact, which is superlinear in size.
5. **Climb the tier / stake.** Real but slow, and never the reason a losing strategy becomes a
   winning one.

## How fees deform strategy choice

This is the part most people skip. Fee structure does not just subtract from returns — it changes
which strategies are viable at all.

- **High-turnover mean reversion dies first.** Its edge per trade is small by construction (that is
  why the signal exists) and its trade count is high. It is the strategy most sensitive to the fee
  term and the first to flip negative as you move down in timeframe.
- **Carry strategies are nearly fee-insensitive.** A funding trade held for weeks pays two fills
  total. Its economics are dominated by the funding path and the cost of the hedge, not by the fee
  schedule. This asymmetry is why carry is the most robust category for a small, fee-paying account
  — see [../quant/strategies/funding-carry.md](../quant/strategies/funding-carry.md).
- **Market making is a fee *business*, not a fee cost.** At rebate tiers the sign flips: you are paid
  per fill and your risk is inventory, not fees. That is a different discipline entirely
  ([../quant/strategies/market-making.md](../quant/strategies/market-making.md)).
- **Stops are takers.** Any strategy with a protective stop pays taker on the exit — and pays it
  disproportionately in fast markets, where slippage is also worst. A backtest that models exits at
  the stop price with maker fees is wrong twice.
- **Leverage is a fee decision as much as a risk decision.** Because fees scale with notional,
  raising leverage raises the required edge proportionally while also shortening the distance to
  liquidation. It worsens both sides of the ledger at once.

## Cross-venue quick comparison

Base tier, taker, round trip, ignoring spread:

| Venue | Round trip | Note |
|---|---|---|
| Lighter Plus | 0.010% | flat, plus high rate limits |
| Lighter Premium | 0.056% | at 0 LIT staked; 0.039% at max stake |
| Lighter Standard | 0% explicit | **plus latency-driven adverse selection — measure it** |
| Polymarket Perps | 0.080% | |
| Hyperliquid perps | 0.090% | before staking / referral discounts |
| Hyperliquid spot | 0.140% | but spot volume counts double toward tier |

Do not choose a venue from this table alone. Liquidity, depth at your size, market availability,
funding levels and custody model all move the answer more than a few basis points do.
