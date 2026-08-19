---
protocol: gmx-v2
category: perp
chains: [42161, 43114]
archetype: open_perp
executor: knowledge-only
aliases:
  - "long ETH 5x on gmx"
  - "short BTC on gmx"
  - "open a leveraged perp on gmx"
  - "increase my ETH position on gmx"
  - "close my gmx position"
  - "market long WETH with USDC collateral"
  - "add margin to my gmx short"
roles: [router, exchangeRouter]
actions: [sendWnt, sendTokens, createOrder, multicall]
tokens: [USDC, WETH, WBTC]
---

# GMX v2

GMX v2 is an oracle-priced perpetuals + spot exchange. Positions are opened by creating an **order** that
keepers execute against a Chainlink/GMX oracle price on the next block. All calls go through the
**ExchangeRouter** (role `exchangeRouter`); token pull-ins are authorized against the shared **Router**
(role `router`, the approval target). The canonical flow is a single **`multicall`** that atomically
(1) pays the native execution fee, (2) transfers collateral into the order vault, and (3) creates the
order — the three legs below are the members of that batch.

> **executor: knowledge-only.** No engine executor runs the `open_perp` archetype yet; the harness will
> `needs_research` a GMX request until an `open_perp` executor exists. This file is the knowledge that
> executor is built against.

## action: multicall
**Function:** `multicall(bytes[] calldata data) returns (bytes[] results)`
**Contract:** role `exchangeRouter` (registry: `perp/gmx-v2/exchangeRouter`)
**Use when:** opening, increasing, or decreasing a position — it bundles `sendWnt` + `sendTokens` +
`createOrder` into one atomic transaction (the way every GMX v2 position action is submitted).

### params
- `data` — the ABI-encoded calls to the other actions on this same contract, in order:
  `sendWnt` (execution fee, and WETH collateral if native), then `sendTokens` (ERC20 collateral),
  then `createOrder`. Ordering matters: the vault must be funded before `createOrder` reads it.

### pitfalls
- The transaction's `msg.value` must equal the total native sent by the inner `sendWnt` leg(s)
  (execution fee + any native collateral). A mismatch reverts the whole multicall.
- Do not split the legs across separate transactions — collateral left in the order vault between txs
  is sweepable by anyone.

### safety
- Every inner call target is this one contract; a leg addressed elsewhere is malformed — refuse.

## action: sendWnt
**Function:** `sendWnt(address receiver, uint256 amount)`
**Contract:** role `exchangeRouter` (registry: `perp/gmx-v2/exchangeRouter`)
**Use when:** paying the keeper **execution fee** (and, for a native-ETH position, the WETH collateral)
into the order vault as the first leg of the multicall.

### params
- `receiver` — the **OrderVault** for the order type (deposit/withdraw/order vaults differ). Resolve it
  from the registry; never a user-supplied address.
- `amount` — the wrapped-native amount; must cover the current `executionFee` (a keeper-reimbursement,
  refunded to the position `receiver` on execution) plus any native collateral.

### pitfalls
- Underpaying `executionFee` leaves the order un-executable until topped up; overpay slightly and take
  the refund rather than risk a stuck order.

### safety
- The `amount` here is part of `msg.value`; it must reconcile with the outer transaction value exactly.

## action: sendTokens
**Function:** `sendTokens(address token, address receiver, uint256 amount)`
**Contract:** role `exchangeRouter` (registry: `perp/gmx-v2/exchangeRouter`)
**Use when:** moving ERC20 collateral (e.g. USDC) into the order vault before `createOrder`.

### params
- `token` — the collateral token, resolved from the token book by symbol.
- `receiver` — the **OrderVault**, from the registry.
- `amount` — in the token's decimals; scale from the token book, never a hardcoded 10^n.

### pitfalls
- Approve `token` to the `router` (registry: `perp/gmx-v2/router`) first — GMX pulls collateral via the
  shared Router, not the ExchangeRouter. The approve leg must be in the plan.
- Sending collateral without a matching `createOrder` in the same multicall abandons it in the vault.

### safety
- Approve exactly `amount`, not unlimited; the Router is a long-lived pull target.

## action: createOrder
**Function:** `createOrder((( address receiver, address cancellationReceiver, address callbackContract, address uiFeeReceiver, address market, address initialCollateralToken, address[] swapPath), (uint256 sizeDeltaUsd, uint256 initialCollateralDeltaAmount, uint256 triggerPrice, uint256 acceptablePrice, uint256 executionFee, uint256 callbackGasLimit, uint256 minOutputAmount), uint8 orderType, uint8 decreasePositionSwapType, bool isLong, bool shouldUnwrapNativeToken, bool autoCancel, bytes32 referralCode) params) returns (bytes32)`
**Contract:** role `exchangeRouter` (registry: `perp/gmx-v2/exchangeRouter`)
**Use when:** the final leg — describing the position change (open/increase = MarketIncrease,
close/reduce = MarketDecrease).

### params
- `receiver` — **MUST be the vault's own address.** This is who owns the position and receives payout/refund.
- `market` — the GM market address, resolved from the registry by symbol pair (e.g. ETH/USD).
- `initialCollateralToken` — the collateral just sent; `isLong` — long/short direction.
- `sizeDeltaUsd` — position size in **USD, 30 decimals** (GMX's price precision), not token decimals.
- `acceptablePrice` — the worst fill price you accept; the slippage bound (also 30-decimal price). Derive
  it from a fresh oracle read and the max-slippage bound; **never leave it wide open.**
- `orderType` — 2 = MarketIncrease, 4 = MarketDecrease (limit/stop variants differ).

### pitfalls
- `receiver` other than the vault sends the position and all payouts to a third party — refuse.
- `acceptablePrice` set permissively is an unbounded-slippage entry — floor/cap it from the oracle price.
- `sizeDeltaUsd` in the wrong precision (token decimals instead of 30) mis-sizes the position by orders of
  magnitude.

### safety
- Cap effective leverage (`sizeDeltaUsd` / collateral value) at the strategy's leverage ceiling; an
  over-levered position liquidates on a small adverse move.
- A MarketDecrease that closes more than the open size, or draws collateral below maintenance margin,
  risks liquidation — size the reduction against the live position.
