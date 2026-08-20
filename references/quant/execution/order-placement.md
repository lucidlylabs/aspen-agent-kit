---
section: quant
group: execution
title: Execution — getting filled at the price you modelled
triggers: >-
  market vs limit order, slippage, TWAP, VWAP execution, implementation shortfall,
  post only, order types, how to execute, iceberg, execution algo
---

# Execution — getting filled at the price you modelled

A backtest fills at the close. Reality fills you somewhere else. **Execution is the gap between the
strategy you tested and the strategy you ran**, and for anything short-horizon it is larger than the
signal.

## The cost decomposition

Almgren & Chriss (2000) framed the fundamental trade-off, and it is the right mental model:

```
total cost  =  market impact (worse if you trade fast)
            +  timing risk    (worse if you trade slow)
            +  explicit fees
            +  spread
```

**Trade fast and you move the price against yourself. Trade slow and the price may move away for
unrelated reasons.** There is an optimal speed, it depends on your urgency and on volatility, and
both extremes are wrong.

The single number that captures all of it is **implementation shortfall**: the difference between the
price when you decided and the price you actually achieved, including the cost of any part of the
order you failed to execute. This is the honest measure. Track it.

## Order types, and what each actually costs

| Type | Fills | Costs you |
|---|---|---|
| **Market / IOC** | Certainly, now | Full spread + impact + taker fee. Certainty is expensive. |
| **Limit (GTC)** | Maybe, eventually | Nothing extra if filled — but you are adversely selected, and unfilled orders are opportunity cost. |
| **Post-only / ALO** | Only as maker | Rejects rather than crossing. **The correct default for any passive strategy.** |
| **FOK / FAK** | All-or-nothing / partial | Avoids partial-fill leg risk on multi-leg trades. |
| **Trigger / stop** | On mark price touch | **Executes as a market order by default** — full taker cost, and worst slippage precisely in fast markets. |
| **TWAP (native)** | Sliced over time | Reduces impact, accepts timing risk. Available natively on both perp venues. |

**The trigger-order point deserves emphasis.** Every strategy with a protective stop pays taker on the
exit, in the worst conditions. A backtest that assumes the stop fills at the stop price with maker
fees is wrong twice over. Model stops as market orders with elevated slippage.

## The maker/taker decision

This is the highest-leverage execution choice you make.

**Take when:** the signal decays fast (microstructure, momentum entries), you must hedge a leg now, you
are stopping out, or the cost of not filling exceeds the spread.

**Make when:** the signal is slow (carry, basis, trend at long horizons), you are providing liquidity
deliberately, or the fee differential is large relative to your edge.

The arithmetic on Hyperliquid: taker 0.045% vs maker 0.015% at base tier. **Resting instead of
crossing saves 3bp per fill, 6bp per round trip.** For a strategy with a 20bp edge that is nearly a
third of the edge — decisive. For a carry trade held six weeks it is noise.

**The catch nobody prices in:** maker fills are adversely selected. You fill when the market comes to
you, which is disproportionately when it keeps going. The saved fee is partly an illusion. Measure
effective-minus-realised spread on your own fills to find out how much
([../indicators/microstructure.md](../indicators/microstructure.md#spread)).

## Sizing an order to the book

Before sending anything, walk the book:

```
for each level from best:
    take min(remaining, level_size) at level_price
    average_fill = weighted mean of prices taken
slippage = |average_fill − mid| / mid
```

Rules that hold up:

- **Never send an order that consumes more than a small fraction of visible depth.** Beyond a few
  percent of typical volume, your impact dominates your edge.
- **Displayed depth overstates real depth.** Cancellations, icebergs and spoofing mean the far levels
  are partly fictional. Discount them.
- **Slice large orders.** Either a native TWAP or your own scheduler. Both perp venues have native
  TWAP (Hyperliquid slices at 30-second intervals with a per-suborder slippage cap; Lighter has a
  TWAP order type).
- **Randomise slice timing and size** if you slice on a fixed schedule and care about being detected.

## Execution algorithms, briefly

- **TWAP** — equal size per time interval. Simple, predictable, and predictable is a weakness if
  someone is watching.
- **VWAP** — track the volume profile, trading more when the market is more active. Better when
  volume has a stable shape; in 24/7 crypto the hour-of-day profile is real and usable.
- **POV (percentage of volume)** — trade a fixed share of realised volume. Adapts automatically to
  liquidity; unbounded in time, which is its risk.
- **Implementation shortfall / adaptive** — front-load when urgency is high, ease off when not. What
  Almgren-Chriss actually solves for.

For most retail-sized strategies, **the right answer is usually "your order is small enough that this
does not matter — just do not cross a thin book with a market order."** Know which regime you are in
before building an execution stack you do not need.

## Venue-specific execution notes

**Hyperliquid.** Size rounds to `szDecimals`, price to the tick and to a limited number of significant
figures — un-rounded orders are rejected. `market_open` helpers default to a **5% slippage
tolerance**, which is far too wide for a thin market; set it explicitly. Rate limits are weighted;
reserve headroom for cancels.

**Lighter.** Prices and sizes are **integers scaled by per-market decimals** — the highest-severity
gotcha on the venue, since a wrong exponent trades the wrong size without erroring. A taker order's
price is the *worst acceptable price*. A fat-finger guard rejects orders far from the book. Standard
accounts have ~300ms taker latency, so anything latency-sensitive should be on Premium
([../../perpetuals/fees.md](../../perpetuals/fees.md)). Nonces are per-key and a rejected taker still
consumes one.

**Polymarket.** Tick size is per-market and can change mid-life. Minimum size is in **shares**, so the
dollar minimum scales with price. Open orders reserve the whole per-market balance. Some markets have
a **matching delay during which orders cannot be cancelled** — know which. Market buys take a dollar
amount; market sells take a share amount.

**All three: HTTP 200 means accepted, not executed.** Confirm fills on the account stream. A system
that treats acknowledgement as execution will eventually double a position.

## Modelling execution in a backtest

The most common way a backtest lies. Minimum standards:

1. **Never fill at the close of the signal bar.** Fill at the next bar's open at the earliest.
2. **Charge the spread.** Half-spread for a mid-referenced fill, full for a market order.
3. **Charge slippage from a real book**, not a constant. Build a slippage curve from recorded snapshots
   ([../../perpetuals/hyperliquid-data.md](../../perpetuals/hyperliquid-data.md)).
4. **Charge taker fees on stops.**
5. **Model unfilled limit orders.** If your strategy rests orders, a large share will not fill, and
   assuming they all do is the single most flattering error in maker-strategy backtests.
6. **Compare backtest fills to live fills** once running. Persistent divergence means your model is
   wrong, and it is nearly always optimistic.
