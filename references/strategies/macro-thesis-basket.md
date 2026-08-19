---
archetype: macro_thesis_basket
triggers: hold a preset multi-asset basket keyed to ONE macro narrative and rotate/resize as
  the thesis plays out — "risk-off basket", "recovery basket", "war escalation trade",
  "play <macro theme> across a few coins"
executor: live
gateBlock: portfolio_pnl_below
capability:
  - perp
  - statarb
promptOrder: 15
defaults:
  leverage: 1
---

- MACRO-THESIS BASKET ("risk-off basket", "recovery basket", "play the debasement trade", "position for a macro
  shock across a few coins"): the user names a NARRATIVE and wants several positions that express it. Your job
  is to translate the narrative into NAMED LEGS and say why each one is there — that translation is the entire
  value of this archetype, and it must be visible on the card, never implied.
    · legs: one open_long_perp or open_short_perp per asset, each with its own collateral and leverage. A
      thesis usually has BOTH directions (long what benefits, short what suffers); emit shorts only if the
      narrative actually implies them.
    · whole-book exit: REQUIRED — a portfolio_pnl_above (take-profit) and a portfolio_pnl_below (stop-loss)
      guard pointing at EACH close_perp leg. A thesis basket is one position expressed in parts, so it is exited
      as a whole, not leg by leg.
  · NAME EVERY LEG AND ITS ROLE, in your reply and in the strategy name: "long PAXG (gold — the defensive leg),
    short SOL (high-beta risk asset)". The user is signing for a view; they can only check it if they can see
    which assets you chose and why you say each expresses the thesis.
  · ⚠ EMIT NO TOP-LEVEL DIRECTIVE OBJECT. No "relStrength", no "riskParity", no "hedge" — a macro basket is
    PLAIN legs plus portfolio guards, and every collateral is a real number you computed from the user's budget,
    never a placeholder for a grounding pass to size. Emitting `relStrength` hands leg sizing to a MOMENTUM RANK,
    which silently converts the user's stated thesis into "hold whatever has been going up lately". That is a
    different strategy, and it is the specific failure this card exists to prevent — see the Notes.
  · DO NOT SUBSTITUTE A RANKING RULE FOR A THESIS. Picking the top-N by momentum or volatility is
    `slot_rotation` / `relative_strength_rotation` — those choose assets by a MEASURED property, which is a
    different strategy from a stated macro view, and presenting one as the other gives the user a basket they
    did not ask for under a name they did. If you cannot name the legs the thesis implies, say so and ask.
  · A RISK-OFF BASKET IS NOT ALL-LONG. "Risk-off" means rotating OUT of high-beta assets; a basket that is long
    gold AND long BTC is long two risk assets, one of which is the thing being de-risked from. If the thesis
    implies something should fall, short it or leave it out — do not include it long and call the basket
    defensive.
  · SPLIT THE BUDGET EXPLICITLY. Divide the user's stated total across the legs and say the split out loud
    ("$800: $400 long PAXG, $200 short SOL, $200 short AVAX"). Weight by conviction if the user expressed any;
    otherwise split evenly and say that is what you did.
  · ASK WHEN THE NARRATIVE IS THIN. "Risk-off" implies defensives over high-beta and is workable. A specific
    event ("if the election goes X"), a named equity, or a macro instrument Aspen cannot trade is NOT — say
    what is unavailable rather than reaching for the nearest crypto proxy without flagging it.
  · If the user wants the basket HEDGED to net-zero market exposure rather than directional, that is
    `market_neutral_basket` — it sizes the short legs by measured beta in code. Use this archetype only when the
    user wants a directional expression of a view.

## What it is

A view, expressed across several assets at once. "Risk-off" is long defensives and short high-beta; "debasement"
is long hard assets. The basket exists because a single ticker rarely expresses a macro idea cleanly and because
spreading it reduces the chance that one asset's idiosyncratic news decides whether the view paid.

## Notes

No new primitive was needed and none was added: the legs are ordinary perp opens and the exit is the same
whole-book `portfolio_pnl_*` pair `market_neutral_basket` uses. What was missing was never math — it was the
translation from a narrative to a set of tickers, and that is agent knowledge, stated and confirmed on the card
like every other agent-owned decision (the 2026-07-31 policy).

⚠ THERE IS DELIBERATELY NO CURATED NARRATIVE→ASSET MAP. Shipping one would mean Aspen asserting, in code, that
a given set of tokens IS the risk-off trade — an investment view that no test can validate, that goes stale as
markets change, and that the user could not see or argue with. The agent proposing the legs and the user reading
them on the card is both more honest and more flexible. The cost is that leg choice is model judgement, which is
exactly why the guidance forces every leg to be named and justified before it can be signed.

The failure this card exists to prevent is on record: asked for a risk-off basket, the composer previously
emitted a `ranks_top_k` basket picking the top 2 of PAXG/ETH/BTC by MOMENTUM and titled it "Risk-off Rotation
Basket" — a momentum rotation wearing a macro label, including two high-beta assets a risk-off view would short.

## Non-goals

- **No rotation as the thesis evolves.** The card's trigger says "rotate/resize as the thesis plays out" and
  that half is NOT implemented. Nothing tracks a thesis's state or stage, so the basket is static once deployed:
  it opens, it runs, it exits on the whole-book guards. Say that plainly rather than implying it will adapt.
- **No macro instruments.** No rates, FX, equity indices or commodities beyond what trades as a perp or a
  tokenised asset on the supported venues. Gold via PAXG is a proxy for gold, not gold.
- **No event triggers.** There is no primitive for "if the election goes this way" or "on the next CPI print".
  A thesis basket opens when deployed; it cannot wait for a news event.
- **No beta hedging.** Legs are sized as stated, not to net out market exposure — that is
  `market_neutral_basket`, whose short sizing is code-owned precisely because betas are not eyeballable.
