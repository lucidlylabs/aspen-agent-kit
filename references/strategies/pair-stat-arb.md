---
archetype: pair_stat_arb
triggers: long one asset / short another when their spread is unusually cheap
  and unwind both as it reverts — 2-leg pair (statistical-arbitrage) trade on
  Hyperliquid perps
executor: live
gateBlock: spread_zscore_below
capability:
  - perp
  - statarb
promptOrder: 70
defaults:
  period: 60
  enter: -2
  exit: 0
---

- PAIR / STAT-ARB ("long ETH / short BTC when their spread z-score(60) ≤ −2, close both when it reverts"): TWO legs
  (open_long_perp on asset A + open_short_perp on asset B, each with the user's per-leg collateral + leverage) and
  TWO close_perp exits. The entry (spread_zscore_below, params { "marketA": "<A>", "marketB": "<B>", "period": 60,
  "threshold": -2 }) is REPLICATED as a guard pointing at BOTH opens; the exit (spread_zscore_above, threshold 0) is
  replicated pointing at BOTH closes. (Optional extra exit: pair_correlation_below, threshold 0.5, if the pair
  decorrelates.) Defaults period 60 / enter −2σ / exit 0 — change only what the user states.

## Notes

`spreadZScore` (`pairIndicators.ts`) is the primary pair signal — same sample-stdev convention as the
single-asset z-score; OLS `hedgeRatio` and `pearson` correlation are available from the same module. The
entry guard is REPLICATED onto both opens (and the exit onto both closes) so the legs can never half-enter.
Candle series are inner-joined on `closeMs` (`alignClosesByTime`) before any pair math runs.
