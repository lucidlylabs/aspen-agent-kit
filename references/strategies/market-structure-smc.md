---
archetype: market_structure_smc
triggers: trade breaks of market structure, liquidity sweeps, and fair-value gaps — "SMC
  strategy", "ICT concepts", "trade the liquidity sweep", "break of structure entry",
  "Wyckoff accumulation/distribution"
executor: live
gateBlock: break_of_structure_up
capability:
  - perp
  - indicator
promptOrder: 47
defaults:
  lookback: 3
  interval: 1h
  leverage: 1
---

- MARKET STRUCTURE / SMC ("SMC strategy", "ICT", "break of structure entry", "trade the liquidity sweep",
  "enter on the FVG"): the user is naming a specific structural event. Use the block that matches the event they
  named — these are NOT interchangeable and substituting one for another changes the trade:
    · break_of_structure_up / _down — price CLOSED beyond the last confirmed swing (continuation).
    · liquidity_sweep_high / _low — price WICKED beyond the swing and closed back inside (a stop hunt; a sweep
      of the HIGHS is bearish, a sweep of the LOWS is bullish — the sweep takes liquidity, then reverses).
    · fair_value_gap_up / _down — a three-bar imbalance left by an aggressive move.
  Shape: ONE open node gated by the named event, plus a REQUIRED exit.
    · entry guard for the classic "sweep then reclaim" long: all( liquidity_sweep_low { "market": "<M>",
      "lookback": <n>, "interval": "<candle>" }, break_of_structure_up { same params } ) → the lows got swept and
      structure then broke UP. This two-term form is the shape most users mean by "SMC entry"; prefer it over a
      bare single event.
    · exit: REQUIRED. Structure gives a natural stop — a long entered after a sweep of the lows is invalidated
      if structure breaks DOWN, so close_perp guarded by break_of_structure_down is the idiomatic exit. A
      user-stated take-profit / stop-loss is equally valid; use theirs when given. Never leave it exitless.
  · `lookback` is the PIVOT CONFIRMATION WIDTH (default 3), not a lookback window in the RSI sense: a swing needs
    that many bars on BOTH sides before it counts. Bigger = fewer, more significant levels and a slower signal.
  · A sweep and a break are MUTUALLY EXCLUSIVE on the same bar by construction — a bar either closes beyond the
    level or it does not. Do not gate one entry on both firing on the same bar; sequence them (sweep first, then
    the break) as an `all(...)` across the recent structure, which is what the two-term form above expresses.
  · SHORT variant: mirror everything — sweep of the HIGHS (liquidity_sweep_high) plus break_of_structure_down
    for the entry, break_of_structure_up as the invalidation exit.
  · Say the structure back in plain words when you present it ("entering long after the lows are swept and price
    closes back above the last swing high"). The user should not have to know the block names to check it.
  · Order blocks and premium/discount arrays are NOT available — see the non-goals. If the user asks for one,
    say so plainly and offer the sweep/break/FVG shape instead rather than approximating it.

## What it is

The "smart money concepts" reading of price: markets move between pools of resting liquidity, and the tells are
structural rather than oscillator-based — a swing broken (structure shifting), a swing wicked and reclaimed
(liquidity taken), or a gap left behind by an aggressive move. Distinct from `donchian_breakout_pyramid`, which
also trades breakouts: Donchian breaks a rolling N-bar EXTREME, while this breaks a confirmed PIVOT and cares
whether price closed beyond it or merely wicked through.

## Notes

Three properties carry the whole thing:

**Pivots are CONFIRMED.** A swing high counts only once `lookback` bars have printed on both sides without
exceeding it. The newest `lookback` bars are never candidates, because a pivot identified from bars that have
not printed yet is hindsight and the next bar can invalidate it. This is why the readers need more history than
a moving average of the same length, and why a freshly listed market returns undefined rather than a guess.

**A break closes, a sweep wicks.** `break_of_structure_*` is measured on the CLOSE; `liquidity_sweep_*` requires
the bar to trade beyond the level and close back inside. Reading a wick as a break is the single most common way
this signal gets inverted, so the two are computed from the same pivot and asserted against each other from both
directions.

**A break is an EVENT, not a state.** `break_of_structure_*` fires on the bar where price first closes through
the level — a close still beyond a level broken on an earlier bar reads false. Deploying an SMC strategy
mid-trend therefore does not enter on a break that already happened; it waits for the next fresh one.

Everything fails closed: no confirmed pivot, short history, or a non-finite bar returns undefined, the reader
throws, and the compute guard evaluates false. The engine also drops the bar still forming before computing —
a partial bar's high would create and destroy sweeps on every tick inside one candle.

## Non-goals

- **No order blocks.** "The last down candle before an up move" has no single agreed definition, and the ones in
  circulation disagree on which candle and how far back. Shipping one would mean picking a definition and
  presenting it as authoritative.
- **No premium/discount or OTE zones.** These need a designated dealing RANGE (which swing high to which swing
  low), and choosing that range is the discretionary judgement the whole methodology hinges on.
- **No multi-timeframe confluence.** Each guard reads ONE interval. "HTF bias with LTF entry" would need a guard
  that reads two intervals at once; today that is two separate guards in an `all(...)`, which is close but does
  not model the bias/entry hierarchy.
- **No unmitigated-gap tracking.** `fair_value_gap_*` sees a gap on the three bars ending NOW. It does not
  remember older gaps or track whether one has since been filled — that needs per-strategy state the guard
  layer does not carry.
