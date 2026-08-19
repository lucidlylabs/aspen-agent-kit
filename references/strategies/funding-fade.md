---
archetype: funding_fade
triggers: take whichever side of a perp COLLECTS the funding payment when funding is
  extreme — "farm funding on ETH", "get paid the funding rate", "short what longs are
  paying through the nose for", "collect funding while it's rich"
executor: live
gateBlock: funding_above_for
capability:
  - perp
  - statarb
promptOrder: 85
---

- FUNDING FADE — DIRECTIONAL ("collect the funding on X", "get paid to hold", "short the coin longs are paying
  through the nose for", "farm funding while it's rich"): take the side that RECEIVES funding, gated on the rate
  having stayed extreme for a SUSTAINED window rather than one instant. Emit ONE direction, not both.
  · Funding strongly POSITIVE (longs pay shorts) ⇒ SHORT to collect: open_short_perp guarded by
    funding_above_for { "market": "<M>", "threshold": 0.0001, "duration": "4h" }.
  · Funding strongly NEGATIVE (shorts pay longs) ⇒ LONG to collect: open_long_perp guarded by
    funding_below_for { "market": "<M>", "threshold": -0.0001, "duration": "4h" }.
  · EXIT when the carry stops paying: close_perp guarded by the OPPOSITE sustained condition at threshold 0 —
    a short exits on funding_below_for { "threshold": 0, "duration": "1h" }, a long on funding_above_for.
  · Pick the direction from the user's OWN words ("short what longs are paying" ⇒ the short shape). If they
    only say "collect funding on ETH" without naming a side, ASK which regime they mean, or state plainly which
    side you chose and why — do NOT emit both directions on the same market.
  · Thresholds are PER-INTERVAL rates, not annualised: 0.0001 = 1bp per funding interval. Defaults above are a
    starting point; use the user's numbers when they give them.

## What it is

The directional cousin of `funding_arb`. Both harvest funding, but they are different trades and must not be
confused:

- **`funding_arb`** is CROSS-DEX and DELTA-NEUTRAL — long one venue's rep of an asset, short another's, net
  price exposure ≈ 0, income is the funding SPREAD. Direction is decided in code from live funding.
- **This** is SINGLE-market and DIRECTIONAL — you hold real price risk and are paid to hold it. If funding is
  +1bp/interval you earn roughly 1% a month for being short, and lose far more than that if the market runs.

Fading a funding extreme is a bet that the crowded side is exhausted. It pays a small, steady carry and
occasionally loses a lot at once, so the sustained-window gate matters: entering on a single funding print
catches noise, and the position it opens is directional.

## Notes

`funding_above_for` / `funding_below_for` are TIME-SUSTAINED gates — every sample in the trailing window must
satisfy the threshold, not just the latest. Partial history (a new market, a gap) FAILS CLOSED: the guard stays
false until a full window confirms. That is what stops a freshly listed market from triggering an entry off two
data points.

Funding is an ORACLE READ (`metaAndAssetCtxs`), never modelled.

⚠ Emit ONE direction. A long and a short on the same market survive `checkCoherence` when they hang off
different triggers, but nothing sequences them, so the burner can end up holding both at once — the
`checkUnsequencedReversal` warning exists for exactly this shape. The two sustained conditions are mutually
exclusive in principle (funding cannot be sustained-above and sustained-below at the same time), but "in
principle" is not a guarantee worth a live position.

## Non-goals

- No automatic direction pick from live funding. `funding_arb` does that in code because a sign error there
  silently pays the carry on a hedged book; here the direction IS the trade and the user should own it.
- No sizing off funding magnitude. Position size is the user's, stated and signed for on the card.
