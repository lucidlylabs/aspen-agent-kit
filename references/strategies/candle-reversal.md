---
archetype: candle_reversal
triggers: flip long/short each candle by candle colour (e.g. 'trade 15m BTC
  candles, long if the last candle was red, short if it was green') — a
  per-candle reversal, optionally with outcome-scaled (martingale) sizing
executor: live
gateBlock: candle_close_red
capability:
  - perp
  - indicator
promptOrder: 55
grounding:
  - candle_reversal
defaults:
  interval: 15m
  leverage: 1
  basePct: 0.1
  times: 96
---

- PER-CANDLE REVERSAL / FLIP (user wants to flip long↔short on each new candle by the candle's COLOUR — e.g.
  "trade 15 minute BTC candles: if the last candle was red go long, if green go short", "flip on every candle",
  "reverse each 15m bar"): add a TOP-LEVEL "candleReversal" object and emit NOTHING else in `nodes`/`guards` — the
  system builds the entire flip topology (a reduce-only flatten + a long + a short, the candle_close_red/green
  guards, sizing) in CODE. Shape:
    "candleReversal": {
      "market": "<symbol, e.g. BTC>",
      "interval": "<candle size, default 15m>",
      "leverage": <number, default 1>,
      "takeProfitPct": <percent, optional — e.g. 5>,
      "stopLossPct": <percent, optional — e.g. 5>,
      "bankroll": <the up-front USD to fund the strategy wallet with — REQUIRED, a concrete number>,
      "basePct": <starting per-trade size as a FRACTION of live equity, default 0.1 = 10% — also the size a loss
                  resets to>,
      "sizing": <OPTIONAL — only when the user asks to GROW the size on a win streak ("double on each win", "parlay",
                 "let it ride", "compound my winners", "increase after every win until I lose"). Shape:
                 { "mode": "compound" (double each consecutive win: 10→20→40…) | "step" (add basePct each win:
                 10→20→30…), "capPct": <max fraction of equity to stop growing at, e.g. 0.6 — OMIT if the user
                 hasn't said, the system will ASK>, "winRule": "profit" (any close in profit = a win) | "tp" (only a
                 take-profit fill = a win) — OMIT if the user hasn't said, the system will ASK }. Emit "sizing" with
                 just "mode" if the user described the growth but not the cap/win-rule; the system asks the rest.>
    }
  Because `nodes` must be non-empty in the schema, emit ONE throwaway placeholder node
  (`{ "id": "_", "primitive": "close_perp", "params": { "market": "<symbol>" } }`) and NO guards — grounding
  discards it and supplies the real flip. RED candle → go LONG, GREEN candle → go SHORT (red = a down bar you
  fade by buying; green = an up bar you fade by selling). TP/SL apply to every trade and the system inverts them
  for the short automatically. `times` bounds the number of flips (default 96 ≈ one day of 15m candles).
- MONEY-PATH (never your job): do NOT compute per-trade collateral, do NOT pick which side opens, do NOT assemble
  the close-before-open sequence — all of that is code. You ONLY translate the user's words into the knobs above.
  If the user describes win-streak / parlay sizing ("10% to start, double on each win until I lose, then reset"),
  set basePct to the start size and emit "sizing" with the "mode" (compound vs step). If they ALSO stated a cap or a
  win-definition, fill "capPct"/"winRule"; otherwise LEAVE THEM OUT — the system asks the user for them. When the
  system's follow-up answer comes back ("cap at 60%", "count any profitable close as a win"), map it: a max-% →
  "capPct" (0.6), "any profitable close" → "winRule":"profit", "only when TP fills" → "winRule":"tp". Always ask for
  the `bankroll` (the up-front USD) if they didn't state one — never invent it.

## Notes

The flip topology, sizing, and close-before-open sequencing are built by `groundCandleReversal`
(`compose/candleReversal.ts`), never by the LLM — the same money-path-in-code discipline as `funding_arb`
and `basket_hedge`. The signal is the `candle_close_red`/`candle_close_green` condition primitives
(`indicator` capability): edge-triggered per candle boundary (fires once when a NEW candle closes the given
colour), fail-closed on a missing feed / no completed candle. The opens are RECURRING (bounded by `times` —
no unbounded spend). Per-trade size is `basePct × bankroll`; the `bankroll` is the fund-tx (the money-path
literal and the hard spend ceiling) and is gated against the user's transcript (never an invented amount).
**⚠ The win/loss "double on a win, reset on a loss" auto-scaling (`winPct`) is NOT yet wired into the engine**
(docs/reverse-hardening-spec.md §D5-L3, a follow-up) — the strategy deploys at the FIXED base size and a
warning surfaces that on the card, so the martingale is never a silent drop. The funding-bridge and
repatriation legs auto-attach as usual.
