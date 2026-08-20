---
section: quant
title: Quantitative trading — the method
triggers: >-
  how do I trade this, find me a trade, is this strategy any good, build a
  systematic strategy, what should I trade, quant, backtest, edge, indicators
---

# Quantitative trading

This section is the part of the kit that is not about any venue. It is what you need to know to turn
a data feed into a decision that has positive expected value after costs — and, just as often, to
recognise that a plausible-sounding idea does not.

The venue sections tell you *how the market works*. This tells you *how to trade it*.

## The honest frame

Most systematic trading ideas lose money. They lose money for a small number of repeated reasons, and
almost all of them are visible before deployment:

1. **The edge was never there** — it was noise that looked like signal because it was found by
   searching many hypotheses against one dataset.
2. **The edge was there but is smaller than the costs** — the strategy is real and unprofitable.
3. **The edge was there historically and has been arbitraged away** — you found it in a paper, so did
   everyone else.
4. **The backtest was wrong** — look-ahead, survivorship, unrealistic fills, or a bug that reads the
   future by one bar.
5. **The risk was mis-sized** — correct edge, correct costs, position large enough that ordinary
   variance ended the account before the edge paid.

The discipline in this section is organised around catching each of those before money moves. That is
the actual job. Signal generation is the fun part and the smallest part.

## What counts as an opportunity

A price is a consensus estimate. An opportunity exists only when you can say, in one sentence, **what
the price implies** and **why that is wrong or why it pays you anyway**.

Three answers are legitimate, and they exhaust the space:

1. **Carry** — the position is paid to exist. Perp funding, or convergence to a known value on a known
   date. Needs no forecast, only survival. The most robust category for a small account, because its
   economics are dominated by holding, not by turnover.
2. **Convergence** — two prices that must eventually be equal are not. Needs no direction call.
3. **Direction** — an outright view. The weakest, because the entire payoff rests on a forecast, and
   that forecast needs a stated source of edge.

If a candidate fits none of the three, it is not an opportunity. It is a position.

## The four questions

Most candidates die at question 2. That is where they should die — before sizing.

1. **What does the price imply?** Turn the quote into a claim about the world. Funding at +0.01%/hr
   implies longs pay ~0.24%/day. A contract at 0.30 implies a 30% chance. Until it is a sentence, it
   cannot be disagreed with.
2. **Why is it wrong, or why does it pay?** Name the mechanism. "A crowded long is paying to stay
   long" is a mechanism. "The market is underpricing this" is a hope — it names neither who is
   mispricing nor why they persist. **Nothing reaches question 3 without a mechanism.**
3. **What does it cost to hold?** Fees in and out, funding while held, spread crossed twice, slippage
   against real depth — over the intended holding period. 40bp harvested daily is superb; 40bp
   captured monthly after 18bp of costs is not worth the risk.
4. **What kills it?** Name the event that turns this into a loss, and whether the strategy exits
   before it. If the answer is "a big move against me", it is naked direction and should be sized
   that way.

## The order of work

Do it in this order. Each step can kill the idea, and the early steps are cheap.

```
   mechanism  →  data  →  cost model  →  signal  →  backtest  →  sizing  →  paper  →  live small
```

Reversing it — starting from an indicator and searching for a market it works on — is how you
manufacture overfitting. The indicator is the last thing you choose, not the first.

## How to read this section

**Start here if you are learning:**
1. [data/reading-market-data.md](data/reading-market-data.md) — what a price series actually is
2. [indicators/README.md](indicators/README.md) — what indicators can and cannot tell you
3. [execution/order-placement.md](execution/order-placement.md) — how orders really fill
4. [risk/position-sizing.md](risk/position-sizing.md) — how much to bet
5. [validation/backtesting.md](validation/backtesting.md) — how to not fool yourself
6. [failure-modes.md](failure-modes.md) — what goes wrong, and how to see it coming

**Directory map:**

| Path | What it covers |
|---|---|
| [data/](data/) | Reading market data, where to get it, how to clean it |
| [indicators/](indicators/) | The full indicator toolkit, evidence-graded, plus crypto-native and prediction-market signals |
| [strategies/](strategies/) | Strategy archetypes as specifications: entry, exit, sizing, failure modes |
| [execution/](execution/) | Getting filled at a price you modelled |
| [risk/](risk/) | Sizing and portfolio-level control |
| [validation/](validation/) | Backtesting, and evaluating whether a result is real |
| [failure-modes.md](failure-modes.md) | **What actually goes wrong** — the catalogue of ways strategies die, with the numbers that decide it |
| [references.md](references.md) | The literature this section is built on |

## Combining instruments across venues

Two instruments belong in one strategy only when a shared underlying variable links them. Before
going further, state:

1. **The sign** — if this event resolves YES, or this rate moves, which way does the other leg go?
2. **The mechanism** — why that is causal, not a correlation someone noticed once.

If the sign cannot be named, there is no combination. Two positions with independent payoffs are not
a hedge: they can lose together, and the pair is worse than either alone.

Combinations that hold up, strongest first:

- **Prediction market as signal, perp as position.** The event market gates a perp leg; no capital on
  the prediction venue at all. Cleanest by a distance.
- **Same event, two venues.** A question listed on both Polymarket and HIP-4: YES on the cheaper plus
  NO on the dearer for a combined cost below 1.00 pays exactly 1.00 on one leg.
- **Threshold market against the perp.** A market on "asset above X on date D" and the perp price the
  same variable, so a gap in implied probability is convergence, not a forecast.
- **Spot against perp.** Long spot, short perp: delta-neutral, collects funding.
- **Carry plus its own break-risk.** A funding carry hedged with the binary on the event that would
  break *that* carry. Any other event is a second bet wearing one wrapper.

## Non-negotiables

- **The user sizes the trade.** Entry amounts and leverage come from the user. Offer defaults; never
  assume them.
- **Never invent a number.** Fee rates, decimals, market ids, depth, funding — read them live. A
  fabricated parameter is a total-loss class of bug.
- **State costs before deploying, not after.** If a strategy pays X% per day in fees regardless of
  whether it wins, say so plainly and let the user decide. This is a warning, never a refusal.
- **Simulate first.** Paper trade where the venue offers it. Lighter's official kit simulates against
  live books; use it.
- **An idea without its failure mode is incomplete.** Always name what kills it.
