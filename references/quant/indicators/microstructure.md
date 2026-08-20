---
section: quant
group: indicators
title: Microstructure indicators
triggers: >-
  order book imbalance, spread, depth, kyle lambda, price impact, adverse
  selection, queue position, order flow imbalance, slippage estimate, micro price
---

# Microstructure indicators

These are computed from the order book and the trade stream rather than from bars. They answer
different questions from chart indicators — mostly about **cost and immediate pressure** rather than
about direction over days.

You need book data to compute them, which means recording it
([../data/data-sources.md](../data/data-sources.md)). It is worth it: this family is where the honest
cost model comes from, and a cost model is worth more than an entry signal.

## The theoretical backdrop, briefly

Two results explain almost everything in this family:

- **Glosten & Milgrom (1985):** the bid-ask spread exists because market makers face traders who may
  know more than they do. The spread is compensation for **adverse selection**, not just for
  inventory and processing. This is why spreads widen in uncertainty and why your fills skew against
  you.
- **Kyle (1985):** an informed trader's order flow moves price approximately linearly in size, with a
  coefficient λ that measures market depth. Price impact is not a friction bolted onto trading — it is
  the mechanism by which information enters price.

Together: **you cannot trade without paying for the information your trade reveals.** Every cost
estimate below is a way of measuring that.

## Spread

- **Quoted spread** = `ask − bid`. What you see.
- **Effective spread** = `2 × |execution price − mid at order arrival|`. What you actually paid,
  including the part of the book you ate through. Always larger than quoted for anything but the
  smallest orders.
- **Realised spread** = `2 × |execution price − mid at t + Δ|`, typically with Δ of a few minutes.
  What the *market maker* kept after the price moved. Effective minus realised is the adverse
  selection component — the part of your cost that is you being picked off.

**Measure your own effective spread.** It is the single most valuable number for validating a
backtest, and it is the empirical input to the latency-cost question on Lighter's zero-fee tier
([../../perpetuals/fees.md](../../perpetuals/fees.md#zero-fees-are-not-free)).

Normalise as `spread / mid` in basis points to compare across markets.

## Order book imbalance

```
OBI = (bid_size − ask_size) / (bid_size + ask_size)     at the top of book, or over N levels
```

- **Grade: B at very short horizons; D at any horizon a discretionary trader cares about.**
- Top-of-book imbalance genuinely predicts the next price move over seconds. This is one of the most
  reliably documented short-horizon predictive relationships in all of trading.
- It **decays extremely fast**. By the time you have observed it, decided, and sent an order, most of
  the edge is gone unless you are latency-competitive. On Lighter's Standard tier, with a 300ms taker
  delay, you are structurally unable to trade it.
- **Displayed size is not real size.** Spoofing, iceberg orders and rapid cancellation all mean the
  book overstates available liquidity. Weight by distance from mid and expect the far levels to be
  substantially fictional.

**The micro-price** is the practical application:

```
micro_price = (bid × ask_size + ask × bid_size) / (bid_size + ask_size)
```

Weighted toward the side with less size — i.e. toward where price is more likely to go next. A better
short-horizon fair value than the mid, and a better mark for computing PnL on a position you are
about to close.

## Order Flow Imbalance (Cont, Kukanov & Stoikov, 2014)

A refinement of book imbalance that tracks **changes** at the best quotes — additions, cancellations
and trades — rather than levels. Their result is that price changes are approximately linear in OFI,
with a stronger and more stable relationship than volume-based measures.

**Grade: B.** The correct measure if you are building anything at short horizons, and a better
research target than raw imbalance.

## Price impact and Kyle's lambda

Estimate λ by regressing price change on signed order flow over short intervals:

```
Δprice = λ × signed_volume + ε
```

λ is your **market impact coefficient**: expected adverse price movement per unit of size. It gives
you the cost of trading at size directly, which is what determines strategy capacity.

The widely observed empirical refinement is that impact is **concave, not linear** at larger sizes —
approximately a **square-root law**:

```
impact ≈ Y × σ × sqrt(Q / V)
```

where σ is volatility, Q is order size, V is typical volume over the execution horizon, and Y is a
constant of order 1. This form appears remarkably consistently across markets and asset classes.

**Why you should care even if you trade small:** it tells you the size at which your strategy stops
working. A strategy with a 10bp edge dies at the size where impact reaches 10bp. That size is your
capacity, and knowing it is the difference between a strategy and a business.

### Capacity, measured rather than assumed

The square-root law is not just theory you can cite — it shows up in reconstructions of live books.
One such reconstruction found realised alpha dollars scaling as approximately **AUM^0.52**
(R² ≈ 0.45): doubling capital produced about **1.44×** the alpha dollars, so return on capital
decayed as **AUM^−0.48**.

The practical reading: a strategy earning several percent per period at small size can be under one
percent at 50× the size, with the difference going to impact. **The edge is real and does not
scale.** Measure your own curve — regress realised alpha dollars against deployed capital over time —
rather than assuming capacity is far away.

## Markout: the rigorous way to measure maker edge

Effective-minus-realised spread is the concept; **markout** is how practitioners actually compute it.

1. Identify your passive fills (on venues that do not flag aggressor side, infer them from
   best-level size depletion).
2. For each fill, compute the **signed mid move at a series of horizons** after it — 0s, 1s, 10s,
   60s, 300s.
3. Plot the curve. A profitable maker's markout flattens or turns favourable; an adversely selected
   one keeps sloping against the fill.

The horizon curve is the point: it shows you *how fast* adverse selection erodes your capture, which
tells you how quickly you need to flatten. On liquid perps that erosion happens **within seconds**,
which is why passive strategies there need fast flattening rather than patient inventory.

## Depth and the cost of liquidity

- **Depth at N basis points** — cumulative size within N bp of mid. The direct answer to "can I trade
  my size", and far more useful than total book size.
- **Slippage curve** — walk the book and compute the average fill price for hypothetical order sizes.
  Do this for your actual intended size, on real snapshots, across different times of day. **This
  should be an input to every backtest**, replacing the fantasy of filling at mid or at close.
- **Book resilience** — how fast depth replenishes after a large trade. Determines whether you can
  execute in slices or must accept full impact at once.

## Queue position (for makers)

If you rest orders, your position in the price-time priority queue determines your fill probability
and your adverse selection. The uncomfortable arithmetic of passive execution:

- You fill when the market comes to you, which is disproportionately when it is about to keep going
  through you. **Passive fills are adversely selected by construction.**
- Being early in the queue means filling more often, including more often on the bad fills.
- The maker's edge has to come from the spread and rebates exceeding that adverse selection — which
  is exactly the Glosten-Milgrom trade-off, and the whole subject of
  [../strategies/market-making.md](../strategies/market-making.md).

## Practical notes for these venues

- **Hyperliquid** publishes L2 book snapshots in its S3 archive — the only free historical book data
  in this kit. Use it to build slippage curves and estimate λ before committing to a strategy's size.
- **Lighter's latency tiers are a microstructure variable you control.** Your account type literally
  changes your adverse selection. Measure effective spread per tier before choosing one.
- **Polymarket books are thin and the tick grid is coarse.** Microstructure measures are noisy there,
  and the dominant costs are spread and the fee curve, not impact. Depth-at-price matters far more
  than any imbalance signal.
