---
archetype: donchian_breakout_pyramid
triggers: enter on a new N-day high/low (Donchian channel breakout) and add to the position
  as the trend extends — "Turtle strategy", "Donchian breakout", "pyramid into a trend",
  "buy new highs and add on the way up"
executor: live
gateBlock: donchian_high_break
capability:
  - perp
  - indicator
promptOrder: 45
defaults:
  period: 20
  interval: 1d
  adds: 4
  leverage: 1
---

- DONCHIAN BREAKOUT / TURTLE PYRAMID ("Turtle strategy on BTC", "buy new 20-day highs and add on the way up",
  "pyramid into the trend", "Donchian breakout"): the user wants ONE position built in STAGES, each stage added
  on a fresh breakout. Emit ONE instanced open node whose `slots` is the number of adds, plus one guard per
  rung, plus a REQUIRED opposite-channel exit:
    · node: { "id": "rungs", "primitive": "open_long_perp", "slots": <adds>, "instances": [ { "market": "<M>",
      "collateral": "<per-rung size>", "leverage": "<lev>" }, … one per add, all the SAME market ] }
    · rung 0 guard: donchian_high_break { "market": "<M>", "period": <N>, "interval": "<candle>" } → do "rungs#0"
    · rung i guard (i ≥ 1): all( donchian_high_break {same params}, instance_filled { "node": "rungs",
      "index": <i-1> } ) → do "rungs#<i>". The `instance_filled` term is what makes it a PYRAMID rather than
      N independent entries — a rung may only open once the rung before it has actually filled.
    · exit: ONE close_perp guarded by donchian_low_break { "market": "<M>", "period": <N>, "interval": "<candle>" }
      → the opposite channel. This is the Turtle exit and it is NOT optional; a pyramid with no exit keeps
      adding into a trend it can never leave.
  · `collateral` is the PER-RUNG size, never the total. The system funds `slots × per-rung`, so say that product
    out loud when you present it ("four adds of $125 — $500 in all"). Split the user's stated budget evenly
    across the rungs unless they describe a different ladder.
  · `adds` must be BOUNDED and small (default 4). Take it from the user's words ("add three times") or use the
    default and say the number — an unbounded pyramid has no spend ceiling to sign for.
  · Defaults: period 20, interval "1d", leverage 1. Change only what the user states. A "20-day high" means
    period 20 with interval "1d"; a "20-bar high on the 4h" means period 20 with interval "4h".
  · SHORT variant (user wants to sell new lows and add as it falls): swap every direction — open_short_perp
    rungs gated on donchian_low_break, exit close_perp gated on donchian_high_break.
  · Put the SAME `market` on every instance. Do not mix markets in one pyramid — that is a basket
    (`relative_strength_rotation` / `risk_parity_allweather`), not a Turtle.

## What it is

The classic Turtle-trading shape: enter when price makes a new N-period high (long) or low (short) — a Donchian
channel breakout — then ADD to the position as the trend extends, exiting the whole thing when price breaks the
OPPOSITE channel. Distinct from `momentum_trend` (a single entry/exit on a momentum threshold): this is
multi-entry, with size building in stages tied to the same breakout signal re-triggering.

## Notes

Both ingredients are live and neither is new to this card. The signal is `donchian_high_break` /
`donchian_low_break` (`indicatorBlocks.ts`), which desugar to a `compute` over the `donchian_high_value` /
`donchian_low_value` readers — rolling N-period extremes over the same candle feed RSI and z-score use, and
FAIL-CLOSED on a missing feed or short history exactly as they do.

The staging is the RUNG machinery `grid_trading` and `slot_rotation` already run on: an instanced node with
`slots`, `reconcileInstances` attributing fills per rung, and the `instance_filled` condition resolved in
`executors/graph.ts`. There is no new execution model here — a pyramid is a ladder whose rungs are gated on a
breakout instead of a price level.

Spend is bounded at compose time by `slots × per-rung collateral`, so the whole pyramid is funded by one
signature and cannot exceed what the user signed for, no matter how many times the channel breaks.

⚠ Sizing is AGENT-OWNED (the 2026-07-31 policy, as in `slot_rotation` and `cash_and_carry`): an even split of a
stated budget across a stated number of rungs is arithmetic the user can check on the card. What stays in code
is the venue-max leverage clamp and the per-rung venue minimum — a rung too small to fill is refused rather
than silently placed.

## Non-goals

- **No risk-budget sizing.** Real Turtle sizing scales each add by N (ATR) against an account risk fraction.
  There is no ATR reader today, so rungs are an even split. If the user asks for volatility-scaled adds, say
  that plainly rather than approximating it with an even ladder.
- **No ratcheting trailing stop.** The exit is the opposite Donchian channel, which does trail with the range,
  but it is not a per-add stop that tightens with each rung. `trailing_stop` exists as a block and can be added
  as a separate exit if the user asks for one.
