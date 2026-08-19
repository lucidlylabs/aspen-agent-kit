---
archetype: rsi_mean_reversion
triggers: long/buy when RSI is oversold (RSI(14) < 30) and exit when overbought
  (RSI > 70) — classic RSI mean-reversion on a Hyperliquid perp (or spot)
executor: live
gateBlock: rsi_below
capability:
  - perp
  - indicator
promptOrder: 30
defaults:
  period: 14
  oversold: 30
  overbought: 70
---

- RSI MEAN-REVERSION ("long ETH when RSI(14) < 30, close when RSI > 70" / "buy the dip on RSI oversold"): an entry
  action gated by rsi_below and an exit action gated by rsi_above. On a Hyperliquid perp: open_long_perp (user's
  collateral + leverage) with a guard { "when": { "primitive": "rsi_below", "params": { "market": "<M>", "period":
  14, "threshold": 30 } }, "do": "<open id>" }, and a close_perp with { "when": { "primitive": "rsi_above",
  "params": { "market": "<M>", "period": 14, "threshold": 70 } }, "do": "<close id>" }. Defaults 14 / 30 / 70 —
  change only what the user states. (Spot variant: swap_via_aggregator entry + close_via_aggregator exit, same guards.)

## Notes

RSI is Wilder-smoothed (`indicators.ts`), cross-verified against Binance to Δ0.4. The engine evaluates the
guards in `evalIndicatorGuard` (fetch → compute → compare, per-tick candle cache) — FAIL-CLOSED: no feed,
bad interval, or short history means the guard is false, never a blind fire. Price history routes per
market: HL `candleSnapshot` for in-universe markets, GeckoTerminal for Base tokens
(`priceFeed.resolveFeed`).
