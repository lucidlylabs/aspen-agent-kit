---
archetype: cross_asset_lag_catchup
triggers: trade asset B expecting it to "catch up" after asset A (a correlated leader) has
  already moved — "lag trade", "catch-up trade", "X always follows Y with a delay"
executor: live
gateBlock: momentum_above
capability:
  - perp
  - indicator
  - statarb
promptOrder: 72
defaults:
  period: 24
  interval: 1h
  thresholdPct: 0.02
  leverage: 1
---

- CROSS-ASSET LAG / CATCH-UP TRADE ("SOL always follows BTC with a delay — buy SOL after BTC moves", "lag
  trade", "catch-up trade", "X follows Y"): the user names a LEADER and a LAGGARD. The position is opened on the
  LAGGARD; the trigger reads the LEADER. Getting that pairing backwards produces a plain momentum trade on the
  wrong asset, so state it back to the user explicitly ("buying SOL when BTC has run +2% over 24h").
    · open node: open_long_perp { "market": "<LAGGARD>", "collateral": <user's amount>, "leverage": <lev> }
    · entry guard: momentum_above { "market": "<LEADER>", "period": <N>, "interval": "<candle>",
      "thresholdPct": <move size as a FRACTION — 0.02 means 2%, never 2> } → do "<open id>". The `market` on the
      GUARD is the LEADER and the `market` on the NODE is the LAGGARD — they are deliberately different, and
      that difference IS the strategy.
    · exit: REQUIRED. Default to a close_perp on the laggard guarded by momentum_below { "market": "<LEADER>",
      "period": <N>, "interval": "<candle>", "thresholdPct": 0 } — the catch-up thesis is dead once the leader's
      move is gone. A user-stated take-profit / stop-loss on the LAGGARD is equally good; use theirs when given.
  · DOWNSIDE variant (the leader has fallen and the laggard hasn't yet): open_short_perp on the laggard gated by
    momentum_below on the leader with a NEGATIVE thresholdPct, exiting on momentum_above at 0.
  · Defaults: period 24, interval "1h", thresholdPct 0.02 (= 2% — the param is a fraction), leverage 1. A "big
    move" with no number stated is 2% over 24h — say the number you used, since it decides when this fires.
  · Do NOT emit a second position on the leader. This trade holds the laggard only; a leg on both assets is a
    pair trade (`pair_stat_arb`, which trades the spread REVERTING) and is a different strategy with different
    risk. If the user wants both legs, use that archetype instead.

## What it is

Two correlated assets where one historically moves first and the other tends to follow — enter the laggard once
the leader has moved but the laggard hasn't caught up. Distinct from `pair_stat_arb` / `zscore_mean_reversion`
on a pair: those trade REVERSION of a stable ratio back to its mean; this trades CONTINUATION — a bet the
laggard still has a move coming, not that a spread will close.

## Notes

Both ingredients are live. `momentum_above` / `momentum_below` are ordinary indicator guards over the shared
candle feed, and nothing in them requires the guard's market to match the node's — reading one asset to act on
another has always been expressible, which is what makes this a prompt change rather than a new primitive. Both
fail closed on a missing feed or short history, so a leader with no candles never fires the laggard's entry.

Correlation between the two is NOT asserted at compose time. The user is claiming the relationship; the card
takes their word and states it back rather than silently validating it. `correlation_value` exists as a reader
if a user wants the entry gated on the relationship still holding — offer it when they ask, as an `all(...)`
around the momentum guard.

## Non-goals

- **No lead-lag calibration.** Nothing measures whether the laggard actually follows the leader, or by how many
  periods. There is no cross-correlation-at-lag-k primitive, so the LAG ITSELF is not modelled — the trade fires
  as soon as the leader's move clears the threshold, not after a fitted delay. If the user asks "how long is the
  lag", say plainly that it is their assumption, not something measured here.
- **No automatic laggard selection.** The user names both assets. There is no scan for "which asset hasn't
  caught up yet" — that is closer to `slot_rotation`'s ranking shape.
