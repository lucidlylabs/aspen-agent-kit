---
venue: hyperliquid-hip4
section: prediction-markets
title: Hyperliquid HIP-4 outcome markets
docs: https://hyperliquid.gitbook.io/hyperliquid-docs
triggers: >-
  HIP-4, hyperliquid outcome market, hyperliquid prediction market,
  buy YES on hyperliquid, settleFraction, merged outcome book
---

# Hyperliquid HIP-4 — outcome markets

**Source:** docs → *Hyperliquid Improvement Proposals → HIP-4*, plus the API reference for order
mechanics and the fees page for the outcome-token fee rules.

## What it is

HIP-4 adds **fully collateralized outcome contracts** to Hyperliquid's engine: binary instruments
that settle within `[0, 1]`. Each market has a **Yes** and a **No** side. At settlement, Yes converts
to `settleFraction` of the quote token and No to `1 − settleFraction`, credited automatically — there
is no redeem call to make.

Relative to perps on the same venue: **no leverage, no liquidation** (every position is fully
collateralized), and contracts are **dated** with non-linear payoffs rather than perpetual.

## The properties that change how you trade it

- **The Yes and No books are merged.** They share liquidity: buying Yes at *p* is the same as selling
  No at *1 − p*, and a Yes buy can match against a No sell. Reason in the `p / 1−p` duality; treating
  them as two independent books will produce phantom arbitrage that does not exist.
- **The quote token is per-market data.** Do not assume USDC. Read it from the market's metadata. An
  unknown quote token should fail a sizing decision closed, not default to something.
- **Recurring markets rotate.** Instruments that recur on a schedule create a **new** market instance
  each period. Ids are therefore not stable — resolve them per tick against live metadata rather than
  pinning at compose time.
- **Asset ids use their own offset scheme** with the Yes/No side encoded into the id. Same
  order-placement path as perps; different id arithmetic.
- **No leverage step, no reduce-only semantics, no server-side triggers.** A probability-based take
  profit or stop loss must be implemented as your own guard plus a sell order. There is nothing on
  the venue to lean on.
- **It is builder-deployed and builder-operated**, like HIP-3. The deployer and the settlement source
  are a trust assumption. Surface them before sizing.

## Fees are backwards, deliberately

**Fees are charged only on close, burn, or settlement. Opening a position is free.** Maker orders pay
zero and there are no rebates; users who would earn rebates on perps and spot simply pay nothing as a
maker here. At settlement each side is charged against `settle_fraction × size`.

This inverts the usual entry/exit cost logic:

- **Entry is costless**, so the "is it worth entering?" bar is set entirely by spread and by your
  edge, not by fees.
- **You will pay on the way out either way** — whether you close early or hold to settlement. There
  is no fee saving from holding to expiry, which is different from most venues where letting a
  position expire avoids an exit fill.
- **The cost of being wrong is capped at collateral**, but a losing side settles to **0**. "No
  liquidation" is not "no total loss".

## Practical guidance

Because HIP-4 sits on the same connection as Hyperliquid perps and spot, its real strength is
**combination**: an event contract and a perp position on the same account, same collateral surface,
one integration. The cleanest shape is using the event market as a *gate* on a perp position rather
than holding capital on both sides — see
[../quant/strategies/prediction-markets.md](../quant/strategies/prediction-markets.md).

Be aware of the venue-level execution constraint that a single tick generally acts on one venue
surface at a time. Two entry legs on different surfaces should be sequenced — one opens, the other is
guarded on the first leg's state — rather than fired simultaneously and hoped for.

## What to verify live, every time

The quote/collateral token. The current market instance id for any recurring instrument. Settlement
date and settlement source. The deployer. Current fee treatment (this is a newer surface and its fee
rules have been explicitly provisional).
