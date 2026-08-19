---
archetype: orderbook_depth_skew
triggers: trade an imbalance between resting bid/buy-side and ask/sell-side depth on the order
  book — "orderbook imbalance", "depth skew", "trade the bid/ask imbalance", "more buy orders
  than sell orders"
executor: live
gateBlock: depth_skew_above
capability:
  - perp
  - indicator
promptOrder: 97
defaults:
  threshold: 0.3
  levels: 10
  leverage: 1
---

- ORDER-BOOK DEPTH SKEW ("trade the orderbook imbalance on ETH", "go long when bid depth far exceeds ask
  depth", "depth skew", "more buy orders than sell orders"): the book is BID-heavy or ASK-heavy and the user
  wants to lean with it. The reading is a signed ratio in -1..+1 — +1 = all resting size is on the bid, -1 = all
  on the ask, 0 = balanced.
    · open node: open_long_perp (bid-heavy) or open_short_perp (ask-heavy) with the user's amount + leverage.
    · entry guard: depth_skew_above { "market": "<M>", "threshold": <t>, "levels": <n> } for a long, or
      depth_skew_below with a NEGATIVE threshold (e.g. -0.3) for a short.
    · exit: REQUIRED, and it must NOT be the skew flipping back on its own. Book imbalance decays in seconds;
      an exit that waits for the skew to invert can sit in a losing position indefinitely. Use a take-profit AND
      a stop-loss on the open node (takeProfitPct / stopLossPct), or a close_perp on a price guard. State both
      numbers — they are what bound a trade whose signal has no natural exit.
  · PAIR IT WITH A SECOND TERM. A bare skew entry is the weakest shape on this card: resting size can be pulled
    the instant it is leaned on. Prefer an `all(...)` combining the skew with a confirming signal — a momentum
    term in the same direction, or relative_volume_above so the imbalance is backed by real trading. Emit the
    bare form only if the user explicitly insists, and say what they are trading.
  · Defaults: threshold 0.3 (bids carry ~30% more of the book's notional than asks), levels 10, leverage 1.
    `levels` is how deep to look — deeper sees more resting interest but lets a far-away wall dominate a signal
    that is meant to describe the touch.
  · SAY THE HALF-LIFE OUT LOUD. This is the shortest-lived signal in the catalog. If the user describes holding
    for hours or days on a book imbalance, tell them the signal will be long gone and the position will be
    riding on nothing but the TP/SL.
  · Hyperliquid perp markets only — the reading comes from the HL resting book. There is no depth feed for spot
    tokens or for another venue.

## What it is

A lean on resting order-book imbalance: when far more size rests on one side than the other, take the side with
the backing. A microstructure trade, not a technical one — it reads the CURRENT book rather than price history.

## Notes

The math (`depthSkew`, `execImpact.ts`) sums resting size weighted by PRICE into notional rather than raw base
units, so the two sides are compared in the same currency; summing units would let a cheaper side win on count
alone. It is bounded to `levels` per side and returns undefined on an empty, one-sided-empty or degenerate book,
so a guard reading it fails CLOSED and never fires on a book it could not measure.

The engine reads the book through its own `bookFeed` port (`adapters/bookFeed.ts`), not the per-strategy signed
client: `l2Book` is public data and a public read should not depend on a burner's credentials. The adapter's
cache TTL is deliberately sub-tick (2s) — it exists only to collapse duplicate reads within one tick, never to
carry a book across ticks. Past the TTL the entry is dropped rather than served, because a stale book is exactly
the input that would make this fire wrongly.

⚠ Depth skew is SPOOFABLE. Resting orders are not commitments and can be cancelled the moment they are leaned
on; a wall can be placed precisely to attract this trade. That is a property of the signal, not a defect in the
reading, and it is why the guidance pushes toward a confirming term and a hard stop.

## Non-goals

- **No queue position, no flow, no trade tape.** This reads the resting book only. It does not know order
  arrival rate, cancellations, or executed aggressor flow — order-flow imbalance is a different and stronger
  signal that would need a trade-tape feed the engine does not have.
- **No sub-second reaction.** The fastest cadence tier is 8s and this guard sits on the 30s default, so a book
  imbalance that lives for two seconds will never be seen. This is for imbalances persistent enough to survive a
  tick, not for latency trading.
- **No market making.** Leaning on an imbalance is directional. Quoting both sides to earn the spread is
  `market_making_volume_farming`, which needs resting-order lifecycle management the engine does not have.
