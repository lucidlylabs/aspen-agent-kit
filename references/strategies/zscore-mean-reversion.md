---
archetype: zscore_mean_reversion
triggers: long/buy when price is unusually cheap vs its rolling mean (z-score ≤
  −2) and exit as it reverts to the mean — single-asset z-score mean-reversion
  on a Hyperliquid perp (or spot)
executor: live
gateBlock: zscore_below
capability:
  - perp
  - indicator
promptOrder: 50
defaults:
  period: 20
  enter: -2
  exit: 0
---

- Z-SCORE MEAN-REVERSION ("long ETH when it's 2σ below its 20-period mean, close when it reverts"): entry gated by
  zscore_below (price unusually cheap), exit gated by zscore_above (reverted to the mean). On a Hyperliquid perp:
  open_long_perp (user's collateral + leverage) guarded by { "primitive": "zscore_below", "params": { "market":
  "<M>", "period": 20, "threshold": -2 } } and a close_perp guarded by { "primitive": "zscore_above", "params": {
  "market": "<M>", "period": 20, "threshold": 0 } }. Defaults period 20 / enter −2σ / exit 0 — change only what the user states.

## Notes

The z-score uses the SAMPLE-stdev convention (`indicators.ts`), matching the pair spread z-score, and
returns `undefined` on short history — engine guards fail closed. Entry −2σ / exit 0 is the classic
revert-to-mean trade; the exit at the mean (not a symmetric +2σ) banks the reversion rather than betting on
an overshoot.
