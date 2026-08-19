---
module: hyperliquid-perps
instrument: Hyperliquid perpetual futures
venue: hyperliquid
triggers: perp opportunities — funding rates, carry, basis, leverage, longs and shorts on
  BTC/ETH/SOL/HYPE, "what perp should I trade", "where is funding high", "delta neutral",
  "cross-DEX funding", HIP-3 builder markets (stocks, indices, commodities, FX, pre-IPO)
---

# Hyperliquid perpetual futures

## What it is, from first principles

A **perpetual future** is a contract tracking an asset's price with **no expiry date**. That combination is
unstable on its own: a future with no settlement date has nothing forcing it back to spot. So perps add a
tether — the **funding rate**, a payment made directly between traders every hour.

When the perp trades **above** spot, longs pay shorts. When it trades **below**, shorts pay longs. The payment
scales with the gap. This makes holding the expensive side costly and the cheap side profitable, which pushes
the perp back toward spot without anyone ever settling anything.

Two consequences follow, and nearly every perp opportunity is one of them:

1. **Funding is a real cash flow**, paid hourly, independent of whether the price moves. It can be harvested.
2. **Funding is a crowding gauge.** A high positive rate is not an opinion — it is direct evidence that longs
   are crowded enough to pay to stay long.

## How it works on Hyperliquid

- **On-book, off-chain.** Orders go to HyperCore via signed API actions, not an EVM contract. Every market is
  a central limit order book with real depth — read the book, don't assume it.
- **Margin.** Cross (shared collateral across positions, most capital-efficient) or isolated (collateral
  fenced to one position, so a liquidation there can't touch the rest). Leverage is an integer up to a
  per-asset maximum.
- **Liquidation.** Triggered when account value including unrealized PnL falls below maintenance margin —
  roughly half the initial margin at max leverage, so ~1.25% on a 40x asset up to ~16.7% on a 3x asset.
  Positions over ~100k USDC liquidate partially, in 20% tranches, on the book; below ~2/3 of maintenance
  margin a backstop liquidation hands the position to the liquidator vault and the maintenance margin is
  **not returned**. Leverage does not change expected return — it changes the distance to forced exit.
- **Fees.** Base tier ~0.045% taker, ~0.015% maker, tiered down by 14-day volume. A round trip is two fills,
  so budget **~0.09% of notional per completed trade** at base. Automated entries and exits are usually takers
  (a market open, a triggered stop, a flip-close all cross the book).
- **HIP-3 builder DEXs** extend the venue beyond crypto — equities, indices, commodities, FX, pre-IPO names —
  under namespaced symbols like `xyz:GOLD`. They may add a builder fee on top, so a builder market is never
  cheaper than the same core market.

## The cost check that kills most perp ideas

Fee drag per day ≈ `trades/day × 2 × (fraction of bankroll per trade) × leverage × 0.00045`.

A 15-minute candle flip at 10x with 10% of the account per trade is `96 × 2 × 0.10 × 10 × 0.00045 ≈ **8.6% of
bankroll per day**, charged win or lose. The signal must beat 8.6%/day before it earns a cent. Per-minute
flipping on the same settings costs ~130%/day — mathematically certain ruin. **Run this number before
presenting any re-entering strategy**, say it plainly, then name the levers that move it: lower leverage, a
longer interval, smaller size, or resting maker entries (~3x cheaper per fill, but they may not fill).

## Where the opportunities are

**Funding carry (the strongest, because it needs no forecast).** Hold the side that receives funding while
cancelling the price risk. Long spot + short perp on the same asset is delta-neutral and collects funding
whenever the rate is positive. Cross-DEX is the same idea when one asset trades on two Hyperliquid DEXs (e.g.
`PAXG` on core and `xyz:GOLD` on a builder DEX): long the lower-funding venue, short the higher, and the two
price exposures cancel. **Direction is decided from live funding, never guessed** — a sign error pays the
carry instead of collecting it. Screen: annualized rate against total holding cost, then depth on both legs.

**Funding extremes as a crowding signal.** A rate far from its own recent range says positioning is
lopsided. Two distinct plays: harvest it (take the paid side and hold), or fade it (crowded positioning
unwinds violently, and the crowded side is the one that gets liquidated). These are opposite trades — say
which one you mean and what confirms it.

**Basis and term structure.** Perp versus spot on the same asset is a spread that funding continuously pulls
to zero. A wide gap is a convergence trade with a mechanism behind it, not a forecast.

**Liquidation cascades.** Forced sellers must trade regardless of price. Open interest concentrated with
leverage stretched means a move triggers liquidations that trigger more. Supplying liquidity into that is
paid; standing in front of it is not. Time-specific and short-lived.

**Newly listed HIP-3 asset classes.** Equities, commodities and FX perps are recent, and their participants
are thinner and less specialised than crypto's. Genuine structural inattention — and the fastest-decaying
edge here.

## Screens

- **Funding**, annualized and compared to the asset's own recent range — not to other assets. Then net it
  against fees over the intended holding period.
- **Open interest and 24h volume** — the depth the ticket must fit inside. A market with zero of both is
  **listed but dead**; several HIP-3 builder DEXs sit deployed with full universes and no participants at all.
  Confirm activity before naming any builder market.
- **Spread and book depth**, walked for the actual size. A rate that looks great on a book that cannot absorb
  the ticket is not an opportunity.
- **Distance to liquidation** at the proposed leverage, stated as a percentage move.

## What kills a perp position

Leverage plus an adverse move, before the thesis resolves. Funding flipping sign mid-trade (the carry becomes
a cost). Fee drag exceeding a thin edge. And on a delta-neutral pair, **leg risk** — one side filling without
the other leaves naked direction until the second fills.
