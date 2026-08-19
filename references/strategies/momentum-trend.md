---
archetype: momentum_trend
triggers: long/buy while momentum is positive/rising and exit when it turns
  negative — momentum/trend-following on a Hyperliquid perp (or spot)
executor: live
gateBlock: momentum_above
capability:
  - perp
  - indicator
promptOrder: 40
defaults:
  period: 24
  thresholdPct: 0.02
---

- MOMENTUM / TREND ("long ETH while momentum is positive, close when it turns negative"): a symmetric pair —
  entry gated by momentum_above, exit gated by momentum_below. On a Hyperliquid perp: open_long_perp (user's
  collateral + leverage) guarded by { "primitive": "momentum_above", "params": { "market": "<M>", "period": 24,
  "thresholdPct": 0.02 } } and a close_perp guarded by { "primitive": "momentum_below", "params": { "market":
  "<M>", "period": 24, "thresholdPct": 0 } }. Defaults period 24 / enter +2% / exit 0 — change only what the user states.

## Notes

Momentum is simple percent change over `period` candles (`indicators.ts`), with an `undefined` sentinel on
short data — the engine guard treats that as false (fail-closed). The pair is symmetric by design: enter on
`momentum_above`, exit on `momentum_below` at 0, so a strategy is never long into a confirmed downtrend.
Default period 24 on 1h candles ≈ one day of trend.
