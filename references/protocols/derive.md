---
protocol: derive
category: options
chains: [957]
archetype: trade_option
executor: knowledge-only
aliases:
  - "buy an ETH call on derive"
  - "sell a covered call on derive"
  - "buy a BTC put option"
  - "open an ETH-PERP position on derive"
  - "close my derive options position"
  - "deposit USDC to a derive subaccount"
  - "run a covered-call strategy on derive"
roles: [matching, subAccount, tradeModule, depositModule, withdrawalModule, riskManager]
actions: [create_subaccount, deposit, place_order, cancel_order, transfer, withdraw]
tokens: [USDC, WETH, WBTC]
---

# Derive (formerly Lyra)

Derive is a self-custodial **options / perps / spot** exchange on its own OP-Stack L2, **Derive Chain
(chain 957)**. It trades **European, cash-settled options** (instrument naming `TICKER-YYYYMMDD-STRIKE-C|P`,
e.g. `ETH-20240628-3000-C`), **perps** (`ETH-PERP`), and **spot** (`ETH-USDC`). Quote/settlement is **USDC**
(the `CashAsset`, which can go negative as an intrinsic borrow); **WETH/WBTC** and other base assets are
usable as haircut collateral. Positions live inside an **ERC-721 subaccount**, each subscribed to one risk
manager: **Standard Margin (SM)** or **Portfolio Margin (PM)**. (Infra still carries Lyra branding —
`api.lyra.finance`, `X-Lyra*` headers.)

Trading is a **hybrid signed-order model**: build module-specific data (`TradeModuleData`), wrap it in an
EIP-712-style **`SignedAction`**, sign with the wallet or a registered session key, and POST to the API
(`/private/order`). On a match the on-chain **`Matching`** contract verifies the signature and settles the
fill trustlessly on-chain. Deposits/withdrawals use the same signed-action pattern against their modules.
Collateral bridges in from Ethereum / Arbitrum / Optimism / Base via a Socket-based bridge.

> **executor: knowledge-only.** Derive orders are signed `SignedAction`s (off-chain matching, on-chain
> `Matching` settlement) plus on-chain deposit/withdraw modules; there is no single `vault.manage` path yet.
> A Derive leg routes through the engine's signed-order path (create a subaccount, sign trade actions)
> analogous to the Hyperliquid agent. Addresses resolve from the registry by role — never from this file.

## action: create_subaccount
**Function:** API `POST /private/create_subaccount` (or `/private/deposit` for a new account). On-chain: a `SignedAction` with `module = DepositModule` whose data carries `managerForNewAccount` (StandardManager or PortfolioManager). Debug with `public/create_subaccount_debug`.
**Contract:** role `subAccount` (ERC-721 registry) + role `depositModule`.
**Use when:** provisioning a trading subaccount before any order — choosing its margin model.

### params
- `margin_type` — `"SM"` (Standard Margin, isolated, default) or `"PM"` (Portfolio Margin, risk-scenario across the whole subaccount). Selects the risk-manager address — pick deliberately, it can't be trivially changed later.
- `wallet` / `signer` — owner + signing key; `nonce`; `signature`; `signature_expiry_sec`.
- Initial `amount` + `asset_name:"USDC"` if funding on creation.

### pitfalls
- A wallet can hold multiple subaccounts, but each subscribes to exactly **one** risk manager for its lifetime.
- The `managerForNewAccount` in the deposit data fixes SM vs PM — a wrong choice means a new subaccount.

### safety
- Subaccounts are self-custodial (ERC-721 the owner holds); the exchange never takes custody. This is the isolation boundary — a strategy's subaccount holds only its own positions.

## action: deposit
**Function:** API `POST /private/deposit`; on-chain `SignedAction` with `module = DepositModule`, data = `DepositModuleData(amount, asset [CashAsset/USDC], managerForNewAccount)`. Debug with `public/deposit_debug`.
**Contract:** role `depositModule`.
**Use when:** funding a subaccount with USDC (or base) collateral.

### params
- `amount` — collateral to deposit; **18-decimal-scaled in the signed data** regardless of the token's own decimals.
- `asset_name` — `"USDC"` (cash) or a base asset (WETH/WBTC) as haircut collateral.

### pitfalls
- **USDC must be ERC20-`approve`d to the DepositModule** before the first deposit, or it reverts.
- Amounts in the signed action are 18-dec scaled even though USDC is 6-dec / WBTC 8-dec — scale correctly.
- Collateral must first be bridged onto Derive Chain (Socket bridge, ~2–5 min from L2s, 5–10 min from L1).

### safety
- Deposit adds collateral only. Base collateral carries a risk haircut (`BASE_DISCOUNT` ~0.8 ETH / 0.75 BTC); long options/base can push cash negative (interest-bearing borrow).

## action: place_order
**Function:** API `POST /private/order`. Two-layer signing: inner `TradeModuleData` wrapped in a `SignedAction` (`module = TradeModule`), verified on fill by `Matching`. Debug with `public/order_debug`.
**Contract:** role `tradeModule`, settled by role `matching`.
**Use when:** buying/selling an option, perp, or spot leg — a resting limit, a marketable order, a trigger (stop/TP), or a TWAP.

### params
- `instrument_name` — e.g. `ETH-20240628-3000-C`, `ETH-PERP`, `ETH-USDC`. The on-chain `asset` + `subId` come from `public/get_instrument` — **never hardcode them.**
- `direction` — `buy` / `sell` (`isBid` in the signed data).
- `amount` — size in base units (18-dec scaled in the signature).
- `limit_price` — **required even for market orders** (it is part of the signature; a market order just doesn't rest).
- `max_fee` — per-contract fee cap in USDC; for a resting/maker order must exceed `~2 × max(taker,maker) × spot + extra` or it's cancelled (`signed_max_fee_too_low`).
- `order_type` (`limit`/`market`), `time_in_force` (`gtc`/`post_only`/`fok`/`ioc`), `reduce_only`, `trigger_price`/`trigger_type` (`stoploss`/`takeprofit`)/`trigger_price_type` (`mark`/`index`), `algo_type:"twap"` (+`algo_duration_sec`, `algo_num_slices`), `mmp`, `label`.
- `nonce` — format `<UTC ms><up to 3–6 random digits>` (e.g. `1695836058725001`); reused nonces fail.
- `signature_expiry_sec` — **must be ≥5 minutes in the future.**

### pitfalls
- **`limit_price` and a valid signature are mandatory on every order** including market orders; use `order_debug` to validate encoding before sending.
- Options are matched with a **FIFO + pro-rata blend**; perps are **pure FIFO**.
- **Open-interest fee** on OI-increasing trades is `max($800, n × 0.70 × spot)` (transitional, high at launch) — punishing for small trades.
- To **close**: there is no close endpoint — submit an opposing order (usually `reduce_only:true`).

### safety
- **`reduce_only:true`** is the close-only guardrail (never increases the position). Trigger orders give stop-loss / take-profit. **Market Maker Protections** (`mmp:true` + `set_mmp_config`) auto-freeze quoting on rapid fills.
- **Settlement/expiry risk (options):** European options auto-settle to a **30-min TWAP of spot**; mark price transitions to the TWAP over the final 30 min, causing **delta decay** — a hedged/portfolio-margin account's delta drifts near expiry and can go underwater. An automated agent must account for expiry timing, not just price.
- Short OTM puts can become liquidatable as spot **rises** (margin scales with spot) — the risk isn't only downside.

## action: cancel_order
**Function:** API `/private/cancel` (single), plus `/cancel_by_nonce`, `/cancel_by_instrument`, `/cancel_by_label`, `/cancel_all`, `/cancel_trigger_order`. Atomic reprice: `/private/replace`.
**Contract:** role `matching`.
**Use when:** pulling resting orders or repricing (replace = atomic cancel+create).

### params
- The order id / nonce / instrument / label to cancel.

### pitfalls
- `cancel_by_nonce` **consumes a nonce even if no order exists** — don't reuse that nonce afterward.

### safety
- Cancels only reduce exposure; `cancel_all` is the quick de-risk. Session keys have scopes (`read_only`/`account`/`admin`); trading needs `admin` — scope down or revoke to disarm.

## action: transfer
**Function:** API `/private/transfer_erc20` (cash/base between own subaccounts) and `/private/transfer_position` / `transfer_positions` (options/perps, executed as a crossing maker+taker pair, `reduce_only` maker, zero `max_fee`). On-chain module `TransferModule`.
**Contract:** role `tradeModule` (position transfers cross as orders) / role `subAccount`.
**Use when:** moving collateral or positions between subaccounts the same owner controls.

### params
- Source/target subaccount ids + asset/position and amount (18-dec scaled).

### pitfalls
- A position transfer executes as crossing orders on `Matching`, so it is subject to the same signature/nonce rules as a normal order.

### safety
- Transfers stay within one owner's subaccounts; they don't move funds to a third party.

## action: withdraw
**Function:** API `POST /private/withdraw`; on-chain `SignedAction` with `module = WithdrawalModule`. Bridge back out via the Socket bridge.
**Contract:** role `withdrawalModule`.
**Use when:** moving USDC/base collateral off a subaccount back toward the vault/owner.

### params
- `asset_name` + `amount` (18-dec scaled) + the signed-action fields (`nonce`, `signature`, `signature_expiry_sec`).

### pitfalls
- Withdrawable is bounded by margin; if **USDC borrow utilization is high you may be unable to withdraw USDC** immediately (the cash market is intrinsic and interest-bearing).
- You **cannot withdraw** collateral that would drop the subaccount below its maintenance margin.

### safety
- Self-custodial escape hatch: because funds never leave the owner-controlled subaccount, on-chain withdrawal works even if the matching engine goes down. Liquidations run as a Dutch/solvent auction (discount `5% → 30%` over 15 min) once maintenance margin < 0, with a Security Module backstop for insolvent debt.
