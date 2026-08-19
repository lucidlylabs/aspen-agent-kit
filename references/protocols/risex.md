---
protocol: risex
category: perp
chains: [4153]
archetype: open_perp
executor: knowledge-only
aliases:
  - "long BTC 10x on risex"
  - "short ETH perp on risex"
  - "open a 25x long on BTC with a stop loss"
  - "market buy SOL perp reduce only"
  - "set leverage to 20x isolated on risex"
  - "close my risex perp position"
  - "set a take profit and stop loss on my risex position"
roles: [perpsManager, collateralManager, authorization, oracle]
actions: [register_signer, deposit, withdraw, place_order, cancel_order, update_leverage, update_margin_mode, update_isolated_margin, place_tpsl, migrate_account]
tokens: [USDC]
---

# RiseX (RISEx)

RiseX is a **fully on-chain orderbook perpetuals DEX** on **RISE (chain 4153)**, an Ethereum L2. Unlike an
off-chain-matched venue, the orderbook, oracle, and risk engine all live on-chain (~1ms book updates, ~3ms
E2E order latency). Collateral and settlement are **USDC**. Markets are quoted in USDC with per-market max
leverage (BTC 25×, ETH 25×, SOL/BNB/HYPE 20×, XRP/DOGE/NEAR/ZEC 10×, smaller alts 3×); market ids are
1-indexed (BTC=1, ETH=2, …).

There are **two ways to trade, both hitting the same on-chain contracts:**
1. **Direct on-chain call** — call `PerpsManager` (`placeOrder`, `cancelOrder`, `updateLeverage`, …) and
   `CollateralManager` (`deposit`/`withdraw`) yourself.
2. **Signed off-chain API relay** (the common path) — sign an **EIP-712 permit** with a registered
   **session-key signer** and POST it to the REST API (`/v1/orders/place`, …); RiseX submits the on-chain
   tx for you (deposits are gas-sponsored) and returns a `transaction_hash` + `order_id`. This is a
   signed-intent relay over the same contracts, **not** a custodial matcher.

> **executor: knowledge-only.** No `vault.manage` executor ships yet. A RiseX leg routes through the
> engine's signed-order path (register a scoped session key, then relay EIP-712 permits) analogous to the
> Hyperliquid agent; the direct on-chain path is available when an EVM executor lands. Addresses resolve
> from the registry by role — never from this file.

## action: register_signer
**Function:** API `POST /v1/auth/register-signer`; contract `RISExAuthorization.registerSigner(account, signer, message, nonceAnchor, nonceBitmap, expiration, accountSignature)`. One-time auth setup before any state-changing call.
**Contract:** role `authorization`.
**Use when:** delegating a scoped, revocable session key (the engine's trade signer) for an account.

### params
- `signer` — the session-key address that will sign order permits.
- `expiration` — session-key expiry (docs example ~7–30 days); must re-register on expiry.
- Permission scope — enum `None | All | Perps | Spot | MoveFund` (defaults to `All`; scope down to `Perps` for a trade-only key).
- `nonceAnchor` (uint48 epoch) + `nonceBitmap` (uint8 bit) — the bitmap-nonce anchor (≤256 concurrent nonces per epoch).

### pitfalls
- **Every state-changing API call needs fresh `permit_params`** (an EIP-712 signature from this signer) with a **unique bitmap nonce** — reusing a nonce is rejected.
- The session key **expires** (~7 days typical); an expired key silently fails all authenticated calls until re-registered.

### safety
- Session-key permissioning is the kill-switch surface: `enablePermission`/`disablePermission` scope a signer to `Perps`/`Spot`/`MoveFund`, and `revokeSigner` (EIP-712 signed) kills it entirely. `getSessionKeyStatus` → `None | Authorized | Expired | Revoked`. A `Perps`-scoped key can trade but never `MoveFund` (withdraw).

## action: deposit
**Function:** API `POST /v1/account/deposit {account, amount}` (amount in plain decimal, e.g. `"100"` = 100 USDC; **gas-sponsored**, 3–5 min to credit); contract `CollateralManager.deposit(receiver, token, amount)`.
**Contract:** role `collateralManager`.
**Use when:** funding an account with USDC collateral before trading.

### params
- `amount` — USDC to deposit. API path takes plain decimal; contract path takes native-decimal units and requires a prior ERC20 `approve` to `CollateralManager`.

### pitfalls
- On-chain deposit needs an ERC20 `approve` to `CollateralManager` first, or it reverts.
- API deposit is gas-sponsored but takes **3–5 min to credit** — don't place orders against uncredited balance.

### safety
- Deposit adds collateral only; it takes on no position risk. USDC is the sole live collateral token.

## action: place_order
**Function:** API `POST /v1/orders/place`; contract `PerpsManager.placeOrder(PlaceOrderParams)`. Returns `order_id` + `transaction_hash` (contract returns a 56-bit `WideOrderId`).
**Contract:** role `perpsManager`.
**Use when:** opening/resting a perp order — a limit at a price, or a marketable market order.

### params
- `marketId` — 1-indexed market (BTC=1, ETH=2, …).
- `size` — **integer `sizeSteps` × market `stepSize`** (e.g. BTC step 0.000001 BTC); sub-step sizes are invalid.
- `price` — **integer `priceTicks` × market `stepPrice`** (e.g. BTC $0.1 tick); round to the tick.
- `side` — 0 = Long/Buy, 1 = Short/Sell.
- `orderType` — 0 = Market, 1 = Limit.
- `timeInForce` — 0 GTC, 1 GTT, 2 FOK, 3 IOC.
- `postOnly` — bool (maker-only; cancelled if it would cross).
- `reduceOnly` — bool (may only shrink/close, never flip).
- `stpMode` — self-trade prevention: 0 ExpireMaker / 1 ExpireTaker / 2 ExpireBoth (always on).
- `expiry` — unix seconds (GTT); on-chain uses `ttlUnits` (5-min units).

### pitfalls
- **Size and price are integers** — always convert via the market's `stepSize`/`stepPrice`; un-stepped values are rejected.
- Per-market bounds enforced: `minOrderStep`, `maxOrderStep`, `oiLimitSteps` (open-interest cap), optional `matchPriceBandBps`.
- **No max-slippage param** — control slippage by using a **limit** order with a bounded `price`, not a market order.
- Order-quota rate limit: 10,000 free tx to start, +1 tx per $5 lifetime volume; place = 1 tx, cancel = free; at zero headroom you're throttled to **1 order / 10s** (watch `X-Address-Quota-Remaining`). Edge limit 200 req/10s.
- During a **maintenance window** the venue is post-only — market/taker orders are rejected, cancels still work.

### safety
- Kill switch = the session-key scope (revoke/disable the `Perps` permission to stop all order placement).
- `reduceOnly` is the primary de-risking primitive; a `reduceOnly` order that would flip the position is rejected.
- Per-user isolation: a scoped signer trades only its own account and can never `MoveFund`.

## action: cancel_order
**Function:** API `POST /v1/orders/cancel {market_id, order_id}`; contract `PerpsManager.cancelOrder(CancelOrderParams{marketId, orderId})` (batch `cancelOrders(marketId, RestingOrderId[])`). **Cancels are free.**
**Contract:** role `perpsManager`.
**Use when:** pulling resting limit orders.

### params
- `marketId` + `orderId` — the `RestingOrderId` (40-bit) extracted from the placed order's `WideOrderId` (56-bit).

### pitfalls
- **Only resting (limit) orders are cancellable** — a market/IOC-filled order has nothing to cancel. You must extract the 40-bit `RestingOrderId` from the 56-bit `WideOrderId` returned at placement.

### safety
- Cancels only reduce exposure; always permitted (free, and allowed even in post-only maintenance mode).

## action: update_leverage
**Function:** API `POST /v1/account/leverage {market_id, leverage}` (leverage encoded ×1e18); contract `PerpsManager.updateLeverage(UpdateLeverageParams{marketId, leverage})` (plain `uint8`, e.g. 10 = 10×).
**Contract:** role `perpsManager`.
**Use when:** setting per-market leverage before/between orders.

### params
- `leverage` — integer, capped by the market's `maxLeverage` (BTC/ETH 25×, down to 3× on small alts). API encodes ×1e18; contract takes plain `uint8`.

### pitfalls
- Leverage is **per market**, capped per market; a change adjusts liquidation price immediately but does not close positions.

### safety
- A config action, not fund movement; still gated by the session-key scope, never touches custody.

## action: update_margin_mode
**Function:** contract `PerpsManager.updateMarginMode(marketId, marginMode)` (Cross = 0, Isolated = 1).
**Contract:** role `perpsManager`.
**Use when:** switching a market between cross (whole-account collateral) and isolated (per-market fenced) margin.

### params
- `marginMode` — 0 Cross (default; all USDC + all positions' uPnL back margin), 1 Isolated (only assigned margin + that position's uPnL).

### pitfalls
- **Cannot change margin mode while the market has open positions or orders** — flatten first.

### safety
- Config action; affects the liquidation waterfall for that market but moves no funds.

## action: update_isolated_margin
**Function:** contract `updateIsolatedPositionMarginBalance(marketId, int256 amount)` (positive = add, negative = remove; 18-dec USDC).
**Contract:** role `perpsManager`.
**Use when:** adding/removing collateral on an isolated position to move its liquidation price.

### params
- `amount` — signed int; positive adds isolated margin, negative removes it.

### pitfalls
- Over-removing isolated margin raises liquidation risk immediately.

### safety
- Adding margin de-risks; removing adds risk — the health metric is Cross Health Factor = Cross Margin Balance / Total Cross MM (risk rises as it → 1).

## action: place_tpsl
**Function:** conditional reduce-only close orders (take-profit / stop-loss); API-only proportional sizing. Costs 1 tx to place.
**Contract:** role `perpsManager` (trigger price from role `oracle` / last-traded).
**Use when:** attaching an automatic profit-take or stop-loss to an open position.

### params
- Trigger source (per order): **Last Traded Price** (a real trade crosses the stop) or **Mark Price** (the Stork oracle crosses it) — they do not cross-trigger.
- Sizing: Full (100%, auto-tracks the position), Fixed (won't grow, clamps down), Proportional (API-only, tracks both ways).
- No max-slippage param — bound execution slippage with a `limit_price` on the close.

### pitfalls
- TP/SL are **always reduce-only** and can never increase or flip a position (auto-cancelled on full close/flip, re-sized on partial close).
- **Automatic offline execution requires a one-time on-chain delegation signature** authorizing a specific RiseX executor to submit the close while you're offline (revocable via the signer permissions).

### safety
- The delegation is scoped and on-chain-verifiable; revoke it (or the session key) to disarm auto-execution. Mark price = median of 3 calcs (book-premium-anchored + raw book + Stork), so a single thin-book spike is less likely to trip a mark-triggered stop.

## action: migrate_account
**Function:** contract `migrateAccount(newAccount)` — moves all positions, collateral, and orders to a fresh address.
**Contract:** role `perpsManager`.
**Use when:** rotating the account address (e.g. key rotation) — source must be healthy, target empty.

### params
- `newAccount` — the destination address (must hold no RiseX positions/collateral/orders).

### pitfalls
- Source account must be **healthy** (above maintenance margin) to migrate; RiseX has no sub-accounts — one account = one address, so migration is the account-rotation primitive.

### safety
- Migration preserves positions atomically; it is a recovery/rotation tool, not a trading action, and is gated by account ownership.
