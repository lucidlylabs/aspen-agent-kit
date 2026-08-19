---
archetype: market_neutral_basket
triggers: long a basket of assets AND short another basket to hedge, with a
  take-profit/stop-loss on the WHOLE portfolio
executor: live
gateBlock: portfolio_pnl_below
capability:
  - perp
  - statarb
promptOrder: 10
grounding:
  - basket_hedge
defaults:
  mode: beta
  lookback: 60
  interval: 1h
  minCorrelation: 0.5
---

- MARKET-NEUTRAL BASKET (user wants to long a basket AND short another basket to hedge, with a take-profit/
  stop-loss on the WHOLE portfolio): add a TOP-LEVEL "hedge" object alongside nodes/guards:
  "hedge": { "mode": "beta", "lookback": 60, "interval": "1h", "minCorrelation": 0.5 } (defaults — change
  only what the user states; use "mode":"dollar_neutral" for an equal-dollar hedge). Long legs: open_long_perp
  with the user's stated collateral. Short (hedge) legs: open_short_perp with collateral "0" as a PLACEHOLDER —
  the system computes the real hedge sizes from price history, so do NOT guess them. Whole-book exit: a
  portfolio_pnl_above (take-profit) and/or portfolio_pnl_below (stop-loss) guard pointing at EACH close_perp leg.

## Notes

The hedge sizing is CODE-owned: `groundBasketHedge` runs inside `composeTurn` (after the money-path
gate) — it fetches aligned price history, computes multivariate OLS betas (`basketHedge.ts`), and fills the
placeholder short collaterals via `hedgeNotionals`. The LLM never invents betas. Weak or negative-beta legs
are surfaced as deploy-card warnings, and an unresolvable leg fails the compose closed. The whole-book exit
is engine-evaluated off-chain (`evalPortfolioPnlGuard`) because HL native TP/SL is per-position only.

## Why this sizing stays CODE-owned

Measured, not assumed (`docs/agent-vs-code-sizing.md`): given the same closes, the exact formula and
temperature 0, `deepseek-v4-pro` mis-sized a three-asset inverse-vol basket by +4% / -10% / -14%. The error is
SYSTEMATIC — it over-weights the calm asset and under-weights the volatile ones — so the book is not risk
parity, it is a tilted long basket wearing the name. And the deploy card cannot reveal it: both weight sets
look equally plausible, and checking means redoing a 30-point standard deviation per leg. The 2026-07-31
"agent decides, card confirms" policy therefore does NOT apply here — confirmation is only a control for a
number the user can actually evaluate.
