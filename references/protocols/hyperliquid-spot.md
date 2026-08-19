---
protocol: hyperliquid-spot
category: dex
chains: [999]
archetype: spot_trade
executor: knowledge-only
aliases:
  - "buy PURR spot on hyperliquid"
  - "sell HYPE for USDC on the hyperliquid spot dex"
  - "spot swap USDC to a HIP-1 token"
  - "place a limit buy on hyperliquid spot"
  - "move USDC from perp to spot on hyperliquid"
roles: [venue]
actions: [order, market_open, cancel, spot_transfer, usd_class_transfer]
tokens: [USDC]
---
# Hyperliquid Spot
Hyperliquid's spot DEX is a native on-book spot market on the Hyperliquid L1 for **HIP-1** capped-supply tokens, each paired against **spot USDC**. Like perps it is off-chain relative to HyperEVM — reached via signed `/exchange` API actions through the engine's HL agent, never an EVM `vault.manage`. It uses the same `order` action as perps, distinguished by the **asset id**: spot asset id = `10000 + index`, where `index` is the pair's position in `spotMeta.universe` (e.g. PURR/USDC = `10000`). There is **no leverage, no margin, no liquidation** — spot is fully collateralized, you trade a base token you actually hold for USDC. HIP-1 tokens carry a globally unique on-chain hash as their canonical id (frontend names may differ); sizes round to the token's `szDecimals`. HIP-2 "Hyperliquidity" optionally seeds automated on-book liquidity for a pair (consensus-run: a 0.3% spread refreshed every ~3s block, USDC-quoted pairs only), but many bridged assets opt out (`noHyperliquidity`).
> **executor: knowledge-only.** Hyperliquid legs run through the Aspen engine's off-chain HL agent (signed API actions), not an EVM `vault.manage`; there is no on-chain address/role. The harness routes an HL request to the engine's DSL path. This file is the knowledge that path is built against.
## action: order (spot)
**Function:** `order(name, is_buy, sz, limit_px, order_type, reduce_only=False, cloid=None, builder=None)` (`exchange.py`); spot coin naming `"{dex}:{token}"` / spot asset id `10000+index` (`exchange-endpoint`, `info-endpoint/spot`)
**Contract:** role `venue` (off-chain — no registry address)
**Use when:** buying/selling a HIP-1 spot token against USDC on the order book.
### params
- `name` — spot coin/pair; resolves to spot asset id `10000 + spotMeta index`. `is_buy=true` buys the base token with USDC.
- `sz` — base-token size; **rounds to the token's `szDecimals`**.
- `limit_px` — quote (USDC) price; rounds to tick.
- `order_type` — `{"limit":{"tif":"Gtc"|"Ioc"|"Alo"}}` (spot has no trigger/perp-style TP-position semantics; use resting limits or Ioc).
- `reduce_only` — not meaningful for spot (no position); leave false.
### pitfalls
- **Spot != perp balance.** Buying spot spends the **spot** USDC balance; convert from perp with `usd_class_transfer(amount, to_perp=false)` first.
- Ticker is a display name — the **on-chain hash is the unique id**; two frontends can show the same ticker for different tokens.
- `reduce_only` has no effect on spot; do not rely on it as a guard.
- Size rounds to `szDecimals`.
### safety
- Engine kill switch gates every order; the HL agent is trade-only and cannot withdraw tokens off the venue.
- Fully collateralized — no leverage/liquidation risk on spot; per-user isolation as with perps.
## action: spot_transfer / usd_class_transfer
**Function:** `spot_transfer(amount, destination, token)` (wire `{type:"spotSend", destination, token:"NAME:tokenId", amount}`, EIP-712 user-signed); `usd_class_transfer(amount, to_perp)` (wire `{type:"usdClassTransfer", amount, toPerp, nonce}`) (`exchange.py`, `exchange-endpoint`)
**Contract:** role `venue` (off-chain)
**Use when:** moving USDC between the perp and spot books (`usd_class_transfer`), or sending a spot token to another address (`spot_transfer`).
### params
- `to_perp` — true = spot→perp, false = perp→spot.
- `spot_transfer.token` — the HIP-1 token to send; `destination` = recipient address.
### pitfalls
- `spot_transfer` is a **fund movement** — the trade-only Aspen agent should not perform arbitrary external transfers; restrict to same-account/USDC-class moves per policy.
### safety
- Any transfer action is policy-gated; the engine's kill switch and least-privilege agent policy bound what the HL agent may move.
