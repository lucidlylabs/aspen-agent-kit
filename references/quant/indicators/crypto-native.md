---
section: quant
group: indicators
title: Crypto-native indicators — funding, basis, open interest, liquidations
triggers: >-
  funding rate, basis, open interest, long short ratio, liquidations,
  annualized funding, carry, positioning, crowding, perp premium
---

# Crypto-native indicators

These do not exist in classical technical analysis because the instruments did not exist. **They are
the highest-signal data available on a perp venue**, and they are under-used relative to chart
indicators that carry far less information.

The reason they are strong: funding, basis and open interest are **direct observations of
positioning**, not inferences from price. You are not guessing whether longs are crowded. You are
reading how much they are paying to stay long.

## Funding rate

The periodic payment between longs and shorts that tethers the perp to spot. Positive: longs pay
shorts.

**Always convert to a common unit before comparing anything:**

```
annualised % = rate_per_period × periods_per_year
```

Hourly funding of 0.01% → `0.01% × 24 × 365` ≈ **87.6%/year**. Hourly rates look tiny and are not.
Cross-venue comparison without this normalisation is meaningless, and it is the most common error in
funding analysis.

**Grade: A.** Two distinct and both-valid uses:

### 1. Funding as carry (the cash flow)

A delta-neutral position — long spot, short perp, or long one venue and short another — collects
funding while being indifferent to price. This is the most robust strategy family for a small
account, because it is nearly fee-insensitive. See
[../strategies/funding-carry.md](../strategies/funding-carry.md).

What to check before believing a carry number:

- **Is the rate persistent or a spike?** Funding mean-reverts. A single rich print is not an
  annualised yield. Look at the distribution over weeks, not the current value.
- **What is the cost of the hedge**, including its own funding, borrow, and both legs' fees?
- **Lighter clamps and floors funding.** If the premium sits inside ±5bp the rate defaults to roughly
  1bp per 8 hours, and the big clamp caps it at 4% per 8 hours. Quiet markets pay almost nothing
  there. A screen calibrated on an unclamped venue will systematically overstate Lighter's carry.
- **Per-market-class multipliers** on Lighter (1 for crypto, ½ for RWAs, 1/100 for pre-IPO) mean a
  basis on a pre-IPO market faces almost no funding pressure and can persist indefinitely.

### 2. Funding as a crowding gauge (the signal)

This is the use most people miss. **A high positive funding rate is not an opinion — it is evidence
that longs are crowded enough to pay to stay long.** It is a directly observed measure of positioning
that equity markets would kill for.

- **Extreme funding marks crowded positioning**, and crowded positioning is fragile. Sustained
  extremes have historically preceded violent unwinds, because the marginal long is paying to hold
  and will capitulate.
- **Use it as a filter on directional trades.** Going long into extremely rich funding means paying
  carry to join a crowd. Going long into negative funding means being *paid* to take the unpopular
  side. The second is structurally better even with the same price signal.
- **Funding z-score** — `(funding − rolling_mean) / rolling_std` per market — makes extremes
  comparable across markets and regimes. This is the right construction; raw thresholds are not
  portable.
- **Funding divergence across venues** on the same asset is a convergence trade, not a forecast. It
  is the cleanest opportunity shape available on these venues.

## Basis

`basis = (perp price − spot/index price) / index price`, usually annualised.

Funding's mirror. Funding is the mechanism; basis is the state. They are tightly linked but not
identical — funding rules include clamps, interest-rate components and impact-price constructions
that make the realised payment differ from the raw premium.

- **Grade: A.** The basis on a dated future gives you a clean, forecast-free convergence trade: it
  must go to zero at expiry. See [../strategies/basis-and-cash-carry.md](../strategies/basis-and-cash-carry.md).
- On perps there is no expiry, so basis is enforced only by funding pressure. It can persist far
  longer than intuition suggests, especially where funding is clamped or damped.
- **Basis as a sentiment measure:** a persistently rich basis is leveraged long demand exceeding
  spot-holding supply.

## Open interest

Total notional of open contracts.

**Grade: B, and much stronger in combination with price than alone.** The standard four-way reading:

| Price | Open interest | Reading |
|---|---|---|
| ↑ | ↑ | New longs entering — trend supported by fresh capital |
| ↑ | ↓ | Shorts covering — a squeeze, not accumulation. Less durable. |
| ↓ | ↑ | New shorts entering — trend supported |
| ↓ | ↓ | Longs liquidating/closing — capitulation, often near exhaustion |

- **OI relative to market cap or to its own history** is a leverage-in-the-system gauge. High OI plus
  extreme funding is the classic fragile configuration.
- **OI rising while price stalls** means positioning is building without resolution — a coiled state
  that tends to resolve violently in whichever direction hurts the crowd.
- Available directly from Hyperliquid's asset contexts, which is one call for the whole universe and
  the cheapest useful poll on the venue.

## Liquidations

Forced closes. **Grade: B as a state variable, D as a trigger.**

- **Liquidations are reflexive**: a move triggers liquidations, which force market orders, which
  extend the move, which triggers more. This is why crypto volatility has the tail shape it does and
  why it clusters so violently.
- **Liquidation clusters** — the price levels where large amounts of leverage would be forced out —
  act as attractors. Price tends to move toward pools of forced liquidity because that is where
  liquidity actually is.
- **A liquidation cascade is usually a mean-reversion opportunity** — price overshoots because forced
  sellers are price-insensitive, then recovers. Trading it requires being able to act during the
  worst possible liquidity, so model slippage brutally.
- **Do not chase liquidation data as a signal generator.** By the time it is in a feed, the cascade
  has happened. Use it to understand regime and to avoid being positioned into a cluster.

**Practical:** the honest use of liquidation awareness is defensive. Know where your own liquidation
price sits relative to visible clusters, and do not put it inside one
([../../perpetuals/risk-controls.md](../../perpetuals/risk-controls.md)).

## Long/short ratios and positioning data

Venue-published ratios of accounts or positions long vs short.

**Grade: C.** Widely quoted, weakly informative. Account-weighted ratios are dominated by small
accounts; notional-weighted ones are more meaningful. Definitions vary by venue and are rarely
comparable. Funding is a better crowding measure, because it is a price rather than a survey.

## Putting it together: the positioning dashboard

For any perp you are considering, the four numbers worth having on one line:

1. **Annualised funding**, and its z-score over the last month.
2. **Basis** to index, annualised.
3. **Open interest**, and its change over 24h and 7d.
4. **Realised volatility**, and its ratio to its own longer-run average.

That combination tells you what the crowd is doing, what it costs to join or fade them, and how
violent the resolution is likely to be. It is more informative than any set of chart indicators, and
on Hyperliquid most of it comes from a single asset-contexts call.
