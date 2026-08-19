---
archetype: perp_tp_sl
triggers: a Hyperliquid perp long/short with a take-profit and/or stop-loss
  (e.g. 'long ETH 3x, take profit 15%, stop loss 8%')
executor: live
gateBlock: open_long_perp
capability:
  - perp
  - indicator
promptOrder: 60
---

- PERP WITH TAKE-PROFIT / STOP-LOSS ("long ETH 3x, take profit 15%, stop loss 8%" / "short BTC $30, close at
  +20%"): when the user gives a take-profit and/or a stop-loss (a % or a price), you MUST include it — never
  drop a stated exit. A percentage means RETURN ON POSTED COLLATERAL, not a raw move in the market price.
  Divide it by leverage to derive the price move (`price move % = requested return % / leverage`). Emit the
  open (open_long_perp / open_short_perp with the user's collateral + leverage),
  a close_perp for the SAME market, and a price guard PER STATED exit pointing at the close_perp:
    · Let `p = tp% / leverage` and `s = sl% / leverage` (both remain percentages).
    · LONG:  take-profit → price_above { "token": "<market>", "threshold": "entry*<1+p/100>" };  stop-loss →
      price_below { "token": "<market>", "threshold": "entry*<1−s/100>" }.
    · SHORT (INVERT): take-profit → price_below { ... "entry*<1−p/100>" };  stop-loss → price_above { ... "entry*<1+s/100>" }.
  Use the literal keyword "entry" times the leverage-adjusted multiplier (at 5x, take profit 5% →
  "entry*1.01"; stop loss 0.5% → "entry*0.999"). Include ONLY the exits the user actually stated: if they
  mention NO take-profit and NO stop-loss, emit a BARE open (no close_perp, no price guard) — do NOT invent one. Never drop a stated exit,
  never add an unstated one. If the user NAMES a take-profit or stop-loss but gives NO level (no % and no
  price — e.g. just "take profit"), do NOT guess a threshold: emit a bare open, and the app prompts for the
  level (a guessed exit is a money-path guess — forbidden).
  · TRAILING / RATCHET EXIT ("let it run but lock in gains", "cut it fast if it fails but give a winner room",
    "at +20% lock a quarter of the gain, at +50% lock 60%"): a fixed price guard CANNOT express this — it
    compares against a level set now, and a ratchet depends on the best level the position has reached. Emit a
    trailing_stop guard pointing at the close_perp instead: { "market": "<market>", "tiers":
    "20:25,50:60,100:85" } where each rung is "<ROE% that arms it>:<% of the peak gain it locks>". For a plain
    "trail by N%" with no ladder, use { "market": "<market>", "retracePct": <N> }. Both may be set. Direction is
    derived from the open position — never state it. A trailing exit COMBINES with a fixed stop-loss: keep the
    user's stated stop as its own price guard, since the ratchet only engages once the trade is in profit.

## Notes

Stated exits become guard-triggered `close_perp` nodes — the amount gate covers guard-TRIGGERED entries
too, and the `"entry*X"` keyword is resolved by the engine at fill time, never a composed absolute price. A
perp open automatically gets BOTH funding legs attached as units: `attachFundingBridge` (Base→HyperCore,
prepended) and `attachRepatriation` (margin comes home, appended) — the user never says "bridge". The
exit-completeness aspect WARNS (never refuses) on a perp with no guard-triggered close.
