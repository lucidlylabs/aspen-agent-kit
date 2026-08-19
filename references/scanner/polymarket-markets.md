---
module: polymarket-markets
instrument: Polymarket prediction markets
venue: polymarket
triggers: Polymarket opportunities — which prediction market to trade, event and election
  and macro markets, YES/NO shares, odds, "scan polymarket", "find a relevant market",
  whale and smart-money flow, market resolution, UMA oracle, neg-risk multi-outcome events
---

# Polymarket prediction markets

## What it is, from first principles

A Polymarket market turns a real-world question into two **outcome tokens**, YES and NO. After the question
resolves, the winning token redeems for **$1** and the losing one for **$0**. There is no leverage and no
liquidation; the most a position can lose is what was paid for it.

Because the pair must sum to $1 at resolution, the price is a **probability** — and the mechanism that keeps
it honest is worth stating exactly, because it is what makes the whole thing scannable. Anyone can convert $1
of collateral into one YES **and** one NO (a "split"), and burn one of each back into $1 (a "merge"). If YES
and NO ever traded for more than $1 together, splitting and selling both is free money; if less, buying both
and merging is. **Those two operations are the arbitrage that pins the pair to $1** — not goodwill, and not the
operator.

One consequence is routinely missed: **price is not quite probability.** Capital is locked until resolution
and earns nothing, so a market resolving far in the future must price *below* its true probability to
compensate for the wait. A market at 0.95 resolving in twelve months is not claiming 95% — it is claiming
roughly 95% *minus the cost of parking money for a year*. On long-dated near-certain markets that wedge is the
trade, and it is a structural feature rather than anyone's mistake.

## How it works

- **Hybrid execution.** A trader signs an EIP-712 limit order **off-chain** and posts it to the CLOB operator,
  which matches it and settles the matched trade **on-chain**. The operator never takes custody, sets prices
  or moves funds — it can only match and order.
- **Polygon, and pUSD collateral.** Markets live on Polygon. Collateral is pUSD, an ERC-20 backed 1:1 by USDC
  and wrapped from bridged USDC.e — not raw USDC.
- **YES and NO are distinct token ids**, not two views of one instrument. "Buy NO" means buying the NO token.
- **Two exchanges.** Standard markets settle on the main Exchange; multi-outcome ("neg-risk") events settle on
  a separate one. The flag must match the market or the order mis-routes.
- **Per-market tick size and minimum order size.** A price off the tick grid is rejected outright, so both
  must be read per market rather than assumed.
- **Open orders reserve the whole per-market balance**, so a second order on the same market can be rejected
  even when the balance looks sufficient.
- **Position primitives are direct on-chain calls**: split (mint a YES+NO pair from collateral), merge (burn a
  pair back to collateral), redeem (claim after resolution), and convert on neg-risk events.

## Where the opportunities are

**Selection is most of the edge.** Polymarket carries tens of thousands of active markets. Almost all of the
work is choosing which one to look at, and the volume-ranked default list is the worst possible filter — it
returns whatever is culturally loud to every user identically. **Always query by the asset, event or theme
actually under discussion.**

Screens that find real candidates:

- **Volume spike** — 24h volume large relative to the market's own history or its liquidity.
- **Price velocity** — the midpoint moved several cents in a session with no matching news.
- **Thin-book distortion** — a wide spread and shallow book on a high-attention market: mispricing, or
  someone pushing it.
- **Expiry hunting** — markets near their end date still priced mid-range, where convergence has a deadline.
- **New-market surge** — young markets whose volume ramps unusually fast.

**Structural biases.** Prediction markets persistently overprice longshots and underprice near-certainties —
the mirror image of the capital-cost wedge above, and reinforced by it at long horizons. Real, well
documented, and slow-moving.

**Flow signals.** Large single prints, one wallet accumulating across consecutive fills, or a top holder
exceeding a meaningful share of open interest. Treat these as *context*, never as a signal on their own:
whales are sometimes informed and often merely rich. Splits, merges and neg-risk conversions appear as
position changes without book trades, so read activity before calling something a "buy".

**Pairing with Hyperliquid.** A market with a mechanical read-through to a crypto price (a rate decision, an
ETF or listing approval, an upgrade or unlock date) can gate a perp position — the strongest combination,
because it needs no capital on Polygon at all. See the scanner hub for the linkage test and the constraints on
mixed graphs.

## Screens

- **Price band** roughly 0.15–0.85, unless the trade *is* the convergence at an extreme.
- **Liquidity against the intended ticket**, plus the tick size — a market with a few hundred dollars of
  liquidity cannot absorb a real order at anything like the quoted price.
- **End date** inside the user's horizon, and far enough out for the thesis to play.
- **Resolution source and criteria**, read before entry, not after.
- **Whether the event is neg-risk**, since multi-outcome events split volume across legs and route
  differently — screen at the event level too.

## What kills a Polymarket position

**Resolution risk is the distinctive one, and it is not a price risk.** Markets resolve through UMA's
optimistic oracle: a proposer posts a bond, there is a challenge window of about two hours, and a dispute
escalates to a multi-day token-holder vote. Polymarket can also publish clarifications that change a market's
effective rules *after* entry. So a position can be correct about the world and still lose, or be tied up far
past the expected date. Treat resolution timing and outcome as an outside signal, never a controllable step.

Also: a 50-50 resolution pays each side $0.50, and a "Too Early" resolution can void — read the actual
resolution outcome rather than assuming a clean $1/$0. Exiting means selling on the book or merging a full
YES+NO set; a lopsided position cannot be merged, so the excess has to be sold at whatever the book offers.
