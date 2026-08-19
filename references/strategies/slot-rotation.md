---
archetype: slot_rotation
triggers: watch a list of assets and hold only the best few at any moment, rotating as
  the ranking changes — "hold the top 2 of these ten", "rotate into whatever is
  strongest", "watch this list and trade the best one", "hold the calmest three"
executor: live
gateBlock: ranks_top_k
capability:
  - perp
  - indicator
promptOrder: 88
---

- SLOT ROTATION ("watch BTC/ETH/SOL/AVAX and hold the best 2", "rotate into whichever is strongest", "trade the
  top pick of this list", "hold the calmest three"): the user names a WATCHLIST and how many to hold at once.
  Emit ONE instanced open_long_perp node whose `instances` are the candidates and whose `slots` is the hold
  count, plus ONE ranks_top_k guard per instance:
    · node: { "id": "picks", "primitive": "open_long_perp", "slots": <K>, "instances": [ { "market": "<A>",
      "collateral": "<per-slot size>", "leverage": "<lev>" }, { "market": "<B>", ... } ] }
    · guard per instance i: ranks_top_k { "market": "<that instance's market>", "markets": "<A,B,C,...>",
      "k": <K>, "metric": "momentum", "period": 30 } → do "picks#<i>"
  · `collateral` is the PER-SLOT size, not the total. The system funds `slots × per-slot`, so a ten-name
    watchlist held two at a time funds TWO positions — say that number out loud when you present it.
  · `metric` is "momentum" (strongest first — the default) or "volatility" (CALMEST first, for "hold the
    steadiest"). Use the user's own words to pick; ask if genuinely ambiguous.
  · `markets` must list EVERY candidate, identically on every guard — it is the ranking universe, not that
    instance's own market.
  · Do NOT use this for a weighted basket where all legs are held (that is relative_strength_rotation or
    risk_parity_allweather). This one holds only K of N; the others hold all N with different sizes.

## What it is

The "scan and pick" shape: a fixed candidate list, a ranking rule, and a cap on how many positions are open at
once. Distinct from the weighted-basket archetypes in what it does with the losers — a basket holds them small,
a rotation does not hold them at all.

## Notes

Only WHICH candidates fire is decided at run time; every candidate is enumerated at compose time, so the graph
stays statically analysable and the spend stays bounded by `slots × per-slot size` rather than the candidate
count. That bound is what makes a ten-name watchlist fundable with one signature.

Ranking is code-owned and FAIL-CLOSED (`compose/slotRank.ts`): an unreadable candidate drops OUT of the ranking
rather than being ranked last (ranking it last on a guess would silently promote whatever sits above it into a
real position), and if fewer than K candidates are readable the guard stays false — no entry on a partial view
of the watchlist. Ties break on the user's own list order, so a rotation never churns the book on a coin flip.

## Non-goals

- **No automatic re-balance out of a loser.** v1 opens the top K; it does not close a position whose rank has
  since slipped. Pair it with an exit the user asks for (a stop, a trailing stop) rather than implying the
  rotation self-corrects.
- **No sizing by rank.** Every slot is the same size. Rank-weighted sizing is `relative_strength_rotation`.
