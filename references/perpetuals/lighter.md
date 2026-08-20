---
venue: lighter
section: perpetuals
title: Lighter
surfaces: [perps, spot, rwa, pre-ipo, prelaunch, perp-rfq, public-pools]
docs: https://docs.lighter.xyz
official_kit: https://github.com/elliottech/lighter-agent-kit
triggers: >-
  trade on lighter, connect to lighter, lighter api key, market_index,
  zero fee perps, standard vs premium account, LIT staking, robinhood lighter
---

# Lighter

## Use the official agent kit for execution

Lighter ships its own agent skill. **Install it and let it own the money path.** This card does not
re-document order placement, because a maintained first-party kit will always be more current than a
third-party copy of it.

| What | Where |
|---|---|
| Official agent kit | https://github.com/elliottech/lighter-agent-kit |
| Docs | https://docs.lighter.xyz (`llms.txt` index; append `.md` to any page for raw Markdown) |
| API reference | https://apidocs.lighter.xyz |

```bash
curl -fsSL https://github.com/elliottech/lighter-agent-kit/releases/latest/download/install.sh | bash
```

It covers order books, candles, funding rates, fills and market metadata; **paper trading against
live order books**; balances, positions, open orders and PnL; limit and market orders, modify,
cancel, leverage and margin changes; withdrawals and perp/spot transfers. It supports both Lighter
and the Robinhood Chain deployment ("Robinhood Lighter"), where spot pairs like `AAPL/USDG` are
distinguished by the `/` separator. Public reads need no credentials; account reads and all writes
need an API key, configured via its `./lighter-config` helper into
`~/.lighter/lighter-agent-kit/credentials`.

**The paper-trading mode is the most valuable thing in that kit and the most underused.** It
simulates against live books. Anything you are about to run with money should run there first — see
[../quant/validation/backtesting.md](../quant/validation/backtesting.md) for why a live-book paper
run catches a class of error that no historical backtest can.

## What this card adds

The venue's structure, its costs, and the places where it differs from Hyperliquid in ways that
change strategy design rather than just API calls.

## The architecture, in one paragraph

Lighter is a verifiable CLOB. Matching runs off-chain in its own sequencer and matching engine;
state is proven with **ZK validity proofs** and settled to contracts on Ethereum that hold deposits
and the canonical state root. Placing a trade is a **signed L2 transaction**, not an on-chain call:
you sign with a registered API key (distinct from your Ethereum key) and POST it. Users keep
custody, and an L1 **escape hatch** lets you force-exit if the sequencer censors you. Markets are
addressed by integer `market_index`.

## What is structurally different from Hyperliquid

**The fee model is inverted, and it is the venue's defining design choice.** A Standard account pays
**zero** maker and taker fees and accepts added latency: roughly 300ms on takers, 200ms on makers and
cancels. Premium accounts pay real fees and get lower latency; Plus accounts trade a flat half-basis
-point for higher rate limits. This is not a discount — it is a different currency for the same cost.
[fees.md](fees.md) works through what a 300ms taker delay actually costs, because it is invisible to
any backtest that models fees as basis points.

**Funding is clamped, and the clamps bind often.** The rate is built from a premium sampled once a
minute at a random offset, time-weighted over the hour, then pushed through two clamps: a small clamp
(default 5bp) that pulls the premium toward the interest-rate component, and a big clamp (default 4%
per 8h, i.e. 0.5%/hr) that caps it. The result is divided by 8 to spread it over eight hours.

Two things follow that matter for any funding strategy:

- **If the premium stays inside ±5bp, funding defaults to the interest rate over 8** — about 1bp per
  8 hours, or 0.00125%/hr. Quiet markets do not pay carry here. A funding screen calibrated on a
  venue without this floor will systematically over-predict Lighter's carry.
- **A `FundingPremiumMultiplier` scales the premium per market class**: 1 for crypto, ½ for RWAs, and
  1/100 for pre-IPO and pre-launch markets. Funding on a pre-IPO market is therefore nearly inert by
  construction, and a basis that would be arbitraged away by funding pressure on a crypto market can
  persist indefinitely there.

**The API key is a real privilege boundary, and it is sharper than Hyperliquid's.** Keys are
per-account with individual nonces, and a key can be scoped. A trade-only key that does not hold the
Ethereum private key **cannot redirect a withdrawal**: the secure withdrawal path only returns funds
to the origin L1 address, and anything else requires the ETH key. Build on that. It is the cleanest
custody boundary of the three venues in this kit.

**Nonce handling has a sharp edge.** Nonces are per-API-key and must increment. A valid taker order
that the sequencer later rejects **still consumes the nonce**; a maker order rejected at the API
layer does not. A single key shared across an aggressive taker path and a resting maker path will
desynchronise. Use separate keys per order type.

**Non-crypto markets are a first-class surface.** RWAs, pre-IPO and pre-launch markets exist here
with their own contract specifications and their own funding treatment. They are thin, their price
formation is not continuous, and standard crypto microstructure intuitions transfer badly. Read the
market specifications before treating one as just another symbol.

## What to verify live, every time

`market_index` and the per-market size/price integer scaling (wrong scaling is a total-loss class of
bug). Per-market leverage caps. Your account tier and therefore your actual fee and latency. Funding
clamp parameters and the premium multiplier for the market class you are trading. Minimum order size.
