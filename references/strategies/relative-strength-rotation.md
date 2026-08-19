---
archetype: relative_strength_rotation
triggers: hold a basket of candidate assets weighted toward the strongest-trending ones —
  "relative strength rotation", "rotate into the strongest coins", "overweight the
  best-performing assets of a basket, underweight the laggards"
executor: live
gateBlock: open_long_perp
capability:
  - perp
  - statarb
promptOrder: 90
grounding:
  - rel_strength
defaults:
  lookback: 30
  interval: 1d
---

- RELATIVE-STRENGTH ROTATION (user wants to hold a basket "tilted toward the strongest movers" / "relative
  strength" / "overweight the best performers"): add a TOP-LEVEL "relStrength" object alongside nodes/guards:
  "relStrength": { "budget": <total USD across the basket>, "lookback": 30, "interval": "1d",
  "leverage": <default 1> } (change lookback/interval/leverage only if the user states them). Emit ONE
  open_long_perp leg PER candidate asset (at least 2), each with its "market" set and its "collateral" left as
  "0" — a PLACEHOLDER. The system reads each leg's momentum over the lookback, RANKS the legs, and sizes every
  leg's collateral by rank (strongest gets the most) in CODE, so do NOT guess the weights yourself.

## What it is

A momentum-tilted basket: rank a fixed set of candidate assets by trailing momentum and weight the position
toward the strongest, away from the laggards. Distinct from `momentum_trend` (a single asset crossing its OWN
threshold) and `market_neutral_basket` (hedged long/short): this is a long-only basket whose weights lean on
relative strength.

## Notes

The momentum-rank weighting is CODE-owned: `groundRelStrength` (`compose/relStrengthGrounding.ts`) runs at
compose time — it reads each `open_long_perp` leg's momentum over the lookback, ranks them, and writes each
leg's `collateral = budget × (rank / Σranks) / leverage`. The LLM never invents the weights. FAIL-CLOSED:
fewer than 2 legs, a feed error, or too-short history refuses the sizing rather than guessing. v1 sizes AT
OPEN (a single tilt); a recurring rotate-out-of-laggards execution model is a follow-up.

## Why this sizing stays CODE-owned

Measured, not assumed (`docs/agent-vs-code-sizing.md`): given the same closes, the exact formula and
temperature 0, `deepseek-v4-pro` mis-sized a three-asset inverse-vol basket by +4% / -10% / -14%. The error is
SYSTEMATIC — it over-weights the calm asset and under-weights the volatile ones — so the book is not risk
parity, it is a tilted long basket wearing the name. And the deploy card cannot reveal it: both weight sets
look equally plausible, and checking means redoing a 30-point standard deviation per leg. The 2026-07-31
"agent decides, card confirms" policy therefore does NOT apply here — confirmation is only a control for a
number the user can actually evaluate.
