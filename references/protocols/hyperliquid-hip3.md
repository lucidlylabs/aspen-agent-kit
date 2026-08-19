---
protocol: hyperliquid-hip3
category: perp
chains: [999]
archetype: builder_perp
executor: knowledge-only
aliases:
  - "trade a builder-deployed perp on hyperliquid"
  - "long a HIP-3 perp market"
  - "deploy a builder perp dex on hyperliquid"
  - "order on a builder perp dex"
  - "short a HIP-3 pre-launch perp"
roles: [venue]
actions: [order, market_open, market_close, cancel, update_leverage, approve_builder_fee]
tokens: [USDC]
---
# Hyperliquid HIP-3 (Builder-Deployed Perpetuals)
HIP-3 lets anyone permissionlessly deploy an independent **perp DEX** on Hyperliquid's shared L1 infrastructure — the deployer ("builder") defines the markets (oracle definitions, contract specs) and operates them (oracle prices, leverage limits, settlement). It is the same off-chain order-book venue reached via signed `/exchange` API actions through Aspen's HL agent, never an EVM `vault.manage`; margin/settlement remain in **USDC**. Trading a HIP-3 perp is mechanically identical to a first-party perp — the same `order`/`cancel`/`updateLeverage` actions, just targeting the **asset id belonging to the builder's dex** (unified asset-id scheme; no special routing). Deploying a mainnet perp dex requires staking **500,000 HYPE** (expected to decrease over time), held for at least 183 days. The first three assets deploy with no auction; further assets go through a HIP-1-style Dutch auction, and deployers get 7 reserve deployments that bypass the auction timer. Builders set an additional fee share of **0–300%** (0–100% in growth mode; above 100% raises the protocol fee to match) and are **subject to stake slashing** for malicious or faulty operation — up to 100% for invalid state transitions (e.g. a manipulated oracle) or prolonged downtime, up to 50% for brief downtime, up to 20% for network degradation; unstaking sits in a 7-day queue during which the stake remains slashable.
> **executor: knowledge-only.** Hyperliquid legs run through the Aspen engine's off-chain HL agent (signed API actions), not an EVM `vault.manage`; there is no on-chain address/role. The harness routes an HL request to the engine's DSL path. This file is the knowledge that path is built against.
## action: order (builder-deployed perp)
**Function:** `order(name, is_buy, sz, limit_px, order_type, reduce_only=False, cloid=None, builder=None)` (`exchange.py`); routes by asset id under the builder's perp dex (`hip-3` docs, `exchange-endpoint`)
**Contract:** role `venue` (off-chain — no registry address)
**Use when:** taking a position on a builder-deployed (HIP-3) perp market.
### params
- `name`/asset id — resolves to the asset within the **builder's** perp dex, not the first-party universe; asset id = `100000 + perp_dex_index * 10000 + index_in_meta` (e.g. testnet `test:ABC` with dex index 1, meta index 0 → `110000`).
- `sz`, `limit_px`, `order_type`, `reduce_only`, `cloid` — identical semantics to first-party perps (size→`szDecimals`, tif Gtc/Ioc/Alo, trigger tp/sl).
- `builder` — `{b, f}` builder-fee tag if the dex charges a builder fee (pre-approve with `approve_builder_fee`).
### pitfalls
- **Deployer-set risk parameters.** Max leverage, oracle, and margin rules are chosen by the builder and can differ sharply from first-party markets — verify per-dex before sizing.
- **Oracle/settlement risk.** The builder controls oracle pricing and can settle/delist; a manipulated or thin oracle is the primary hazard (mitigated only by the builder's slashable stake).
- Asset ids are dex-scoped — using a first-party id targets the wrong market.
- Builder fee only applies if the account approved it via `approve_builder_fee(builder, max_fee_rate)`.
### safety
- Same engine kill switch + trade-only HL agent; no fund custody on the venue.
- Treat builder-deployed markets as higher-trust-assumption than first-party perps — surface the deployer/oracle in the consent screen; per-user isolation still bounds blast radius.
## action: update_leverage
**Function:** `update_leverage(leverage, name, is_cross=True)` (`exchange.py`)
**Contract:** role `venue` (off-chain)
**Use when:** setting leverage on a HIP-3 market — bounded by the **builder's** configured max.
### params
- `leverage` — integer 1..(builder-set max for that asset).
- `is_cross` — cross vs isolated as with first-party perps, **but a HIP-3 dex may run "no cross" mode** (isolated-only margin, with margin removal enabled); the deployer's choice to enable cross margin on an asset is irreversible.
### pitfalls
- Max leverage is builder-defined and may change; do not assume first-party caps.
### safety
- Config action only; engine-gated, no custody movement.
