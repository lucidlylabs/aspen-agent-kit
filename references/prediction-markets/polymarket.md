---
venue: polymarket
section: prediction-markets
title: Polymarket
surfaces: [prediction-clob, neg-risk, combos, perps, bridge]
docs: https://docs.polymarket.com
triggers: >-
  polymarket, buy yes, buy no, conditional tokens, CTF, neg risk, pUSD,
  redeem, merge, split, resolution, UMA oracle, combos
---

# Polymarket

## Official documentation

| What | Where |
|---|---|
| Docs home | https://docs.polymarket.com |
| Documentation index for agents | https://docs.polymarket.com/llms.txt — **use this**; every page has a `.md` twin |
| SDKs | docs → *Getting started* — official unified **TypeScript** and **Python** SDKs |
| API + WebSockets | docs → *API Reference* |
| Contracts & audits | docs → *Resources → Contracts* |
| Error codes | docs → *Resources → Error Codes* |

The unified SDKs replaced earlier per-service clients; if you find a tutorial using an older client,
check the migration page before copying it. **Do not hand-roll order signing** — the auth scheme has
several wallet-type variants and the SDK handles them.

## The data model

**Event → market → outcome.** An event groups related markets; a market is one tradable question;
each outcome (YES / NO) has its own **token id**. The token id is the unit of everything — prices,
books, orders, positions. Get it from market metadata and never construct it yourself.

## How trading actually works

It is a **hybrid** model, and the split matters:

- **Orders are off-chain.** You sign an order and POST it to the CLOB operator, which matches it and
  submits matched trades on-chain for atomic settlement. The operator never takes custody, never sets
  prices, and cannot move your funds. It can only match and sequence.
- **Position primitives are on-chain calls** you make yourself:
  - **split** — lock *X* pUSD, mint *X* YES + *X* NO.
  - **merge** — burn *X* YES + *X* NO, get *X* pUSD back. This is an exit that touches no order book:
    no spread, no slippage, no counterparty. Underused.
  - **redeem** — after resolution, winners pay $1 and losers $0.
  - **convert** — neg-risk only; turn 1 NO in one outcome into 1 YES in every other outcome.

Collateral is **pUSD**, an ERC-20 backed 1:1 by USDC. Older integrations referencing raw USDC.e are
out of date.

## The mechanics that cause most bugs

- **Two exchanges.** Standard markets settle on one exchange contract; multi-outcome **neg-risk**
  events settle on another. The flag must match the market or the order is mis-routed. Read it per
  market; never infer it.
- **Allowances are per-side.** Buying needs a pUSD approval to the settling exchange; selling needs
  the ERC-1155 conditional-token approval. Forgetting either fails at settlement, not at submission.
- **Tick size is per-market and can change mid-life.** There is a tick-size-change event on the market
  stream for exactly this reason. A price off the tick grid is rejected.
- **Minimum size is denominated in shares, not dollars.** Minimum spend is therefore
  `min_size × price` — the dollar minimum for a $0.05 share is twenty times smaller than for a $0.95
  share. A budget check written in dollars will pass and then be rejected.
- **Open orders reserve balance per market.** Additional orders in the same market are rejected once
  the reservation consumes the balance, even though "you have funds".
- **Some markets impose a matching delay** (notably crypto up/down and sports). An order **cannot be
  cancelled while pending in that window.** Any strategy that relies on fast cancellation must know
  which markets have it.
- **A partially filled order cannot be cancelled** — only the unfilled remainder.
- **Matching engine restarts** happen on a maintenance schedule and the venue documents a post-restart
  post-only mode. An unattended maker must handle it.

## Resolution risk is the real risk

This is the part that has no analogue in perps and the part that most costs money.

Markets resolve through **UMA's optimistic oracle**: a proposer posts an outcome with a bond, there is
a challenge window, and disputes escalate to a token-holder vote that takes days. Three consequences:

1. **Resolution is not instantaneous and not guaranteed to match reality.** It matches what the
   oracle process concludes. Those usually coincide. When they do not, being right about the world is
   worth nothing.
2. **Rules can be clarified after you enter.** Polymarket can publish clarifications that change a
   market's effective terms. Read the full resolution criteria before sizing, not the headline
   question — the question is marketing, the criteria are the contract.
3. **Not every resolution is $1/$0.** A 50-50 resolution pays $0.50 per token on both sides. "Too
   early" style resolutions can void. Read the actual outcome; do not assume binary.

The practical rule: **treat resolution as an external, non-deterministic event you do not control.**
An automated strategy should never assume it can exit at $1 the moment the event visibly happens.

## Neg-risk, combos, and perps

**Neg-risk** markets are multi-outcome events (an election with several candidates) where the outcomes
are mutually exclusive. They are capital-efficient — the convert primitive lets you express "not X"
without buying every other leg — but the exit and redemption paths differ from standard binaries, and
placeholder buckets like "Other" have definitions that shift as the field clarifies. If your
automation only implements the standard-binary lifecycle, restrict new positions to two-outcome
non-neg-risk markets and treat neg-risk as read-only.

**Combos** are multi-leg positions built from existing outcomes, priced through an RFQ flow rather
than a standing book.

**Polymarket Perps** run on the same pUSD collateral. See
[../perpetuals/fees.md](../perpetuals/fees.md) for their fee schedule. The interesting property is
that event exposure and perp exposure share a collateral pool, which makes event-gated directional
trades operationally simple — a shape discussed in
[../quant/strategies/prediction-markets.md](../quant/strategies/prediction-markets.md).

## What to verify live, every time

Token ids. Tick size. Neg-risk flag. Fee rate for the market's category. Minimum order size. Whether
the market has a matching delay. The full resolution criteria and the resolution source.
