---
protocol: gains-network
category: perp
chains: [42161, 137, 8453]
archetype: open_perp
executor: knowledge-only
aliases:
  - "long ETH 10x on gtrade"
  - "short BTC on gains network"
  - "open a leveraged trade on gtrade"
  - "market long WETH with USDC on gains"
  - "close my gtrade position"
  - "move my stop loss on gains"
  - "set a take profit on my gtrade long"
roles: [diamond, trading]
actions: [openTrade, closeTradeMarket, updateSl]
tokens: [USDC, DAI, WETH]
---

# Gains Network (gTrade)

Gains Network's **gTrade** is a synthetic-leverage perp DEX settled against Chainlink + a decentralized
oracle. There is no per-pair pool: trades draw from a shared vault (gToken) with a spread/price-impact
model. All trade actions go through the **GNSMultiCollatDiamond** (role `diamond` / `trading`), an
EIP-2535 diamond; collateral is one of the whitelisted tokens (USDC / DAI / WETH), selected by
`collateralIndex`.

> **executor: knowledge-only.** No engine executor runs the `open_perp` archetype yet; the harness will
> `needs_research` a gTrade request until an `open_perp` executor exists. This file is the knowledge that
> executor is built against.

## action: openTrade
**Function:** `openTrade((address user, uint32 index, uint16 pairIndex, uint24 leverage, bool long, bool isOpen, uint8 collateralIndex, uint8 tradeType, uint120 collateralAmount, uint64 openPrice, uint64 tp, uint64 sl, uint192 __placeholder) trade, uint16 maxSlippageP, address referrer)`
**Contract:** role `diamond` (registry: `perp/gains-network/diamond`)
**Use when:** opening a market or limit leveraged position.

### params
- `trade.user` — **MUST be the vault's own address.** The position owner and payout recipient.
- `trade.pairIndex` — the gTrade pair id (e.g. ETH/USD), resolved from the registry by symbol pair.
- `trade.collateralIndex` — the collateral token id (1-based into the whitelisted set); pick the one whose
  token you approve and fund.
- `trade.leverage` — scaled by 1e3 (e.g. 10x = 10000); cap it at the strategy's leverage ceiling.
- `trade.collateralAmount` — in the collateral's decimals; scale from the token book, never a hardcoded 10^n.
- `trade.tradeType` — 0 = MARKET, 1 = LIMIT, 2 = STOP. `trade.tp` / `trade.sl` — take-profit / stop-loss
  prices (1e10 precision), 0 to omit.
- `maxSlippageP` — max slippage in %·1e3; the slippage bound. **Never leave it unbounded.**
- `openPrice` — the desired price for a limit/stop order (1e10); ignored/oracle-set for a market order.

### pitfalls
- Approve `collateralAmount` of the collateral token to the `diamond` first — the approve leg must be in
  the plan or the open reverts.
- `trade.user` ≠ the vault opens a position someone else owns — refuse.
- `leverage`/`tp`/`sl` in the wrong precision mis-sizes or mis-triggers the trade.

### safety
- Cap leverage at the strategy ceiling; gTrade liquidates at a defined loss threshold on the collateral.
- Set `maxSlippageP` from the strategy bound, not permissively — the oracle+impact fill can move against you.

## action: closeTradeMarket
**Function:** `closeTradeMarket(uint32 index, uint16 expectedPrice)`
**Contract:** role `diamond` (registry: `perp/gains-network/diamond`)
**Use when:** market-closing (fully) an open position.

### params
- `index` — the trade index for this pair/user, from the vault's open trades (gTrade indexes trades per
  user per pair).
- `expectedPrice` — the reference close price (1e10) used with the pair's slippage tolerance; derive it
  from a fresh oracle read.

### pitfalls
- Closing the wrong `index` closes a different position — read the live open-trades list, don't guess.

### safety
- Closing reduces risk and needs no new collateral; still price it against the live oracle so the realized
  PnL matches expectation.

## action: updateSl
**Function:** `updateSl(uint32 index, uint64 newSl)`
**Contract:** role `diamond` (registry: `perp/gains-network/diamond`)
**Use when:** tightening a stop-loss on a live position (risk management) without closing it.

### params
- `index` — the open trade's index. `newSl` — the new stop-loss price (1e10 precision), or 0 to clear.

### pitfalls
- A `newSl` on the wrong side of the current price (above entry for a long) is rejected — validate against
  the live mark.

### safety
- Only tighten the stop toward the mark to cap downside; this action never withdraws funds, so it is
  low-risk, but a mis-set stop can prematurely close the position.
