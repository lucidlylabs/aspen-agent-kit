---
module: scanner
instrument: The scanning method — all venues
venue: cross
triggers: how to look for a trade at all — "give me ideas", "any opportunities", "what should
  I trade", "suggest something", "scan the markets", "find me something", "what looks good
  right now", "combined strategy across venues", "which market should I pick"
---

# The scanning method

Aspen trades four instruments: **Hyperliquid perpetual futures**, **Hyperliquid spot**, **HIP-4 outcome
markets**, and **Polymarket prediction markets**. Each has its own module with the mechanics and the screens
that fit it. This card is the method that governs all four.

## An opportunity is a priced disagreement you can name

A market price is a consensus estimate. An opportunity exists only when you can say, in one sentence, **what
the price implies** and **why that is wrong or is about to pay you**.

Three answers are legitimate, and they exhaust the space:

1. **Carry** — the position is paid to exist: a recurring payment from the other side (perp funding), or
   convergence to a known value on a known date. Needs no forecast, only survival.
2. **Convergence** — two prices that must eventually be equal are not. Needs no direction call.
3. **Direction** — an outright view. The weakest, because the whole payoff rests on a forecast, and that
   forecast needs a stated edge.

If a candidate fits none of the three, it is not an opportunity. It is a position.

## The four questions

Most candidates die at question 2, which is where they should die — before sizing.

1. **What does the price imply?** Turn the quote into a claim about the world. Funding of +0.01%/hr implies
   longs pay ~0.24%/day. A market at 0.30 implies a 30% chance. Until it is a sentence, it cannot be disagreed
   with.
2. **Why is it wrong, or why does it pay?** Name the mechanism. "A crowded long is paying to stay long" is a
   mechanism. "The market is underpricing this" is a hope — it says neither who is mispricing nor why they
   persist. **Nothing reaches question 3 without a mechanism.**
3. **What does it cost to hold?** Fees in and out, funding while held, spread crossed twice, slippage against
   depth — measured over the intended holding period. 40bp harvested daily is superb; 40bp captured once a
   month after 18bp of costs is not worth the risk. The modules carry the real figures.
4. **What kills it?** Name the event that turns this into a loss, and whether the strategy exits before it. If
   the answer is "a big move against me", it is naked direction and should be sized that way.

## Scan, never browse

The venue tools return a **volume-ranked** list when called without a query. That is global attention, not
relevance: it returns the same handful of markets to every user regardless of what they trade. A market that
arrives from a query-less browse **has not been selected; it has merely appeared.**

Query by the asset, event or theme actually under discussion, then screen the survivors on **room to move**
(not already at an extreme), **depth against the intended ticket**, **a horizon that fits**, and **a stated
mechanism**. Per-instrument thresholds live in the modules.

Two failure signatures, each meaning the scan step was skipped: **one market appearing in several ideas** (it
was chosen for none of them), and **an unrelated instrument bolted onto a working position** (a second, separate
bet wearing one wrapper — it hedges nothing).

## Combining instruments

Two instruments belong in one strategy only when a shared underlying variable links them. Before going
further, state:

1. **The sign** — if this event resolves YES, or this rate moves, which way does the other leg go?
2. **The mechanism** — why that is causal, not a correlation someone noticed once.

If the sign cannot be named, there is no combination. Two positions with independent payoffs are not a hedge:
they can lose together, and the pair is worse than either alone. "Buy YES on a geopolitical market and short
BTC" fails — that sign is not established in either direction.

Combinations that hold up, strongest first:

- **Prediction market as signal, Hyperliquid as position.** The event market gates an ordinary perp or spot
  leg; no capital on the prediction venue at all. Cleanest by a distance — prefer it unless the user
  specifically wants exposure on both sides.
- **Same event, two venues.** HIP-4 and Polymarket both listing one question: YES on the cheaper plus NO on
  the dearer for a combined cost under 1.00 pays exactly 1.00 on one leg. Use resting limits summing below 1,
  and equal contract counts.
- **Threshold market against the perp.** A market on "<asset> above <strike> on <date>" and the perp price the
  same variable, so a gap in implied probability is convergence, not a forecast.
- **Spot against perp.** Long spot, short perp: delta-neutral, collects funding. See the perps and spot
  modules.
- **Carry plus its own break-risk.** A funding carry hedged with the binary on the event that would break
  *that* carry. Any other event is the bolt-on above.

## Engine constraints on a combined strategy

Execution limits, not preferences. A graph violating one refuses at deploy or stalls after it.

- **One venue acts per tick.** The executor refuses a tick batching Hyperliquid signed actions with prediction
  actions, and holds. Two unguarded entry legs therefore fire together on tick one and the strategy never
  executes. Sequence them: one leg opens, the other is guarded on the first leg's state. Exits too — one
  trigger fanned to a leg on each venue reproduces the stall.
- **No vault-chain EVM leg** in a graph reaching a prediction venue on another chain; the burner lives on the
  venue's chain, so that leg would execute on the wrong one.
- **One cross-chain destination** per strategy. Two means two strategies.
- **Hub funding is unavailable** to a mixed graph — one strategy records one hub relationship; it funds from
  the vault.
- **Prediction symbols name the outcome** — `<slug>:<outcome-index>` on Polymarket, `<selector>:YES` / `:NO` on
  HIP-4. An outcome-less symbol is refused.

## Presenting what you found

Each idea names a **different** market unless you say why one carries two. Lead with the mechanism, then the
instrument. State the holding cost and the thing that kills it — an idea without its failure mode is
incomplete. Never invent the money-path numbers: entry amount and leverage come from the user.
