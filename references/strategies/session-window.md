---
archetype: session_window
triggers: hold a position only during a wall-clock window and be flat outside it — "long BTC
  only between 13:00 and 21:00 UTC", "trade the US session and close before the close",
  "only during London hours", "flat overnight", "session-only hold"
executor: live
# NOT `time_of_day_between`: it is an ALWAYS-ON core primitive, so gating on it would inject this guidance
# into every prompt — including a swap-only catalog with no `open_long_perp` for the guidance to emit. Same
# trap the DCA card documents; the existing prompt-assembly test catches it. Gate on the perp block the
# recipe actually emits.
gateBlock: open_long_perp
capability:
  - perp
  - indicator
# Between DCA (75) and risk-parity (80). Both neighbours are unrelated shapes, so the tie-break never
# matters here — but the number is stated rather than defaulted so a rename cannot reshuffle the prompt.
promptOrder: 78
defaults:
  leverage: 1
  times: 30
---

- SESSION WINDOW ("long BTC only between 13:00 and 21:00 UTC", "only trade the US session", "flat
  overnight", "close before the daily close"): the user wants exposure INSIDE a wall-clock window and
  nothing outside it. Ask ONE thing if they haven't said it — is this a ONE-SHOT (the next session only)
  or does it REPEAT DAILY — because the two graphs are different and the difference is what they signed
  for.

  ONE-SHOT — enter during the next window, exit when it ends. Two plain guards, no recurrence:
    open  n1:  time_of_day_between { startHourUtc, endHourUtc }
    close n2:  not[ time_of_day_between { startHourUtc, endHourUtc } ]

  DAILY — re-enter every day. Use `daily_at`, an ABSOLUTE wall-clock alarm. TWO guards, nothing else:
    open  n1:  daily_at { hourUtc: <start>, times: N }
    close n2:  daily_at { hourUtc: <end>, times: N }

  · Use `daily_at`, NOT `every_interval { interval: "1d" }`. `every_interval` measures 24 hours FROM ITS
    FIRST FIRE, so it locks to whatever time the strategy was deployed: deploy "13:00–21:00 daily" at
    20:00 and every_interval fires at 20:00 forever, turning an 8-hour session into a 1-hour one. It looks
    correct on the card and is wrong every day after. `daily_at` is pinned to the clock, so 13 means 13:00
    whoever deploys it whenever.
  · Do NOT add an ordering guard to the close — the system attaches it. A recurring close alarm is due at
    deploy, before its open has ever fired, so code adds `not[position_closed]` as a gate
    (`attachRecurringCloseOrdering`). MONEY-PATH: not your job, and adding your own only duplicates it.
  · `times` is REQUIRED and must be BOUNDED (same rule as DCA). Take it from the user's own horizon
    ("for two weeks" → 14); if they give none, PROPOSE a number and say it out loud, because
    `collateral` is committed up front for the whole run.
  · A take-profit / stop-loss is ADDITIVE: add the price guards to the same close node as ordinary
    (non-gate) guards and the position leaves on whichever happens first.
  · Hours are 0–23 UTC. Say the window back to the user in UTC even if they said it in another zone — the
    graph has no timezone. A window that WRAPS past midnight is fine here (open 22, close 2) because the
    two alarms are independent; only the one-shot form needs `time_of_day_between`'s wrap handling.

## What it is

A time-of-day hold: be long (or short) only inside a session, flat outside it. The common ask is the US
afternoon (13:00–21:00 UTC) on a 24/7 crypto perp — a way to avoid holding through thin overnight hours
without predicting anything about price.

## Notes

Both halves of the daily shape are ordinary primitives; nothing here is grounded in code. What makes it
expressible is the guard-level `gate` flag: `precondition` on a PRIMITIVE means "gate everywhere"
(`funds_on_hypercore` is never a trigger in any graph), but `time_of_day_between` is a perfectly good
trigger on its own — the one-shot shape above uses it as exactly that. Whether it is a trigger or a
window is a property of the guard in this graph, which is why the flag lives on the guard.

The checker refuses a node whose guards are ALL gates (`all-gates-no-trigger`): a gate can only hold an
action, so such a node can never run, and the runtime failure is invisible — no error, no fire, no log,
indistinguishable from "the condition hasn't happened yet".

`daily_at` is edge-triggered per UTC day, the same machinery `candle_close_red` uses per candle: a stateful
reader (`daily_tick_value`) records the day index it last fired for, so the alarm rings once and not for the
rest of the hour.

The close's ordering gate is CODE (`attachRecurringCloseOrdering`), not guidance, and the reason is empirical:
this card originally instructed the model to emit it and called it mandatory, and the very next composer run
omitted it. The cost was not cosmetic — the deploy-day close spends one of the close node's `times`, so the
budgets fall out of step and the LAST session opens and never closes. Same discipline as the funding bridge:
anything that decides whether a position gets closed belongs in code.

The BACKTEST replays it the same way the engine runs it, which is how the `every_interval` mistake above was
caught: the card reported seven ONE-HOUR trades for a strategy whose author believed it held for eight, and
the numbers were right — the graph really did behave that way. The funding-bridge and repatriation legs
auto-attach as usual.
