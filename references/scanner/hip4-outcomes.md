---
module: hip4-outcomes
instrument: Hyperliquid HIP-4 outcome markets
venue: hyperliquid
triggers: HIP-4 outcome markets — YES/NO shares, binary contracts, "hyperliquid prediction
  markets", "bet on BTC ending above", settlement, settleFraction, dated outcome contracts.
  Names only THIS instrument — a sibling venue mentioned here would steal its queries.
---

# Hyperliquid HIP-4 outcome markets

## What it is, from first principles

A HIP-4 market is a **fully collateralized binary contract bounded in [0, 1]**. It has two sides, Yes and No.
At its settlement date the market publishes a `settleFraction`: Yes converts to that many quote tokens, No
converts to `1 − settleFraction`. The two always sum to exactly 1.

That identity is the whole instrument. Because Yes and No must sum to 1 at settlement, a **price is a
probability** — paying 0.62 for Yes is paying 62 cents for a contract that becomes worth 1.00 or 0.00. The
market's quote is its consensus estimate of the event happening, and disagreeing with it is a statement about
a probability, not about a price level.

Three properties follow directly, and they change how these behave versus a perp:

1. **Bounded loss, no liquidation.** Every position is fully collateralized. The most you lose is what you
   paid. There is no margin call and no forced exit — nothing can take the position away before settlement.
2. **A guaranteed end date.** Unlike a perp, which can drift indefinitely, a dated contract *must* converge to
   0 or 1. A gap between today's price and your estimate has a deadline attached, which converts a forecast
   into a countdown.
3. **A payoff that is a step, not a slope.** Being more right does not pay more. A Yes contract pays the same
   1.00 whether the outcome barely happened or overwhelmingly happened. Never size one like a directional
   position expecting the payoff to scale with the move.

## How it works on Hyperliquid

- **Merged books.** Yes and No share liquidity: **buying Yes at `p` is the same trade as selling No at
  `1 − p`**. There are not two independent books to arbitrage against each other — reason in the `p / 1−p`
  duality or you will double-count the same order.
- **Settlement is automatic.** Proceeds are credited at settlement; there is no claim or redeem call to make.
- **The quote token is per-market data.** Some markets quote in USDC, others in USDH. Read it from the venue —
  never assume, because an unknown quote token makes a sizing decision unsound.
- **Fees fall on the exit, not the entry.** Opening is fee-free; fees apply on close, burn or settlement, and
  are currently set to zero for initial testing. Maker orders pay zero and there are no maker rebates.
- **Symbols name the outcome**: `<selector>:YES` or `<selector>:NO`, where the selector is a pinned outcome
  id, a recurring instance like `BTC-1d`, or a specific dated expiry. **Recurring markets rotate** — each
  instance is a new outcome id, so ids must never be pinned ahead of time; resolve against the live venue.
- **No leverage, no reduce-only, and no venue-side triggers.** A probability take-profit or stop is a polled
  guard plus a sell, not a resting instruction the venue holds for you.

## Where the opportunities are

**Hold-to-settlement is structurally favoured, and this is the non-obvious edge.** Because the fee event is
the *exit*, a position opened and carried to settlement pays less than one opened and closed on the book. The
instrument quietly rewards conviction over churn — the opposite of a perp, where every re-entry is taxed twice.
Any HIP-4 idea that involves frequent flipping is fighting the fee structure; one that holds to the date is
working with it.

**Convergence to the date.** As settlement approaches, price must collapse toward 0 or 1. A contract still
priced mid-range close to its date is either genuinely uncertain or slow to update. This is the mechanism with
a guaranteed end — no other instrument here offers that.

**Probability disagreement.** The purest form: you believe the true chance differs from the quoted one, and
you can say why. This demands an actual estimate, not a feeling. If you cannot state your number and where it
comes from, there is no trade — only a bet.

**Cross-venue against Polymarket.** When both venues list the same question, YES on the cheaper plus NO on the
dearer for a combined cost under 1.00 pays exactly 1.00 on one leg at settlement. See the scanner hub for the
sequencing constraint on mixed graphs.

**Price-threshold markets against the perp.** A market on "<asset> above <strike> on <date>" and that asset's
perp price the same underlying variable. A gap between the market's implied probability and the perp-implied
probability is convergence rather than a forecast.

## Screens

- **Distance from the extremes.** Mid-range (roughly 0.15–0.85) has room to move and usually real two-sided
  interest. At 0.02 or 0.97 there is little distance left and fills are poor.
- **Time to settlement** against the thesis. Too far out and capital sits idle; too close and only the
  convergence play is live.
- **Book depth on the merged book**, walked for the ticket. Outcome markets are newer and thinner than the
  major perps.
- **The quote token**, read from the venue, before any sizing.
- **Whether the market is recurring**, since the tradeable instance rotates and the id you saw last tick may
  no longer exist.

## What kills a HIP-4 position

Settlement against you — a losing side goes to **zero**, which is the normal outcome half the time and must be
sized for. `settleFraction` need not be a clean 0 or 1, so read the settlement rule rather than assuming a
binary. The market is builder-deployed and builder-operated, so the deployer and the settlement source are a
trust assumption worth surfacing to the user. And the flat payoff means a position that is directionally right
but wrong at the boundary pays exactly nothing.
