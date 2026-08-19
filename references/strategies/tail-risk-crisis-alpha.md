---
archetype: tail_risk_crisis_alpha
triggers: a mostly-dormant hedge that only enters when a cross-asset stress signal fires,
  sized for asymmetric payoff in a crash — "tail hedge", "crisis alpha", "black swan hedge",
  "convex protection against a crash"
executor: live
gateBlock: compute
capability:
  - perp
  - compute
promptOrder: 95
defaults:
  fearThreshold: 20
  correlationThreshold: 0.9
  period: 30
  interval: 1h
  leverage: 2
---

- TAIL HEDGE / CRISIS ALPHA ("tail hedge", "black swan protection", "crisis alpha", "something that only kicks
  in when everything breaks"): a position that stays DORMANT and opens only when a cross-asset stress signal
  fires. The whole strategy is the trigger — emit ONE short and gate it on a `compute` guard combining
  sentiment with correlation, because either signal alone is noise:
    · open node: open_short_perp { "market": "<M>", "collateral": <user's amount>, "leverage": <lev> }
    · entry guard: compute with a formula over TWO readers — `fear_greed_value` (market-wide sentiment, 0–100)
      and `correlation_value` (the cross-asset term). `"market"` in the guard's params is REQUIRED and must
      equal the short's market — the checker hard-rejects a compute guard gating a market-scoped node without
      it (`compute-missing-market`). Shape:
        "when": { "primitive": "compute", "params": { "market": "<M>",
          "formula": "fg < <fearThreshold> && corr > <corrThreshold>" },
          "computeInputs": {
            "fg":   { "kind": "read", "primitive": "fear_greed_value", "params": {} },
            "corr": { "kind": "read", "primitive": "correlation_value",
                      "params": { "marketA": "<M>", "marketB": "BTC", "period": <N>, "interval": "<candle>" } } } }
    · REFERENCE ASSET: `marketB` is the market-wide leg, BTC by default. If the short's market IS BTC,
      corr(BTC, BTC) is identically 1 — the correlation term is vacuously true and the "two-signal" gate
      silently degrades to sentiment-only, the exact shape the WHY-BOTH-TERMS note below forbids. For a BTC
      hedge use `marketB: "ETH"` instead, and say so ("correlation of BTC to ETH, since BTC is the hedge").
    · exit: REQUIRED. A tail hedge that never closes is just a permanent short paying funding forever. Close on
      the stress PASSING — a compute guard with the inverted formula (`fg > 40 || corr < 0.7`), carrying the
      same `"market": "<M>"` param — or on a user-stated take-profit. Say which you used.
  · WHY BOTH TERMS: extreme fear alone is common and often marks a bottom; correlation spiking toward 1 is what
    says diversification has stopped working, which is the actual crisis regime. Gating on sentiment alone
    produces a short that fires in every ordinary drawdown.
  · Defaults: fear < 20, correlation > 0.9, period 30, interval "1h", leverage 2. Use the user's numbers when
    given. Say the thresholds out loud — they decide how often this fires, and "rarely" is the point.
  · SIZE IS FLAT AND STATED. Take the user's amount as the whole commitment. Do NOT scale it by how extreme the
    signal is, and do not describe the position as convex — see the non-goal below. If the user asks for a
    small premium that pays off big, tell them plainly what this actually is: a leveraged short that opens on a
    stress trigger.
  · This is a HEDGE, not an overlay. It does not know about the user's other positions and does not size against
    them; if they want it sized against a book, that number is theirs to state.

## What it is

A mostly-dormant position that only opens under cross-asset stress, intended to pay off when everything else is
falling. The classic framing is "cheap insurance most of the time, large payoff rarely" — the honest version
here is a short that stays flat until sentiment and correlation both hit crisis levels.

## Notes

Every ingredient is live: `compute` guards (docs/compute-node-spec.md) combine any two `reader` primitives by
formula, and both readers exist — `fear_greed_value` (the crypto Fear & Greed index, one shared 1h-cached fetch)
and `correlation_value` (Pearson over the shared candle feed).

Gate 3 was the blocker until 2026-08-11 and is now closed: `tick.ts` had always passed `deps.macroSignal`
through to the exec ctx, but nothing constructed it, so every `fear_greed_value` read threw "no macro-signal
port" and the guard was permanently false — the strategy would have deployed and never fired. `buildTickDeps`
now builds it. The adapter fails CLOSED on a fetch error, an HTTP error, an out-of-range value, or a cache past
its 6h stale bound, so a missing sentiment read still means the hedge does not open — it can never fire on
stale data.

## Non-goals

- **The payoff is NOT convex.** Real tail-risk strategies buy options: premium is capped, payoff is not. This
  has neither property — it is a linear short whose loss is unbounded if the market rallies into it, and it pays
  funding while it waits. There is no options venue and no convex sizing primitive, so do not sell it as
  insurance. This non-goal is the most important line on the card.
- **No volatility-scaled sizing.** Size does not grow with signal strength or shrink with realised vol. It is
  the flat amount the user stated and signed for.
- **No portfolio awareness.** It does not read the user's other positions, so it cannot hedge a specific book.
