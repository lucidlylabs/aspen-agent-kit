---
title: Card format
triggers: card format, frontmatter, how are cards structured, schema
---

# Card format

Every card is Markdown with YAML frontmatter. The schema is deliberately small.

## Frontmatter fields

```yaml
---
section: perpetuals          # perpetuals | prediction-markets | quant
group: indicators            # (quant only) data | indicators | strategies | execution | risk | validation
title: Volatility indicators # human-readable name, used in the catalog
venue: hyperliquid           # (venue cards only) the venue this describes
kind: data-sourcing          # (optional) data-sourcing | economics | risk
docs: https://…              # (venue cards) the official documentation this card defers to
type: carry                  # (strategy cards) carry | convergence | direction | short-volatility | liquidity-provision | mixed
triggers: >-
  natural-language phrases that should route a question to this card
---
```

`triggers` is the routing surface: it is what an agent matches a user's question against. Everything
else is organisational.

## The three sections

**`references/perpetuals/`** and **`references/prediction-markets/`** — venue knowledge. One card per
venue, plus a `-data.md` card for its data surfaces, plus shared `fees.md` and `risk-controls.md` for
the section.

These cards are **deliberately thin on API surface.** The venues document their own endpoints better
than any copy of them could, and Lighter ships its own agent kit. Each venue card opens with a table
of official documentation links and covers only what the docs do not: what bites, what it costs, what
you have to build yourself, and what must be verified live.

**`references/quant/`** — venue-independent trading knowledge, grouped:

| Group | Contents |
|---|---|
| `data/` | Reading market data, where to source it, how to validate it |
| `indicators/` | The indicator toolkit, graded against the research literature |
| `strategies/` | Strategy archetypes as specifications |
| `execution/` | Order types, slippage, getting filled |
| `risk/` | Position sizing, limits, operational controls |
| `validation/` | Backtesting, performance evaluation |

## Conventions that carry meaning

- **No addresses, no market ids, no contract addresses.** Anywhere. Resolve every identifier from the
  venue at time of use. This is enforceable and should stay enforced.
- **Fee tables and rate schedules are snapshots**, always accompanied by an instruction to verify.
  They are there so an agent can reason about magnitude, not so it can quote them as current.
- **Indicator cards carry an evidence grade** (A/B/C/D) with the reasoning and a citation. See
  [quant/indicators/README.md](quant/indicators/README.md#evidence-grading).
- **Strategy cards always state the mechanism first** — who is on the other side and why they stay —
  then entry, exit, sizing, and failure modes. A card without a mechanism is not a strategy.
- **"Must be code, never judgment"** marks decisions that must be deterministic and covered by tests
  asserting the failure case. These are never delegated to a model at runtime.

## Adding or editing a card

Cards are the source of truth; the catalog is generated.

```bash
node scripts/build-catalog.mjs
```

Keep `triggers` phrased the way a user would actually ask, not the way a taxonomy would file it.
