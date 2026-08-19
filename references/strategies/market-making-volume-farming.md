---
archetype: market_making_volume_farming
triggers: post resting orders on both sides to earn maker rebates / hit a fee-tier volume
  target, NOT to take a directional view — "market maker bot", "farm maker rebates",
  "generate volume for a fee discount", "post both sides passively"
executor: knowledge-only
refuse: "MARKET MAKING / volume or rebate farming — posting resting quotes on both sides to earn the spread or hit a fee tier. The engine has no resting-order lifecycle (no per-level re-arm, no inventory tracking); a pair of one-shot opens is a directional straddle, not a two-sided quote."
capability:
  - perp
promptOrder: 1040
---

## What it is

Not a directional trade at all — the goal is to rack up volume/maker-rebate fee-tier progress by resting
orders on both sides of the book and flipping frequently, staying roughly flat net exposure. Distinct purpose
from every other card here: PnL from the trade itself is incidental (ideally near-zero); the payoff is the
FEE SCHEDULE (see `hyperliquid-perps.md`'s tiered maker/taker rates), not the market.

## Relation to what is live

Aspen can already place resting post-only orders and cancel or modify them — the low-level pieces exist
(they are the same ones the grid-trading gap notes).

## What is missing

This isn't really a "signal" archetype — it needs symmetric two-sided quote management: post both sides,
re-quote as price moves, and track net exposure so it doesn't drift into an accidental directional bet. It
also needs sizing against a VOLUME target rather than a profit target, which no strategy built today can
express. Closer to grid trading's per-level lifecycle gap than to any indicator-driven card.

Tracked: the subsystem behind this refusal is
[#226](https://github.com/lucidlylabs/useaspen-monorepo/issues/226) (resting-order lifecycle — two-sided
quoting, per-level re-arm, inventory tracking, volume-target sizing). Until it lands, the refusal stands.
