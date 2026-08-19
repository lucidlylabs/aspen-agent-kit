---
archetype: grid_trading
triggers: place a ladder/grid of buy and sell orders around the current price and
  profit from range-bound chop — "grid bot", "range trading bot", "buy every dip
  sell every rip in a range"
executor: live
gateBlock: open_long_perp
capability:
  - perp
  - indicator
grounding:
  - grid
promptOrder: 910
---

- GRID / RANGE LADDER ("grid bot on ETH between 3000 and 3400", "buy every dip and sell every rip in a range",
  "range trading bot"): add a TOP-LEVEL "grid" object alongside nodes/guards: "grid": { "market": "<market>",
  "lowerPrice": <bottom>, "upperPrice": <top>, "levels": <how many rungs>, "budget": <total USD across ALL
  rungs>, "leverage": <default 1>, "spacing": "arithmetic" | "geometric", "venue": "perp" | "spot" }. Emit NO
  nodes and NO guards for it — the system reads the live mark, places every rung, sizes each one, pairs each
  buy with a sell ONE STEP up, and wires the re-arm guards in CODE. Do not invent rung prices or sizes.
  · `budget` is the TOTAL across all rungs and the hard spend ceiling — it is what the user funds and signs for.
  · Use "venue": "perp" (the default for a leveraged ask) or "spot" when the user wants to hold the token
    outright. Both bank the same grid step.
  · A grid is SHORT VOLATILITY: it earns in chop and bleeds when price trends out of the range. The range-break
    exit is attached by default; say so rather than presenting a grid as risk-free.
  · If the range does not bracket the CURRENT price, or the budget split leaves each rung under the venue
    minimum, the system refuses and says why — relay that rather than retrying with invented numbers.

## What it is

A grid strategy quantizes a price RANGE into N levels and rests a buy below / sell above at each level;
every completed buy→sell round trip inside the range banks one grid step of profit. It is a SHORT-VOLATILITY,
range-bound strategy: it bleeds when price trends out of the range (inventory accumulates on the losing side),
so a real deployment needs a range-invalidation exit (stop beyond the grid edge) — not just the ladder.

## How it maps to Aspen blocks

The model emits only the top-level `grid` directive (market, range, levels, budget, leverage, spacing, venue);
the grounding pass owns the whole money path. It reads the live mark, refuses a range that doesn't bracket it,
computes every rung price (`arithmetic` or `geometric` spacing) and an equal per-rung collateral split, and
refuses when a rung's notional falls under the venue minimum (the silent-no-trade failure). The built graph is
two INSTANCED ladders — buys resting below the mark, sells one step up — with a per-rung re-arm guard
(`instance_filled` on buy rung k arms sell rung k). On the perp venue the rungs are `open_long_perp` entries
banked by SIZED `reduce_perp` exits, plus a range-break exit: a `price_below` guard one full rung-step under
the bottom of the range fires `close_perp` and flattens the book (attached by default via
`invalidateOutsideRange`). Rung prices and sizes are code-stamped — a draft arriving with a hand-written
ladder is re-derived, never trusted.

## Status

Composable today on BOTH venues, including under the early-access launch menu (`hl_spot_buy`/`hl_spot_sell`
joined it 2026-08-16). The grounding pass still refuses a spot grid honestly on any catalog that lacks the
spot blocks. One asymmetry stands: a spot grid gets no automatic range-break exit (the exit size depends on
accumulated inventory, which isn't knowable up front) — the perp grid's `invalidateOutsideRange` stop does
not carry over.
