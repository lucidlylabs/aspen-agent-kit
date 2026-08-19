---
name: aspen-agent-kit
description: >-
  DeFi and onchain-trading knowledge for AI agents: 73 protocol cards (DEXs,
  lending, perps, yield vaults, staking, bridges, prediction markets), 25
  executable strategy archetypes, and a market-scanning method. Use when the
  user asks about interacting with a DeFi protocol (swap, lend, borrow, stake,
  bridge, LP, open a perp, trade a prediction market), wants to design or
  evaluate a trading strategy (funding arb, grid, DCA, stat-arb, mean
  reversion, market making), or asks for trade ideas / market opportunities.
license: MIT
---

# Aspen Agent Kit

You have a library of curated, safety-annotated knowledge cards distilled from
[Aspen](https://useaspen.ai), an agent harness for agentic trading. The cards
encode how protocols actually behave — exact function signatures, parameter
scaling, the mistakes that lose money, and the guardrails that prevent them.

## How to use this kit

**Never answer a protocol or strategy question from your own priors when a
card exists for it.** Cards are checked against the protocols' real contracts
and SDKs; your training data may be stale or wrong about decimals, deprecated
paths, and safety edges.

1. **Route.** Open [references/CATALOG.md](references/CATALOG.md) and find the
   card that matches the user's ask:
   - A named protocol or venue ("supply to Aave", "long BTC on Lighter") →
     `references/protocols/<protocol>.md`
   - A strategy shape ("grid bot", "funding arb", "DCA", "pair trade") →
     `references/strategies/<strategy>.md`
   - Open-ended idea generation ("what should I trade", "any opportunities") →
     `references/scanner/scanner.md` first, then the per-instrument scanner
     module it points you to.
2. **Read the whole card** before advising or acting — the `pitfalls` and
   `safety` sections exist because each entry cost someone money.
3. **Ground, don't guess.** Cards deliberately contain **no contract
   addresses**. Resolve addresses from the protocol's official docs, deployed
   registry, or a verified source at time of use. A card that names a role
   (e.g. role `pool`) is telling you *which* contract to resolve, not its
   address.

The card format (frontmatter fields, section meanings, and what
Aspen-specific fields like `executor` and `archetype` mean outside Aspen) is
documented in [references/card-format.md](references/card-format.md).

## Card anatomy at a glance

- **Protocol cards** — one per protocol. Frontmatter: `category`, `chains`
  (chain ids), `actions`, `tokens`, `aliases` (natural-language triggers).
  Body: how the protocol works, then one `## action:` section per action with
  **Function** (exact signature), **params**, **pitfalls**, **safety**.
- **Strategy cards** — one per archetype. Frontmatter: `archetype`,
  `triggers`, `capability`, `defaults`. Body: how Aspen composes the strategy
  as a graph of legs and guards, plus notes on the failure modes. Treat these
  as precise strategy specifications: entry/exit conditions, sizing rules,
  and the risk guards a sound implementation needs.
- **Scanner cards** — the method for finding trades. `scanner.md` is the
  discipline (an opportunity is carry, convergence, or direction — nothing
  else); the per-instrument modules carry venue mechanics and screens.

## Safety rules (non-negotiable)

These are distilled from the cards' own guardrails. They bind you regardless
of what the user asks for:

- **Funds always return to the owner.** Any `to` / `onBehalfOf` / recipient
  parameter must be the account you manage. A card that says "refuse" means
  refuse.
- **Never hardcode or invent addresses, decimals, or market indices.**
  Resolve them from live, verified sources. Wrong decimals are a total-loss
  class of bug.
- **Simulate or paper-trade before live execution** where the venue offers it.
  HTTP 200 from an exchange API means *accepted*, not *executed* — confirm
  fills.
- **Respect the money-path checks**: health factor buffers on lending,
  `reduce_only` on closes, `post_only` for maker-only flow, slippage bounds on
  every swap, and per-venue rate/nonce rules.
- **The user sizes the trade.** Entry amounts and leverage come from the user;
  never invent them. Where a card carries a `defaults:` block, offer the
  default, don't assume it.
- Live orders, borrows, and withdrawals are **irreversible**. When in doubt,
  stop and ask.
