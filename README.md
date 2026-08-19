# Aspen Agent Kit

DeFi and onchain-trading knowledge for AI agents, distilled from
[Aspen](https://useaspen.ai) — an agent harness for agentic trading.

Install it as a skill and your agent (Claude Code, Cursor, Codex, or anything
that reads the [agentskills.io](https://agentskills.io) format) gains curated,
safety-annotated knowledge of **73 DeFi protocols**, **25 executable trading
strategy archetypes**, and a disciplined **market-scanning method** — the same
cards Aspen's own engine trades with.

```
"supply half my USDC to Aave and borrow WETH against it — what do I need to watch?"
"set up a delta-neutral funding trade on ETH"
"long BTC 10x on Lighter with a stop loss"
"what looks good right now on Hyperliquid?"
```

## What's inside

| | Count | Covers |
|---|---|---|
| **Protocol cards** | 73 | Exact function signatures, parameter scaling, pitfalls that lose money, and binding safety rules — per action, per protocol |
| **Strategy archetypes** | 25 | Entry/exit guards, sizing rules, and the decisions that must be code, not model judgment |
| **Scanner method** | 5 cards | What counts as an opportunity (carry, convergence, direction), the four questions that kill bad ideas, per-venue screens |

### Protocol coverage

| Category | Protocols |
|---|---|
| DEXs & swap aggregators (20) | Uniswap v2/v3/v4, Curve, Balancer v2, Aerodrome, Velodrome, PancakeSwap v2/v3, SushiSwap v2/v3, Camelot v3, 1inch, 0x, KyberSwap, Odos, Bebop, fly.trade, Sushi (XSwap), Hyperliquid spot |
| Yield & vaults (14) | Pendle v2, Ethena, Yearn, Convex, Aura, Sky sUSDS, Maker DSR, Syrup (Maple), Ondo USDY/OUSG, Mountain USDM, Origin Ether, Cap, Lucidly |
| Lending & credit (12) | Aave v3, Morpho Blue, Compound v3, Euler v2, Fluid, Spark, Venus, Moonwell, Radiant v2, crvUSD, LlamaLend, Liquity v2 |
| Staking & restaking (8) | Lido, Rocket Pool, ether.fi, Renzo, Kelp, Swell, Stader, Frax Ether |
| Perpetual futures (6) | Hyperliquid perps, Hyperliquid HIP-3 builder markets, Lighter, GMX v2, Gains Network, RiseX |
| Bridges & cross-chain (5) | Across, CCTP, Hyperlane, Stargate, Bungee |
| Prediction markets (3) | Polymarket (trading + signals), Hyperliquid HIP-4 outcome markets |
| Managed vaults (3) | Beefy, MetaMorpho, Morpho Vault v2 |
| Options & RWA (2) | Derive (options), Ondo tokenized stocks |

The full generated index — every protocol with its chains, actions and tokens,
every strategy with its triggers — is in
[references/CATALOG.md](references/CATALOG.md).

### Strategy archetypes

Funding arbitrage (cross-DEX delta-neutral), cash-and-carry basis, funding
fade, pair stat-arb, z-score & RSI mean reversion, momentum/trend, Donchian
breakout with pyramiding, grid trading, market making / volume farming, DCA
accumulation, relative-strength rotation, slot rotation, risk-parity
all-weather, market-neutral baskets, macro thesis baskets, tail-risk crisis
alpha, session windows, session-open drift, orderbook depth skew, chart
patterns, SMC/market-structure, candle reversal, cross-asset lag catch-up,
perp TP/SL.

## Installation

One-liner (installs into the agents it detects; prompts before writing):

```bash
git clone https://github.com/lucidlylabs/aspen-agent-kit.git
cd aspen-agent-kit && ./install.sh
```

Manual — the repo *is* the skill; copy or symlink it into your agent's skills
directory:

```bash
# Claude Code
ln -s "$(pwd)" ~/.claude/skills/aspen-agent-kit

# Cursor
ln -s "$(pwd)" ~/.cursor/skills/aspen-agent-kit

# Codex
ln -s "$(pwd)" ~/.codex/skills/aspen-agent-kit
```

Any agent that supports the agentskills.io format picks up
[SKILL.md](SKILL.md) as the entry point.

## Usage

Once installed, just talk to your agent. The skill routes protocol questions
to the matching protocol card, strategy questions to the archetype card, and
"find me a trade" to the scanner method. Examples:

- *"What's the safe way to lever up wstETH on Aave?"* → `aave-v3.md`: loop
  mechanics, health-factor buffer rules, the `onBehalfOf` refusal rule.
- *"Grid bot on SOL between 120 and 160"* → `grid-trading.md`: ladder
  construction, the guards a sound grid needs, what must be code not vibes.
- *"Where is funding rich right now?"* → `scanner.md` + the Hyperliquid perps
  module: how to screen, what the position costs to hold, what kills it.

The kit is **knowledge, not keys**. It contains no signer, no API client and
no addresses — your agent still executes through whatever wallet/venue tooling
you give it, and resolves live addresses and market ids itself. That is
deliberate: stale addresses in a doc are how funds get lost.

## Repository structure

```
├── SKILL.md                     # agent entry point / contract
├── references/
│   ├── CATALOG.md               # generated index of every card
│   ├── card-format.md           # frontmatter & section schema
│   ├── protocols/               # 73 protocol cards
│   ├── strategies/              # 25 strategy archetype cards
│   └── scanner/                 # the scanning method + per-venue modules
├── scripts/
│   └── build-catalog.mjs        # regenerates references/CATALOG.md
├── install.sh
├── DISCLAIMER.md
└── LICENSE
```

## Card anatomy

Every protocol card gives each action the same four-part treatment:

```markdown
## action: borrow
**Function:** borrow(address asset, uint256 amount, uint256 interestRateMode, …)
**Contract:** role `pool`
**Use when:** drawing a loan against supplied collateral.

### params     — every argument, decimals/scaling rules, required values
### pitfalls   — the mistakes that revert or lose money
### safety     — binding invariants ("refuse" means refuse)
```

See [references/card-format.md](references/card-format.md) for the full
schema, including how to read the Aspen-specific fields outside Aspen.

## Contributing / regenerating

Cards are the source of truth; the catalog is generated. After adding or
editing a card:

```bash
node scripts/build-catalog.mjs
```

## Disclaimer

**Trading is risky. Onchain transactions, borrows, and withdrawals are
irreversible.** This kit is documentation, not financial advice, and it can be
wrong or stale — verify against the protocol's official docs before moving
funds. See [DISCLAIMER.md](DISCLAIMER.md).

## License

[MIT](LICENSE)
