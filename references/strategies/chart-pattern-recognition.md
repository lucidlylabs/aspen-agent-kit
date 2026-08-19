---
archetype: chart_pattern_recognition
triggers: trade classic technical-analysis chart patterns — "head and shoulders", "triangle
  breakout", "flag pattern", "double top/bottom", "trade this chart pattern"
executor: live
refuse: "Chart patterns needing a FITTED TRENDLINE or a subjective anchor — triangles, wedges, channels, flags, pennants, cup-and-handle, rounding tops. Only double top/bottom and head-and-shoulders are detectable; the swing and gap blocks locate individual levels, not multi-bar geometry, and assembling them into one of these would assert a shape nobody detected."
gateBlock: double_top
capability:
  - perp
  - indicator
promptOrder: 49
defaults:
  lookback: 3
  interval: 4h
  leverage: 1
---

- CHART PATTERN ("short BTC on a head and shoulders", "trade the double bottom on ETH", "that double top
  looks ready"): FOUR patterns are detectable, and only four — `double_top`, `double_bottom`,
  `head_and_shoulders`, `inverse_head_and_shoulders`. Anything else the user names (triangle, wedge, flag,
  pennant, cup-and-handle) is NOT available; say so plainly and offer these instead of reaching for a
  lookalike built from breakout blocks.
    · open node: open_short_perp on a bearish pattern (double top / head-and-shoulders), open_long_perp on a
      bullish one (double bottom / inverse), with the user's amount + leverage.
    · entry guard: the matching condition, e.g. head_and_shoulders { "market": "<M>", "lookback": <n>,
      "interval": "<candle>" } → do "<open id>".
    · exit: REQUIRED. These signals say a structure completed, not how far price travels, so the exit is the
      user's take-profit / stop-loss (takeProfitPct + stopLossPct on the open node). If they give no numbers,
      propose them and say what you chose — there is no measured-move target block to fall back on.
  · EVERY PATTERN IS CONFIRMED-ONLY. The guard fires when the NECKLINE HAS ALREADY BROKEN — a close beyond the
    trough (or peak) between the two tops. It does NOT fire on a pattern that is "forming". Tell the user this
    when they ask for one, because it changes the trade: the entry is after the break, not at the top, and
    most candidate shapes never confirm and so never fire at all.
  · `lookback` is the PIVOT CONFIRMATION WIDTH (default 3), not a scan window. `interval` defaults to 4h —
    these are multi-swing structures and reading them on 1m bars finds noise. Optional `tolerance` (how level
    the two tops / shoulders must be) and `minDepth` / `minProminence` are available; leave them at the
    defaults unless the user asks for a looser or stricter shape, and say so if you change them.
  · DO NOT CLAIM A PATTERN EXISTS. You cannot see the chart. Never tell the user "there is a head and
    shoulders forming on BTC" — you have no way to know, and the detector runs at execution time, not now.
    Say what the strategy WILL DO ("it opens a short if a head-and-shoulders completes on the 4h"), which is
    both true and what they are signing for.

## What it is

The two classical reversal families whose definition is a set of level comparisons between confirmed swing
points: a double top/bottom (two extremes at a similar level, separated by a counter-move) and a
head-and-shoulders (three extremes, middle most extreme, outer two similar). Both complete when price closes
back through the neckline between them.

## Notes

Built on the confirmed-pivot machinery from the SMC work (`marketStructure.ts`), which is why this was cheap:
a chart pattern IS a relationship between swing points, so once pivots existed the patterns were level
arithmetic rather than image recognition. `swingPoints` returns the ordered run; the detectors read the last
3 (double top) or 5 (head-and-shoulders) and check the geometry.

CONFIRMATION IS THE WHOLE DESIGN (docs/chart-pattern-recognition-spec.md §1). Every detector requires the
latest completed bar to CLOSE beyond the neckline. Before that it returns 0 — checked and absent — not a
prediction. There is deliberately no "forming" variant: it would be a forecast wearing a detector's name.

The neckline is the LOWER of the two H&S troughs, not a fitted line through both. A sloped neckline needs a
slope, an extrapolation distance and a rule for steep cases; using the lower trough is strictly more
conservative and can be explained on a card.

Fail-closed throughout, and the two sentinels mean different things: `undefined` (too few pivots, short
history, a bad tolerance) makes the guard fail closed, while `0` means the detector ran and found nothing.

⚠ THESE DETECT GEOMETRY, NOT EDGE — AND THE EDGE CLAIM IS MEASURED, NOT ASSUMED. The harness the spec called
for exists (`patternStudy.ts`, run via `patternStudy.eval.ts`). Over ~833 days of BTC/ETH/SOL 4h candles the
patterns fire **too rarely to validate or refute**: no cell showed a demonstrated edge, and at the observed
sample sizes (n≈10-50 per pattern per market) the study could only have detected edges of ±16pp or more — far
larger than any realistic signal — so the honest reading is "unproven and currently unprovable", not "proven
worthless". The structural controls it runs alongside (break of structure, liquidity sweep) cleared no bar
either.

Head-and-shoulders is additionally too RARE to study: 0-5 distinct occurrences per market across 833 days, so
it never reaches a sample size that could support any verdict. A user asking for one should be told it may not
fire for months.

So: present these as "this shape has completed", never as "this shape means price will fall". The detectors are
correct; the claim that the shapes predict anything is unsupported by the only evidence we have.

## Non-goals

- **No fitted-trendline patterns.** Triangles, wedges and channels need a line through ≥2 pivots per side plus
  tolerances for convergence, touch count and flatness — four judgment calls, and a detector assembled from
  four judgment calls returns confident nonsense on ambiguous data. Still refused; see the `refuse:` line.
- **No flags or pennants.** They need a "pole" (a move of X% in Y bars) AND a counter-channel — two subjective
  definitions stacked.
- **No measured-move targets.** The textbook target (project the head's height below the neckline) is not
  emitted; exits are the user's stated TP/SL.
- **No volume confirmation.** `relative_volume_above` exists and can be added as an `all(...)` term if a user
  wants the break to come with participation, but it is not part of the pattern definition here.
