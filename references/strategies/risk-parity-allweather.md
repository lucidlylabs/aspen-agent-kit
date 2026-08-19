---
archetype: risk_parity_allweather
triggers: hold a long-only multi-asset basket weighted by inverse realized volatility
  ("risk parity"), so every leg contributes roughly equal risk — "all-weather portfolio",
  "risk-parity basket", "balance my exposure by volatility not by dollar size"
executor: live
gateBlock: open_long_perp
capability:
  - perp
  - statarb
promptOrder: 80
grounding:
  - risk_parity
defaults:
  lookback: 30
  interval: 1d
---

- RISK-PARITY BASKET (user wants a long-only basket "weighted by volatility not dollars" / "risk parity" /
  "all-weather", so a calmer asset gets a BIGGER position and a choppier one a SMALLER one): add a TOP-LEVEL
  "riskParity" object alongside nodes/guards: "riskParity": { "budget": <total USD across the basket>,
  "lookback": 30, "interval": "1d", "leverage": <default 1> } (change lookback/interval/leverage only if the
  user states them). Emit ONE open_long_perp leg PER basket asset (at least 2), each with its "market" set and
  its "collateral" left as "0" — a PLACEHOLDER. The system reads each asset's realized volatility over the
  lookback and sizes every leg's collateral by INVERSE VOLATILITY in CODE, so do NOT guess the weights or
  split the budget yourself. Optional whole-book exit: portfolio_pnl_above / portfolio_pnl_below guards
  pointing at close_perp legs.

## What it is

A LONG-ONLY multi-asset basket sized so every leg contributes roughly EQUAL risk, not equal dollars — a
low-volatility asset gets a bigger position, a high-volatility one gets a smaller one. Distinct from
`market_neutral_basket` (long/short hedged) and `macro_thesis_basket` (a single directional narrative): this
is a STANDING allocation weighted by volatility, not a single thesis or a hedge.

## Notes

The inverse-volatility weighting is CODE-owned: `groundRiskParity` (`compose/riskParityGrounding.ts`) runs at
compose time — it reads each `open_long_perp` leg's return-volatility (sample stdev of simple returns) over the
lookback and writes each leg's `collateral = budget × weight_i / leverage`, weights ∝ 1/volatility. The LLM
never invents the weights. FAIL-CLOSED: fewer than 2 legs, a feed error, too-short history, or a zero-volatility
leg refuses the sizing rather than guessing. v1 sizes AT OPEN; a periodic rebalance cadence is a follow-up.

## Why this sizing stays CODE-owned

Measured, not assumed (`docs/agent-vs-code-sizing.md`): given the same closes, the exact formula and
temperature 0, `deepseek-v4-pro` mis-sized a three-asset inverse-vol basket by +4% / -10% / -14%. The error is
SYSTEMATIC — it over-weights the calm asset and under-weights the volatile ones — so the book is not risk
parity, it is a tilted long basket wearing the name. And the deploy card cannot reveal it: both weight sets
look equally plausible, and checking means redoing a 30-point standard deviation per leg. The 2026-07-31
"agent decides, card confirms" policy therefore does NOT apply here — confirmation is only a control for a
number the user can actually evaluate.
