---
protocol: polymarket
category: prediction
chains: [137]
archetype: predict_trade
executor: live
aliases:
  - "bet yes on a polymarket market"
  - "buy YES shares in a prediction market"
  - "buy NO at 0.30 on polymarket"
  - "place a limit order on a prediction market"
  - "take profit on my polymarket position at 75 cents"
  - "stop loss on a prediction market bet"
  - "sell my polymarket position"
  - "redeem my winning polymarket shares"
  - "merge my yes and no shares back to cash"
roles: [exchange, negRiskExchange, conditionalTokens, collateralAdapter, negRiskCollateralAdapter, onramp, offramp]
actions: [place_order, cancel_order, split_position, merge_positions, redeem_positions, convert]
tokens: [USDC, USDCe, pUSD]
---

# Polymarket

Polymarket is a prediction-markets protocol on **Polygon (chain 137)**. A market resolves a real-world
question (an election, a sports result, a price threshold) into **binary outcome tokens** — one ERC-1155
token per outcome (YES and NO are *separate token ids*). A winning outcome token redeems for **$1** of
collateral after resolution; a losing one for **$0**. There is **no leverage and no liquidation** — the
most a position can lose is what was paid for it.

Trading is a **hybrid** model: a trader **signs an EIP-712 limit order off-chain** and POSTs it to the
Polymarket **CLOB operator** (role `clob`, `clob.polymarket.com`), which matches it against the book and
submits matched trades on-chain to the **Exchange** contract for atomic settlement. The operator can only
match and order — it never takes custody, sets prices, or moves funds. Position primitives
(**split / merge / redeem**) are instead **direct on-chain calls** the trader makes through the pUSD
collateral adapter. Collateral is **pUSD** (an ERC-20 on Polygon, 6 decimals, backed 1:1 by USDC, wrapped
from bridged **USDC.e**); outcome tokens are Gnosis **Conditional Tokens (CTF)**.

> **executor: live (signed-order trunk).** Polymarket runs on the harness's `signed` modality: the compose
> catalog carries six live prediction blocks — `predict_buy` / `predict_sell` (signed actions emitting a
> `SignedOrderIntent`, scope `prediction`), `market_price_below` / `market_price_above` (absolute-odds
> guards), and `prediction_pnl_below` / `prediction_pnl_above` (stake-value TP/SL). The MARKET SYMBOL NAMES
> THE OUTCOME: `"<gamma-market-slug>:<outcome-index>"` —
> use the exact index-aligned symbol returned by live discovery. Named teams/candidates, Over/Under, and
> Yes/No all resolve to distinct ERC-1155 token ids; an outcome-less symbol is refused fail-closed. The engine's
> Polymarket adapter resolves the slug via the venue market API, validates via the pre-trade gate
> (probability bounds, tick grid, pUSD balance, held shares — `preTradeValidate.ts`), Privy-signs the CLOB
> v2 EIP-712 order with the burner key, and POSTs it to the CLOB operator (`clob.polymarket.com` — an API
> endpoint in engine config, NOT a registry role). Addresses are resolved from the registry by role —
> never from this file. New strategy BUYs are limited to standard, non-neg-risk markets with exactly two
> outcomes: that is the market shape whose CLOB exit and binary CTF redemption paths are both implemented.
> Neg-risk and multi-outcome discovery remains readable, but opening new exposure is refused until the v2
> redemption path is implemented. Strategies run on Polygon (137).

## action: place_order
**Function:** SDK `createAndPostOrder(orderArgs, options, orderType)` (or `createOrder(...)` + `postOrder(signedOrder, orderType, postOnly?)`); market variants `createAndPostMarketOrder(...)`. REST: `POST /order` (single; batch `postOrders` max 15). The order is an **EIP-712 `Order`** struct.
**Contract:** role `clob` (off-chain operator) for placement; settled on role `exchange` (standard markets) or `negRiskExchange` (multi-outcome / neg-risk markets).
**Use when:** buying or selling a listed outcome token — a resting limit (`GTC`/`GTD`) or a marketable order (`FOK`/`FAK`).

### params
- `tokenID` — the ERC-1155 outcome-token id to trade. YES and NO are **distinct ids**; "buy NO" = buy the NO token id. Fetch a market's two token ids from the Gamma API (`GET /markets`, each market's `tokens[]`).
- `price` — 0.00–1.00 (the probability/price per share). On a **market order** `price` is a **worst-price/slippage limit**, not a target.
- `size` — number of shares. For a **market BUY** pass `amount` (dollars) instead; for a **market SELL** pass `amount` (shares).
- `side` — `BUY` or `SELL`.
- `options.tickSize` — the market's tick (`"0.1"|"0.01"|"0.001"|"0.0001"`, plus `"0.0025"` for some sports). **Fetch per market** (`getTickSize(tokenID)`); a non-conforming price → `INVALID_ORDER_MIN_TICK_SIZE`.
- `options.negRisk` — bool; **must match the market** (`getNegRisk(tokenID)`) so the order routes to the right Exchange.
- `orderType` — `GTC` (rests), `GTD` (expires; must be ≥3 min out and effectively expires ~1 min early — set `now + 60 + N`), `FOK` (market all-or-nothing), `FAK` (market partial-fill). Post-only: `postOrder(order, GTC, true)`.
- EIP-712 `Order` fields: `maker` (funder), `signer`, `tokenId`, `makerAmount`/`takerAmount` (6-dec fixed math), `side`, `expiration` (unix s), `timestamp` (unix **ms**, uniqueness), `salt`, `signatureType`, `signature`.

### pitfalls
- **Two exchanges:** standard markets settle on `exchange` (`negRisk:false`); multi-outcome events on `negRiskExchange` (`negRisk:true`). Wrong flag → rejected/mis-routed; always read `getNegRisk` per market.
- **Automated lifecycle is standard-binary only:** do not create a new BUY on `negRisk:true` or a market with
  other than two outcomes. The engine refuses it because it cannot yet guarantee automated redemption after
  resolution; existing positions may still be inspected or reduced for recovery.
- **Allowances:** the `funder` must pre-approve the settling Exchange — **pUSD** for BUYs, the **ERC-1155 conditional-token approval** for SELLs. Forgetting either reverts settlement.
- **pUSD, not raw USDC:** collateral is pUSD; USDC.e must be wrapped → pUSD (onramp) before funding. Older integrations referencing raw USDC.e are outdated.
- **Min size is shares, not dollars:** minimum spend is `minimum_order_size × selected outcome price`; below the share threshold → `INVALID_ORDER_MIN_SIZE`.
- **Delayed-entry ceiling:** a market BUY must carry the code-sealed `maxEntryPrice` derived from the verified
  composition quote and slippage band. Recheck immediately before submit and cap the venue worst price at it;
  if the market moved above it while funding/approvals ran, WAIT rather than buying at newly worse odds.
- **Fee-aware minimum:** validate the stake against `minimum_order_size × maxEntryPrice` with fee headroom at
  composition and immediately before submit. If the budget no longer covers the share minimum, WAIT without
  broadcasting; never silently increase the user's all-in spend.
- **Balance reservation:** open orders reserve the whole per-market balance (`maxOrderSize = balance − Σ(open − filled)`); extra same-market orders get rejected.
- **Choose the right exit units:** use `market_price_*` for an absolute outcome probability (for example,
  sell when Team A reaches 75¢). Use `prediction_pnl_*` when the user says take profit / stop loss as a
  percentage of the money committed (for example, +20% / -10%). Position P&L is
  `(idle pUSD + held shares × live midpoint − original stake) / original stake`, so fee reserves and partial
  fills are included. It fails closed until shares exist and currently requires exactly one market-order
  `predict_buy`; resting limit entries are refused so an unfilled remainder cannot keep buying after an exit.
- **`signatureType` must match the wallet** (0 EOA / 1 POLY_PROXY / 2 GNOSIS_SAFE / 3 deposit-wallet 1271) and `funder` must be a deployed Polymarket wallet, or auth fails.
- **Matching delays:** some crypto up/down markets add a 250ms taker delay, sports a longer one; an order **cannot be cancelled while pending in the delay window**.

### safety
- **No reduce-only / no leverage.** To exit: **SELL** the outcome token on the book, or **merge** a full YES+NO set back to pUSD off the book. Max loss = amount paid.
- **Dead-man switches** are the unattended-bot safety net — keep them armed (see `cancel_order`), or stale resting orders persist.
- The operator is trade-only: non-custodial, atomic settlement, cannot move funds or set prices.

## action: cancel_order
**Function:** SDK `cancelOrder(id)` / `cancelAll()` / cancel-by-market / cancel-by-client-id (batch cancel max 1000). Dead-man switches: **Set Auto-Cancel** (cancels all open orders at a set UTC time, ≥5s out) and the **Heartbeat** endpoint (`postHeartbeat(heartbeat_id)`).
**Contract:** role `clob` (off-chain operator).
**Use when:** pulling resting orders, or arming an unattended kill for a bot that could go stale.

### params
- `id` — order id (or client order id / market / asset) to cancel.
- Heartbeat — send with the latest `heartbeat_id` every ~5s; if no valid heartbeat within ~10s (+5s buffer), **all** open orders auto-cancel.

### pitfalls
- A **partially filled** order can't be cancelled — only the unfilled remainder.
- Orders **pending in a matching-delay window cannot be cancelled** until the window passes.
- Heartbeat/auto-cancel wipes **all** open orders when it fires — arm deliberately.

### safety
- Cancels only reduce exposure; always permitted through the kill switch. The heartbeat is the built-in dead-man switch an automated agent should maintain.

## action: split_position
**Function:** `splitPosition(collateralToken, parentCollectionId, conditionId, partition, amount)` on the Conditional Tokens framework, routed through role `collateralAdapter` (which wraps/unwraps USDC.e↔pUSD). **On-chain call**, not a CLOB order.
**Contract:** role `conditionalTokens` via role `collateralAdapter`.
**Use when:** minting a full outcome set — `X` pUSD → `X` YES + `X` NO — to provide liquidity or hold both sides.

### params
- `collateralToken` — pUSD.
- `parentCollectionId` — `bytes32(0)` for a top-level binary market.
- `conditionId` — the market's condition id (`getConditionId(oracle, questionId, outcomeSlotCount)`); the condition must be prepared (`prepareCondition`).
- `partition` — `[1, 2]` for a binary market (YES = index-set 1, NO = 2).
- `amount` — pUSD to split (6 decimals).

### pitfalls
- Approve the `collateralAdapter` for pUSD **once** before splitting.
- A wrong `partition`/`conditionId` mints nothing usable — resolve them from the market metadata, never guess.

### safety
- Splitting is fully collateralized (mints an equal YES+NO pair against locked pUSD); it takes on no directional risk by itself.

## action: merge_positions
**Function:** `mergePositions(collateralToken, parentCollectionId, conditionId, partition, amount)`, routed through role `collateralAdapter`. **On-chain call.**
**Contract:** role `conditionalTokens` via role `collateralAdapter`.
**Use when:** exiting off the book — burn `X` YES + `X` NO back to `X` pUSD (requires an equal amount of both sides).

### params
- Same shape as `split_position` (`collateralToken`, `parentCollectionId`, `conditionId`, `partition=[1,2]`, `amount`).

### pitfalls
- Requires holding **equal** YES and NO amounts; a lopsided position can't be merged — sell the excess on the book first.

### safety
- Merge is a risk-reducing exit that never touches the order book (no slippage, no counterparty) — a clean unwind for a full set.

## action: redeem_positions
**Function:** `redeemPositions(collateralToken, parentCollectionId, conditionId, indexSets)` on the Conditional Tokens framework, via role `collateralAdapter`. **On-chain call, after resolution.**
**Contract:** role `conditionalTokens` via role `collateralAdapter`.
**Use when:** claiming a resolved market — winning tokens pay $1 each in pUSD, losing tokens $0.

### params
- `collateralToken` — pUSD; `parentCollectionId` — `bytes32(0)`; `conditionId` — the resolved market.
- `indexSets` — `[1, 2]` to redeem both outcomes (only the winner pays). **No `amount`** — redeems the caller's *entire* balance for the condition.

### pitfalls
- Redeem burns the **whole** condition balance (no partial); the market must be **resolved** first.
- A **50-50** resolution pays each token $0.50; a "Too Early" resolution can void — read the resolution outcome, don't assume $1/$0.

### safety
- Redemption only pays out; no risk added. There is **no deadline** — winnings can be claimed any time after resolution.

## action: convert
**Function:** `convert(...)` on the **Neg Risk Adapter** (neg-risk / multi-outcome events only). **On-chain call.**
**Contract:** role `negRiskAdapter`.
**Use when:** in a multi-outcome event, converting `1 NO` in one outcome into `1 YES` in every *other* outcome of the same event.

### params
- Event/market identifiers + amount (exact signature not documented in the pages read — resolve from the Neg Risk Adapter ABI before building).

### pitfalls
- Only valid on **neg-risk** markets; only trade *named* outcomes and ignore placeholder/"Other" buckets, whose definition shifts as placeholders are clarified.

### safety
- Resolution risk is external and non-deterministic: UMA's Optimistic Oracle resolves markets (proposer bond, ~2h challenge window, disputes escalate to a 4–6 day DVM vote), and Polymarket can publish clarifications that shift a market's effective rules after entry. An automation must treat resolution timing/outcome as an outside signal, not a controllable step.
