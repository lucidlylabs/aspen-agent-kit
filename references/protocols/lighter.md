---
protocol: lighter
category: perp
chains: [1]
archetype: open_perp
executor: knowledge-only
aliases:
  - "long BTC 50x on lighter"
  - "short ETH perp on lighter"
  - "open a 25x long on SOL with a stop loss"
  - "market buy HYPE perp reduce only"
  - "set leverage to 20x isolated on lighter"
  - "close my lighter perp position"
  - "place a TWAP order on lighter"
roles: [venue, settlement]
actions: [register_api_key, deposit, create_order, cancel_order, modify_order, update_leverage, update_margin, withdraw]
tokens: [USDC, ETH]
---

# Lighter

Lighter is a **verifiable central-limit-orderbook (CLOB) perps exchange** ("Lighter Core") that runs its
own off-chain matching engine and **settles on Ethereum (chain 1) via ZK validity proofs** — a
ZK-rollup-style app-chain purpose-built for an exchange, NOT an EVM chain and NOT a plain on-chain-call DEX.
Collateral/settlement is **USDC** (ETH is usable as multi-asset margin). Perp markets (100+: BTC/ETH 50×,
SOL/FX 25×, majors 10–20×, small caps 3–8×) are addressed by **integer `market_index`**, not symbol.

**Placing a trade = a signed off-chain L2 transaction, not an on-chain call.** The trader signs an L2 tx
(create/cancel/modify order) with a registered **API key** (a Lighter-specific signing key, distinct from
the Ethereum wallet key), and POSTs it via REST `sendTx`/`sendTxBatch` (or WebSocket). API servers validate
syntax (HTTP 200 = *accepted, not executed*); the **Sequencer** gives FIFO ordering + soft finality; the
**Matching Engine** matches on price-time priority and runs post-trade risk checks. Proofs are aggregated and
verified by **Ethereum contracts** (role `settlement`) that hold deposits + the canonical state root. Users
keep custody and can always force-exit through the L1 **Escape Hatch** if the Sequencer censors.

> **executor: knowledge-only.** Lighter trades are signed L2 txs via a registered API key (off-chain,
> Sequencer-executed), with on-chain deposit/withdraw/escape-hatch on Ethereum. A Lighter leg routes through
> the engine's signed-order path (register an API key, then sign L2 txs) analogous to the Hyperliquid agent;
> deposits/withdrawals are the on-chain half. No `vault.manage` executor yet. Addresses resolve from the
> registry by role — never from this file.

## action: register_api_key
**Function:** SDK `change_api_key(eth_private_key, new_pubkey, ...)` / contract `ChangePubKey`. One-time association of a signing key to an account.
**Contract:** role `settlement` (association) + role `venue` (the key signs L2 txs thereafter).
**Use when:** provisioning the engine's L2 signing key for an account before any trade.

### params
- `new_pubkey` — the API-key public key that will sign L2 txs.
- API-key index — each account registers up to **256 keys (indices 0–254; 0–3 reserved for web/mobile, 255 = "all" sentinel)**. Each key has its **own nonce** and read+write (trade+withdraw) permission.

### pitfalls
- **Associating a key needs the L1 private key once** (`ChangePubKey` / the `change_api_key` signer); generating the key itself does not.
- **Nonce is per-API-key** and must be `new = old + 1` (or `skip_nonce` within the `2^47..2^48-1` window). Use `next_nonce` or track locally. **Gotcha:** a valid *taker* order later rejected by the Sequencer **still consumes the nonce**; a *maker* order rejected at the API layer does **not** — consider one key per order-type.
- Auth tokens (`create_auth_token_with_expiry`) are max 8h; read-only (`ro:`) tokens can't sign trades.

### safety
- **Maker-only keys** can be restricted to post-only/modify-ALO/cancel — a least-privilege signer for a market-making path. Keys are revocable/rotatable via `ChangePubKey`; that scoping is the kill-switch surface.

## action: deposit
**Function:** contract `deposit(_to, _assetIndex, _routeType, _amount)` (approve USDC to Lighter's contract first); or via **Circle CCTP** `createIntentAddress(chain_id, from_addr, amount)` from a source chain.
**Contract:** role `settlement`.
**Use when:** funding an account with USDC collateral (auto-creates the master account on first deposit).

### params
- `_routeType` — **0 = perps**, 1 = spot. Only **USDC** to the perps account.
- `_assetIndex` — from the contract's `assetDetails`.
- `_amount` — ERC20 decimals. **Min 1 USDC** direct on L1; **min 5 USDC** via CCTP.
- CCTP `chain_id` — a deposit source: **Arbitrum (42161), Base (8453), Avalanche C-Chain**.

### pitfalls
- Direct deposit needs an ERC20 `approve` to the Lighter contract first.
- **CCTP deposits take ~15–20 min** to credit (direct L1 ~minutes); don't trade against uncredited balance.

### safety
- Deposit adds collateral only, no position risk. Custody stays with the user; the L1 contract holds deposits under the proven state root.

## action: create_order
**Function:** SDK `create_order(...)` / `sign_create_order(...)` (`SignerClient`; `create_market_order`, `create_market_order_quote_amount`, `create_grouped_orders` variants). Signed L2 tx → `send_tx`/`send_tx_batch`.
**Contract:** role `venue`.
**Use when:** opening/resting a perp order — limit, market, stop-loss/take-profit (with trigger), or TWAP.

### params
- `market_index` — integer market id (e.g. 0 = ETH perp); resolve from `orderBookDetails`.
- `base_amount` — **integer, scaled by the market's `supported_size_decimals`**.
- `price` — **integer, scaled by `supported_price_decimals`**. For a **taker** order this is the **worst acceptable price** (cancelled if unmet).
- `is_ask` — False = buy/bid, True = sell/ask.
- `order_type` — `LIMIT`(0), `MARKET`(1), `STOP_LOSS`(2), `STOP_LOSS_LIMIT`(3), `TAKE_PROFIT`(4), `TAKE_PROFIT_LIMIT`(5), `TWAP`(6).
- `time_in_force` — `IMMEDIATE_OR_CANCEL`(0), `GOOD_TILL_TIME`(1), `POST_ONLY`(2, ALO/maker-only).
- `reduce_only` — bool; the "only close" guardrail.
- `client_order_index` — uint48 caller ref (used for cancel/modify).
- `order_expiry` — ms timestamp, **5 min – 30 days** (GTT).
- TP/SL — require **both** a `trigger_price` and a `price` (price = allowed slippage). TWAP slices every 30s (`#orders = duration/30s + 1`).

### pitfalls
- **HTTP 200 ≠ executed** — confirm real fills on the WebSocket account/order channel; the Sequencer can still reject.
- **Integer price/size scaling** per-market from `orderBookDetails` — wrong decimals = wrong size.
- **Min order size** (max of min-base and min-quote) applies to **maker** orders only.
- **Fat-finger guard:** ask ≥ `max(mark,bestBid)*0.95`; bid ≤ `min(mark,bestAsk)*1.05` — outside → rejected.
- Order caps: 1500 active/account (1000/market); 500 pending TP-SL-TWAP/account (16/market). Rate limits: standard 60 req/min, `sendTx` bucket separate (tier + staked LIT), WS 200 msgs/min.

### safety
- **reduce_only** (available on market/limit/TP-SL/TWAP) is the close-only guardrail — the position only moves toward zero and the remainder auto-cancels at zero; it's also an L1 escape-hatch op. **post_only** guarantees maker-only. Triggers/liquidations use **mark price**, not last trade. Revoke/scope the API key to stop order flow.

## action: cancel_order
**Function:** SDK `cancel_order(market_index, order_index)`; cancel-all `sign_cancel_all_orders(time_in_force, timestamp_ms, cancel_all_market_index)`.
**Contract:** role `venue`.
**Use when:** pulling resting orders (`order_index` = your `client_order_index`).

### params
- `market_index` + `order_index` (the client order index used at placement).

### pitfalls
- Cancel is a signed L2 tx — subject to the per-key nonce and rate limits like any other.

### safety
- Cancels only reduce exposure; a cancel-all is the quick de-risk. Always permitted.

## action: modify_order
**Function:** SDK `modify_order(market_index, order_index, base_amount, price)`.
**Contract:** role `venue`.
**Use when:** repricing/resizing a resting order in place.

### params
- `base_amount` / `price` — new integer-scaled values (same scaling rules as `create_order`).

### pitfalls
- Same integer-scaling and nonce rules as placement; a modify that would cross may be treated as a taker.

### safety
- A modify never moves funds; gated by the API-key scope like every L2 tx.

## action: update_leverage
**Function:** SDK `sign_update_leverage(market_index, fraction, margin_mode, ...)`. Rate-limited 40/min.
**Contract:** role `venue`.
**Use when:** setting per-market leverage and margin mode.

### params
- `fraction` — the initial-margin fraction; **effective IMR = min(user fraction, market minimum fraction)**, so leverage is capped per market (BTC/ETH 50×, SOL/FX 25×, down to 3–8× on small caps).
- `margin_mode` — 0 = cross, 1 = isolated.

### pitfalls
- Leverage is per-market and capped; a user fraction below the market minimum is clamped up (you can't exceed the market cap).

### safety
- Config action, no fund movement. Isolated mode fences a position's collateral ("AllocatedMargin") as a separate account.

## action: update_margin
**Function:** SDK `sign_update_margin(market_index, usdc_amount, direction, ...)`.
**Contract:** role `venue`.
**Use when:** adding/removing collateral on an **isolated** position to move its liquidation price.

### params
- `usdc_amount` + `direction` — add or remove isolated (allocated) margin.

### pitfalls
- Over-removing isolated margin raises liquidation risk immediately; the account-health check uses mark price.

### safety
- Adding margin de-risks. Liquidation waterfall: Healthy (`AV ≥ IMR`) → Pre-liquidation (only health-improving, non-size-increasing ops) → Partial (cancel orders, IoC zero-price, up to 1% fee to the LLP insurance fund) → Full (LLP takes over) → ADL. Funding is hourly, peer-to-peer, clamped (max 4%/8h).

## action: withdraw
**Function:** contract `withdraw` (secure withdrawal, same L1 address only, no ETH key needed, min 1 USDC); SDK `sign_withdraw(asset_index, route_type, amount, ...)`. Fast Withdrawal (USDC, min 4 USDC, ≤10/hr) and `sign_transfer(...)` to another L1 both need the **Ethereum private key**.
**Contract:** role `settlement`.
**Use when:** moving USDC collateral off the venue back to the vault/owner.

### params
- `asset_index` / `route_type` (0 perps) / `amount`.

### pitfalls
- **Secure withdrawal only returns to the origin L1 address**; sending elsewhere (fast withdraw / transfer) requires the ETH private key — a trade-only API key cannot redirect funds.
- **Cannot withdraw unrealized PnL**; withdrawable is bounded by free margin. `L2Withdraw` rate-limited 2/min; Fast Withdraw 10/hr.

### safety
- The custody boundary: an API key registered trade-only should not hold the ETH key, so it can place/cancel orders but can never redirect a withdrawal off the origin address. The L1 Escape Hatch guarantees the user can always force-exit regardless of the Sequencer.
