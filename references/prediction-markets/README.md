---
section: prediction-markets
title: Prediction markets
venues: [polymarket, hyperliquid-hip4]
triggers: >-
  prediction market, bet on an outcome, buy YES, buy NO, event contract,
  polymarket, HIP-4 outcome market, probability, resolution, redeem
---

# Prediction markets

## What they are, from first principles

A prediction market turns a question about the world into a contract that pays **$1 if the event
happens and $0 if it does not**. Because the payoff is fixed, the price *is* the market's probability
estimate: a share at $0.30 is the market saying "about 30%".

That single property changes everything relative to a perp:

- **There is no leverage and no liquidation.** Positions are fully collateralized. Maximum loss is
  what you paid.
- **The price is bounded in [0,1] and terminates.** It does not drift; it converges to 0 or 1 on a
  known date. Time is not neutral — it is the dominant force late in a market's life.
- **YES and NO are the same instrument.** Buying YES at *p* is economically identical to selling NO
  at *1−p*. A full set of YES + NO always equals $1, which is why you can mint and redeem sets
  against collateral.
- **The risk that kills you is resolution, not price.** A position can be correct about the world and
  still lose because the market resolved on a technicality, a source disagreed, or the rules were
  clarified after you entered.

## Official documentation

| Venue | Docs | Machine-readable | API / SDK |
|---|---|---|---|
| Polymarket | https://docs.polymarket.com | https://docs.polymarket.com/llms.txt — every page has a `.md` twin | docs → **API Reference**; official unified TypeScript and Python SDKs |
| Hyperliquid HIP-4 | https://hyperliquid.gitbook.io/hyperliquid-docs | `llms.txt`; `.md` twins | docs → **HIPs → HIP-4**, and **For developers → API** |

As with the perp venues, every mechanical claim in this section should be checked against those, and
anything time-varying — fee rates, tick sizes, market ids, quote tokens — read live.

## The two venues

| | Polymarket | Hyperliquid HIP-4 |
|---|---|---|
| Model | Off-chain CLOB, on-chain settlement | On-chain-adjacent L1 order book |
| Position tokens | ERC-1155 conditional tokens (CTF), distinct id per outcome | Yes/No sides on a merged book |
| Collateral | pUSD | per-market quote token — **read it, do not assume** |
| Fees | Taker only, `C × rate × p × (1−p)`, category-dependent, geopolitics free | **Charged only on close/settle — opening is free** |
| Resolution | UMA optimistic oracle, dispute window, DVM escalation | Builder-operated settlement |
| Breadth | Very large; the deepest event-market venue | Newer, narrower, includes recurring dated instruments |
| Extras | Neg-risk multi-outcome events, combos, perps on the same collateral | Sits alongside perps on one connection |

Polymarket is the venue with real breadth and real liquidity. HIP-4 matters if you are already on
Hyperliquid and want event exposure without a second custody surface, or want to trade the same
question across two venues.

## What is in this section

- **[polymarket.md](polymarket.md)** — structure, trading mechanics, and the resolution risk that
  defines the venue.
- **[polymarket-data.md](polymarket-data.md)** — the API surfaces, the on-chain data stack, and the
  calibration datasets that make prediction markets researchable.
- **[hip4.md](hip4.md)** — outcome markets on Hyperliquid.
- **[fees.md](fees.md)** — the `p(1−p)` fee curve and why it structurally taxes longshots.
- **[risk-controls.md](risk-controls.md)** — resolution risk, concentration, and controls specific to
  binary payoffs.

For how to actually *trade* these — pricing, edge, calibration, sizing on binary payoffs — go to
[../quant/](../quant/README.md), especially
[../quant/strategies/prediction-markets.md](../quant/strategies/prediction-markets.md) and
[../quant/indicators/prediction-markets.md](../quant/indicators/prediction-markets.md).
