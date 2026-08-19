# Card format

Every card is a Markdown file with YAML frontmatter. The cards were written
for the [Aspen](https://useaspen.ai) engine, so a few frontmatter fields refer
to Aspen internals; this file says exactly what each field means, and what to
do with the Aspen-specific ones when you are *not* running inside Aspen.

## Protocol cards (`references/protocols/`)

One card per protocol. Example frontmatter:

```yaml
---
protocol: aave-v3
category: credit          # dex | credit | yield | staking | perp | bridge | vault | prediction | options | other
chains: [1, 8453, 42161]  # EVM chain ids the card covers (1 = Ethereum, 8453 = Base, 42161 = Arbitrum, …)
archetype: lend_borrow    # the interaction family this protocol belongs to
executor: knowledge-only  # see below
aliases:                  # natural-language phrases that should route to this card
  - "supply USDC to aave"
roles: [pool]             # named contract roles the actions reference
actions: [supply, borrow, repay, withdraw]
tokens: [USDC, WETH]      # tokens the card's examples assume
---
```

Body structure:

- An intro: what the protocol is and its trust/settlement model, from first
  principles.
- One `## action: <name>` section per action, each with:
  - **Function** — the exact contract function or SDK call, with its full
    signature.
  - **Contract** — the *role* of the contract the call targets (e.g. role
    `pool`). Cards never carry addresses; resolve the role's address from the
    protocol's official docs or a verified registry at time of use.
  - **Use when** — the intent this action serves.
  - `### params` — every parameter, its scaling/decimals rules, and required
    values.
  - `### pitfalls` — the mistakes that revert or lose money. Read all of them.
  - `### safety` — the invariants and refusal rules. These are binding.

### Aspen-specific fields on protocol cards

- `executor: knowledge-only | live` — whether Aspen's engine has a live
  executor for this protocol. Outside Aspen this is purely informational; the
  card's knowledge is valid either way.
- `roles:` — Aspen resolves contract addresses from an onchain registry keyed
  by `category/protocol/role`. Outside Aspen, treat a role as "the contract
  the official docs call X", and resolve its address yourself.
- Mentions of **"the vault"** mean the account under management — the wallet
  or smart account whose funds the agent controls. Every recipient-style
  parameter must point back to it.

## Strategy cards (`references/strategies/`)

One card per strategy archetype. Example frontmatter:

```yaml
---
archetype: funding_arb    # canonical strategy id
triggers: farm the funding spread / delta-neutral funding trade…   # when this archetype applies
executor: live            # all 25 archetypes run live in Aspen
gateBlock: funding_carry_above   # the guard block that gates entry
capability: [perp, statarb]      # engine capabilities the strategy exercises
promptOrder: 20           # ordering hint when several cards are shown together
grounding: [funding_direction]   # live data reads the composer must perform first
defaults: { leverage: 3 } # defaults to OFFER the user, never to assume
refuse: …                 # asks this archetype must decline (only on some cards)
---
```

The body is the exact composition instruction Aspen's planner follows —
which legs to emit, which guards gate entry and exit, and what the engine
decides in code rather than letting an LLM choose (direction selection,
sizing symmetry, sign conventions). A `## Notes` section explains the
engineering reasoning.

**Outside Aspen**, read a strategy card as a precise specification:

- The *legs* are the positions/orders a sound implementation opens.
- The *guards* (`gateBlock`, exit guards like `portfolio_pnl_above/below`,
  `pair_basis_above`) are the entry/exit conditions and risk limits it needs.
- "Decided in code, never by the LLM" marks the decisions that must be
  deterministic — implement them as code with tests, not as model judgment.
- `defaults` are suggestions to surface to the user; sizing and leverage are
  always the user's call.

## Scanner cards (`references/scanner/`)

The method for finding trades rather than executing them.

```yaml
---
module: hyperliquid-perps
instrument: Hyperliquid perpetual futures
venue: hyperliquid        # or cross, for the method card
triggers: perp opportunities — funding rates, carry, basis…
---
```

`scanner.md` is the venue-independent discipline: what counts as an
opportunity (carry, convergence, or direction — nothing else), the four
questions every candidate must survive, and how instruments may be combined.
The per-instrument modules carry that venue's mechanics, screens, and real
cost figures. Always read `scanner.md` before a per-instrument module.

## Chain id reference

| id | chain | id | chain |
|---|---|---|---|
| 1 | Ethereum | 999 | HyperEVM |
| 10 | Optimism | 5000 | Mantle |
| 56 | BNB Chain | 8453 | Base |
| 130 | Unichain | 42161 | Arbitrum |
| 137 | Polygon | 43114 | Avalanche |
| 146 | Sonic | 747474 | Katana |
