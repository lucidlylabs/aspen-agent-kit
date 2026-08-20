---
section: quant
group: strategies
title: Grid and range trading
type: short-volatility
triggers: >-
  grid bot, grid trading, range trading, ladder, buy the dip sell the rip,
  range bound bot, DCA grid
---

# Grid and range trading

## Mechanism

Quantise a price range into N levels. Rest a buy at each level and a sell one step above. Every
completed buy→sell round trip inside the range banks one grid step of profit.

**Be clear about what this is: you are selling volatility.** You earn when price oscillates and you
accumulate inventory on the losing side when it trends. It is a short-volatility position with the
payoff profile that implies — frequent small gains, occasional large losses — dressed up as a
"strategy" because the small gains are visible and continuous.

**Who is on the other side?** Anyone who needs immediacy. You are a rudimentary market maker with a
fixed, non-adaptive quoting scheme.

## Construction

```
grid = { market, lower, upper, levels, budget, spacing: arithmetic|geometric, venue }
```

- **The range must bracket the current price.** If it does not, the grid is a directional bet on
  entering the range.
- **Spacing:** arithmetic (equal price increments) or geometric (equal percentage increments).
  Geometric is more appropriate for assets that move in percentage terms, which is most of them.
- **Budget is the total across all rungs** and is the hard spend ceiling — it is what you actually
  fund and risk.
- **Per-rung size** must clear the venue minimum. A budget split across too many levels leaves each
  rung below minimum, and the grid silently does nothing. Check this at construction time.
- **The grid step must exceed round-trip costs.** This is the entire viability test:

```
grid step (as % of price)  >  2 × fee_rate + spread crossed
```

## The fee arithmetic is brutal

Grid trading is the **most fee-sensitive strategy in this kit.** Every rung is a round trip, and the
profit per round trip is one grid step — deliberately small.

At Hyperliquid base taker (0.045%), a round trip costs ~0.09%. A grid step of 0.1% nets 0.01% per
completed cycle — a 90% cost ratio. **A grid with steps below roughly 0.3% at retail taker fees is
transferring your capital to the venue.**

Two things fix this, and you need at least one:

1. **Rest as maker (post-only).** Grid rungs are naturally passive orders. On Hyperliquid maker is 3×
   cheaper; on Lighter Standard it is free. **A grid should essentially never be paying taker fees** —
   if your implementation crosses the spread to place rungs, it is broken.
2. **Wider steps.** Fewer, larger round trips. This reduces fill frequency and shifts the strategy
   toward range trading.

Lighter's zero-fee Standard tier is genuinely well-suited to this, with the caveat that the latency
penalty makes your resting orders more adversely selected
([../../perpetuals/fees.md](../../perpetuals/fees.md#zero-fees-are-not-free)).

## Risk controls that are not optional

**A grid without a range-invalidation exit is not a strategy, it is a countdown.** When price leaves
the range, you hold maximum inventory on the wrong side and it keeps going.

- **A hard stop beyond the range edge**, at least one full rung-step outside, that flattens everything.
  This is the single most important component and the one most often omitted.
- **A maximum inventory cap**, independent of the grid geometry.
- **Leverage of 1× unless you have a specific reason.** A levered grid converts the "occasional large
  loss" into liquidation.
- **A time limit.** Ranges are regime-dependent; a grid running for months has outlived its thesis.

## Where a grid is appropriate

- **Explicitly range-bound regimes**: low ADX, contained volatility, no trend
  ([../indicators/volatility.md](../indicators/volatility.md#volatility-as-a-regime-switch)).
- **Assets with genuine oscillation** rather than drift.
- **As a maker, on a venue where you pay little or nothing per fill.**

## Where it is not

- **Trending markets.** Obviously, and this is where the losses come from.
- **After a volatility contraction.** Volatility clustering means contraction precedes expansion —
  precisely the moment a grid is most likely to be about to break.
- **On thin markets**, where your own rungs are a large fraction of the book.
- **At leverage.**

## Failure modes

1. **Range break.** The dominant risk. You hold maximum wrong-side inventory exactly when the move
   is largest. This is not a tail event — it is the expected eventual outcome of every grid.
2. **Fee drag.** Covered above; kills more grids than range breaks do, quietly.
3. **Per-rung minimum violations.** Silent no-trade.
4. **Adverse selection.** Your rungs fill when someone wants to trade through you. As a passive
   quoter you are structurally picked off ([../indicators/microstructure.md](../indicators/microstructure.md)).
5. **Presenting it as low-risk** because the equity curve is smooth until it is not. It is short
   volatility; say so.

## The honest comparison

A grid is a naive market-making strategy with fixed quotes and no inventory management. If the
economics appeal to you, read [market-making.md](market-making.md) — adaptive quoting with inventory
skew is strictly better at the same level of effort, and it is the same trade done properly.
