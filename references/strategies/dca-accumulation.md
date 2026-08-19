---
archetype: dca_accumulation
triggers: buy a fixed amount on a schedule regardless of price — "DCA into ETH",
  "dollar-cost average", "buy $X every day/week", "accumulate slowly over time"
executor: live
# NOT `every_interval`: that is an ALWAYS-ON core primitive, so gating on it would inject this guidance into
# every prompt — including a swap-only catalog with no `open_long_perp` for the guidance to emit. The gate is
# the perp-capability block the recipe actually uses; the recurrence trigger is always present anyway.
gateBlock: open_long_perp
capability:
  - perp
# 75, not 80: `risk-parity-allweather` holds 80, and a tie is broken only by filename order — so a rename would
# silently reshuffle the prompt. Sits between pair-stat-arb (70) and risk-parity (80), which is where the tie
# was resolving anyway.
promptOrder: 75
---

- DCA / SCHEDULED ACCUMULATION ("DCA $25 into ETH every week for 4 weeks", "dollar-cost average into BTC daily
  for a month", "buy $50 of HYPE weekly, 8 buys"): emit ONE open (open_long_perp with the PER-BUY collateral +
  leverage) and ONE guard — every_interval { "interval": "<gap>", "times": <count> } — pointing at that open.
  The node's `collateral` is the size of ONE buy, NEVER the running total: the system funds `collateral × times`
  in a single up-front transaction and states that total on the confirmation card.
  · `times` is REQUIRED and must be BOUNDED. Take it from the user's own count ("4 buys") or from their horizon
    divided by the interval ("weekly for two months" → 8). If they give NEITHER a count nor an end date you may
    PROPOSE a sensible bounded count rather than refusing — but say the number and the resulting total out loud
    ("8 weekly buys, $200 in all"), because `collateral × times` is the whole spend and it is what the user signs
    for. Never leave it unbounded: the checker refuses an unbounded recurrence, and an open-ended schedule has no
    second signature to ask for.
  · If the user gives a TOTAL plus a count ("$100 into ETH over 4 weekly buys"), the per-buy collateral is the
    total divided by the count ($25). If they give a per-buy amount ("$25 a week"), use it as stated. Either way
    `collateral × times` must equal what the user meant to spend — that product is what they are shown and sign.
  · Do NOT attach a take-profit or stop-loss unless the user asks for one: DCA is accumulate-and-hold, and a
    missing exit is warned about, never blocked. If they DO state an exit, add the close_perp + price guard
    exactly as in the perp take-profit/stop-loss recipe.
  · Never mention bridging — the Base→Hyperliquid funding leg is attached automatically, for the full bounded
    amount, and the user never asks for it.

## Notes

`every_interval` is a recurrence trigger (`recurrence: true`): its guarded node runs once PER interval rather
than once for the whole graph, and the engine enforces the `times` bound with a per-node fire count, retiring
the strategy when the count is reached. The checker refuses a recurring guard with no `times` — there is no
unbounded-spend shape.

Two money-path facts are code-owned and must not be recomputed by the model: `attachFundingBridge` bridges
`collateral × times` (not one slice), and `graphFundAmount` funds the same product — so the single user-signed
fund transaction covers every scheduled buy up front. Leverage is the agent's to choose when the user
doesn't state one (policy 2026-07-31) — emit a sensible number and say it. What still runs in code is the
venue-max clamp, because a cap is not something a user can check from a card.

A recurring node's non-recurring guards are PRECONDITIONS, not alternative triggers. The auto-attached
`funds_on_hypercore` gate is the case that matters: without that rule `every_interval` (which fires immediately
when it has never fired) would schedule the first buy while the funding bridge was still in flight, sending a
$0-collateral open to the venue on every tick until the money landed. Pinned in `engine.dryrun.ts`.

## Non-goals

This is deliberately the bounded, single-asset, fixed-slice shape. It is NOT the standing basket accumulator
found in other systems (e.g. senpi's Tortoise), and the differences are structural rather than cosmetic:

- **One asset, one clock.** No basket, and no "whichever asset is most overdue wins this tick" arbitration —
  that needs a select-one-of-basket primitive Aspen does not have (the same gap `relative_strength_rotation`
  names).
- **Fixed slice, not a percentage of live equity.** Sizing off "% of withdrawable" is incompatible with the
  funding model: the total is computed at compose time and the user signs ONE fund transaction, so the burner
  holds exactly what was committed — there is no growing balance to take a percentage of.
- **Bounded, not open-ended.** `times` is mandatory. An indefinitely-running accumulator would need repeated
  funding signatures or a live-balance read at execution time.
- **No automatic trailing exit.** Exits are only what the user asked for; there is no trailing-stop block today
  (a stop is a fixed level), so "let winners run on a ratchet" is not expressible yet.

Basket DCA can be approximated today by composing several independent DCA legs, each with its own
`every_interval` guard — that gives parallel clocks but no shared slot cap and no most-overdue arbitration.
