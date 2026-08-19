---
archetype: session_open_drift
triggers: position ahead of a market's SESSION OPEN based on pre-open drift/volume and exit
  shortly after — "trade the open", "pre-market positioning", "session-open drift"
executor: live
gateBlock: relative_volume_above
capability:
  - perp
  - indicator
promptOrder: 79
defaults:
  interval: 15m
  period: 20
  driftPeriod: 4
  driftPct: 0.005
  multiple: 1.5
  leverage: 1
---

- SESSION-OPEN DRIFT ("trade the US open on ETH", "position on the pre-market drift and exit after the open",
  "session-open drift"): enter INSIDE a short window at the session open, in the direction the market already
  drifted BEFORE it, and be flat again shortly after. Three parts, all required:
    · open node: open_long_perp (or open_short_perp) { "market": "<M>", "collateral": <amount>, "leverage": <lev> }
    · entry guard: an `all(...)` of THREE terms — the window, the drift, and the participation check:
        1. time_of_day_between { "startHourUtc": <open>, "endHourUtc": <open + ~0.25> } — a SHORT window at the
           open, not the whole session.
        2. momentum_above { "market": "<M>", "period": <driftPeriod>, "interval": "<candle>",
           "thresholdPct": <driftPct — a FRACTION: 0.005 means 0.5%, never 0.5> } — the PRE-OPEN drift. Because
           the guard fires just after the open and momentum reads COMPLETED candles, `driftPeriod × interval` is
           exactly the pre-open stretch (4 × 15m = the hour before). For a SHORT, use momentum_below with a
           NEGATIVE thresholdPct.
        3. relative_volume_above { "market": "<M>", "period": <period>, "interval": "<candle>",
           "multiple": <multiple> } — the open is only tradeable if it came with real participation. Do NOT drop
           this term: a drift on thin volume is noise, and it is the whole reason this is not just a time window.
    · exit: REQUIRED, and it is a CLOCK exit — close_perp guarded by time_of_day_between covering a window
      shortly AFTER the open (default ~1h later). "Exit shortly after the open" is the strategy; a position that
      survives the session is a different trade. Add a user-stated take-profit / stop-loss as extra guards on the
      same close node if they ask — it then leaves on whichever comes first.
  · Hours are 0–23 UTC and may be fractional (13.5 = 13:30). The US equity open (9:30 ET) is 13:30 UTC in US
    summer (EDT) and 14:30 UTC in winter (EST); say the window back in UTC, and say which session you assumed.
  · Defaults: interval "15m", drift over 4 bars ≥ 0.5% (driftPct 0.005 — the param is a fraction), volume ≥
    1.5x the 20-bar average, leverage 1. State the numbers you used — they decide whether this fires at all.
  · ⚠ EMIT EXACTLY ONE DIRECTION. Do NOT emit a long AND a short "so it works either way" — the drift is not
    known at compose time, but a graph that opens both sides on the same trigger is a straddle that pays two
    spreads and holds no view. The checker refuses it outright. If the user has not named a direction, pick the
    one their words imply and SAY which you chose ("long, entering only if the pre-open hour drifted up ≥0.5%"),
    or ask them — never hedge by emitting both.
  · Direction comes from the DRIFT, not from a view. If the user names a direction, use theirs and say the drift
    term now only confirms it.

## What it is

The open is when overnight information gets repriced: a market that has already drifted pre-open, on volume,
often continues briefly into the session. This holds for minutes-to-an-hour, keyed to the clock, and is flat
outside it. Distinct from `session_window` (hold for the WHOLE session with no signal): this enters only if the
drift and volume conditions are met, and exits shortly after the open rather than at the close.

## Notes

The drift term needed no new primitive — `momentum_*` already reads a different bar range than the guard fires
in, so "the move before the open" is just a lookback that lands in the pre-open bars. The missing half was
PARTICIPATION, and `relative_volume_above` / `relative_volume_below` (added 2026-08-11) close it: the last
completed bar's volume as a multiple of its recent baseline, with the measured bar excluded from its own
baseline so a surge cannot dilute the number it is judged against. Both fail closed on short history, and a
zero baseline returns undefined rather than Infinity — a market with no prior volume never reads as a surge.

Volume is a genuinely new signal in the catalog, and it is reusable well beyond this card: any breakout
archetype can now require that the break came with participation.

## Non-goals

- **No pre-market or futures data.** The drift is measured on the SAME market's own candles, not on a separate
  pre-market venue or an index future. For a 24/7 crypto perp there is no true "pre-market" — the window before
  the equity open is just quieter, which is what the volume term is for.
- **No opening-auction or gap logic.** There is no auction print and no overnight gap primitive; this reads a
  drift over bars, not a gap between a close and an open.
- **No session calendar.** Nothing knows about holidays or daylight-saving shifts. The user's hour is taken
  literally in UTC, so a summer/winter shift is theirs to state.
