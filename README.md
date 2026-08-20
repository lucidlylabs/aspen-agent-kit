# Aspen Agent Kit

Quantitative trading knowledge for AI agents, distilled from
[Aspen](https://useaspen.ai) — an agent harness for agentic trading.

Install it as a skill and your agent (Claude Code, Cursor, Codex, or anything that reads the
[agentskills.io](https://agentskills.io) format) gains working knowledge of **perpetual futures** and
**prediction markets** — not just how to connect to them, but how to trade them.

```
"where do I get historical funding data for hyperliquid?"
"is a 15-minute mean reversion strategy on ETH viable at my fee tier?"
"what does RSI actually tell me, and does it work?"
"how much should I size this, and where does it liquidate?"
"why is my backtest better than my live results?"
```

## What this is

**Not a replacement for the venues' own docs or SDKs.** Hyperliquid, Lighter and Polymarket each
maintain their own API documentation, and Lighter ships its own
[official agent kit](https://github.com/elliottech/lighter-agent-kit). Those are always more current
than a third-party copy.

This kit is **the layer above that** — what a platform never documents about itself:

| | What it covers |
|---|---|
| **Data** | Where market data actually comes from: live feeds, historical archives, what the archives *don't* contain, and how to build the datasets you have to record yourself |
| **Reading data** | Bars and what they destroy, why time bars are a poor default, returns, stationarity, labelling |
| **Indicators** | The full toolkit — trend, momentum, volatility, volume and flow, microstructure, funding/basis/OI, prediction-market signals — each **graded A–D against the research literature** |
| **Strategies** | Eight archetypes as specifications: mechanism, entry, exit, sizing, fee sensitivity, failure modes |
| **Fees** | All three venues' schedules, and — more importantly — how fee structure decides which strategies are viable at all |
| **Risk** | Position sizing, liquidation math, portfolio limits, and the operational controls that must exist in code |
| **Validation** | Backtesting that rejects rather than confirms; deflated Sharpe; why strategies fail live |
| **Failure modes** | A catalogue of what actually goes wrong — the arithmetic gates, the research artifacts that fabricate edge, the execution bugs that get you picked off |

The goal: **an agent with this kit should be a competent quantitative trader on these venues**, not
merely connected to them.

## Venues covered

| Category | Venues |
|---|---|
| **Perpetual futures** | Hyperliquid (incl. HIP-3 builder markets and native spot), Lighter, Polymarket Perps |
| **Prediction markets** | Polymarket, Hyperliquid HIP-4 outcome markets |

## Grounded in the literature

The quant section is built on published research rather than folklore, and says so explicitly —
including where the evidence is *against* a popular technique. Kyle (1985) and Glosten–Milgrom (1985)
on why spreads exist; Almgren–Chriss (2000) on execution; Avellaneda–Stoikov (2008) on market making;
Jegadeesh–Titman (1993) and Moskowitz–Ooi–Pedersen (2012) on momentum; Sullivan–Timmermann–White
(1999) on why most technical trading results do not survive data-snooping correction;
Bailey–López de Prado on the deflated Sharpe ratio; Thaler–Ziemba (1988) and Wolfers–Zitzewitz (2004)
on prediction markets. Full bibliography in
[references/quant/references.md](references/quant/references.md).

## Installation

```bash
git clone https://github.com/lucidlylabs/aspen-agent-kit.git
cd aspen-agent-kit && ./install.sh
```

Manual — the repo *is* the skill:

```bash
ln -s "$(pwd)" ~/.claude/skills/aspen-agent-kit    # Claude Code
ln -s "$(pwd)" ~/.cursor/skills/aspen-agent-kit    # Cursor
ln -s "$(pwd)" ~/.codex/skills/aspen-agent-kit     # Codex
```

**Pair it with the venues' own kits.** For execution on Lighter, install
[elliottech/lighter-agent-kit](https://github.com/elliottech/lighter-agent-kit) alongside this one —
it owns the money path (including paper trading against live order books) while this kit covers what
to do with it.

## Repository structure

```
├── SKILL.md                          # agent entry point, routing, safety rules
├── references/
│   ├── CATALOG.md                    # generated index of all 41 cards
│   ├── card-format.md                # frontmatter & conventions
│   ├── perpetuals/                   # Hyperliquid, Lighter — venue, data, fees, risk
│   ├── prediction-markets/           # Polymarket, HIP-4 — venue, data, fees, risk
│   └── quant/
│       ├── data/                     # reading, sourcing, validating market data
│       ├── indicators/               # the graded indicator toolkit
│       ├── strategies/               # archetypes as specifications
│       ├── execution/                # order placement and slippage
│       ├── risk/                     # sizing and operational control
│       ├── validation/               # backtesting and performance evaluation
│       └── references.md             # bibliography
├── scripts/build-catalog.mjs
├── install.sh
├── DISCLAIMER.md
└── LICENSE
```

## Principles

- **The kit is knowledge, not keys.** No signer, no API client, no addresses, no market ids. Your
  agent executes through whatever tooling you give it and resolves live identifiers itself. Stale
  addresses in a doc are how funds get lost.
- **Official docs are the source of truth for mechanics.** Every venue card links them and defers to
  them. All three publish an `llms.txt` index and serve raw Markdown at `<page>.md`.
- **Costs before signals.** Most strategies die on arithmetic, not on prediction. The kit computes the
  arithmetic first.
- **Honest about evidence.** Where a popular technique is not supported, the card says so and cites
  why.

## Contributing

Cards are the source of truth; the catalog is generated.

```bash
node scripts/build-catalog.mjs
```

## Disclaimer

**Trading is risky. Orders, borrows and withdrawals are irreversible.** This kit is documentation, not
financial advice, and it can be wrong or stale — verify against the venue's official docs before
moving funds. See [DISCLAIMER.md](DISCLAIMER.md).

## License

[MIT](LICENSE)
