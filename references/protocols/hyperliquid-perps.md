---
protocol: hyperliquid-perps
category: perp
chains: [999]
archetype: open_perp
executor: knowledge-only
aliases:
  - "long BTC 5x on hyperliquid"
  - "short ETH perp"
  - "open a 10x long on SOL with a stop loss"
  - "market buy HYPE perp reduce only"
  - "set leverage to 20x isolated on hyperliquid"
  - "close my hyperliquid perp position"
roles: [venue]
actions: [order, market_open, market_close, modify_order, cancel, cancel_by_cloid, schedule_cancel, update_leverage, update_isolated_margin]
tokens: [USDC]
---
# Hyperliquid Perpetuals
Hyperliquid's perpetuals DEX is a fully on-book, cross/isolated-margin perp venue running on the Hyperliquid L1 (HyperCore), NOT an EVM contract on HyperEVM — it is reached only through signed HTTP API actions to the `/exchange` endpoint, never via a `vault.manage` EVM call. Aspen routes an HL perp leg to the engine's off-chain HL **agent** (an approved API signer), which places/cancels orders on the user's behalf. Margin and settlement are denominated in **perp USDC** (the perp-side USDC balance; move funds in with `usdClassTransfer`). Orders carry an integer **asset id** = the index in the perp `meta.universe`; sizes round to the asset's `szDecimals` and prices to its tick. Leverage is any integer from 1 up to the asset's max (varies per asset), settable per-position as **cross** (shared collateral, max capital efficiency) or **isolated** (collateral fenced to one position). Positions liquidate when account value (incl. unrealized PnL) falls below maintenance margin (currently half the initial margin at max leverage — from 1.25% on 40x assets up to 16.7% on 3x assets); large positions (>100k USDC) liquidate partially (20% tranches) on the book, and below 2/3 of maintenance margin a backstop liquidation via the liquidator vault takes the position (the maintenance margin is not returned). Native TWAP orders exist venue-side: the parent order executes in 30-second suborder intervals, each suborder capped at 3% max slippage.
> **executor: knowledge-only.** Hyperliquid legs run through the Aspen engine's off-chain HL agent (signed API actions), not an EVM `vault.manage`; there is no on-chain address/role. The harness routes an HL request to the engine's DSL path. This file is the knowledge that path is built against.
## economics: trading costs, and why a high-churn strategy usually loses
Fees on Hyperliquid are small per fill and **ruinous in aggregate** once a strategy re-enters often. This is the
single most common way a plausible-sounding automated strategy is a guaranteed loser before its signal is even
evaluated, so **quantify it for the user BEFORE they deploy** — never let them find out from the P&L.
**The schedule.** Base tier is **0.045% taker / 0.015% maker**, tiered down by 14-day volume (and reduced by
staking / referral discounts). Aspen estimates with the **taker** rate, because an automated entry or exit that
must happen *now* crosses the book — a market open, a TP/SL trigger (trigger orders execute as market by
default), and a flip-close are all takers. A **round trip is two fills**, so budget **~0.09% of notional per
completed trade** at base tier.
**The formula.** Fee drag as a percentage of the user's bankroll per day:
```
daily fee % ≈ trades_per_day × 2 fills × (position size as % of equity) × leverage × taker_fee
```
Leverage multiplies it: fees are charged on **notional**, not on margin, so 10x leverage costs 10x the fees for
the same bankroll.
**Trades per day, for a candle-driven strategy** — a strategy that acts on every close:
| interval | 1m | 5m | 15m | 1h | 4h | 1d |
|---|---|---|---|---|---|---|
| candles/day | 1440 | 288 | 96 | 24 | 6 | 1 |
**Worked example (a real case).** "Flip long/short on every 15m candle, 10x, 10% of the account per trade":
`96 × 2 × 0.10 × 10 × 0.00045 ≈ 8.6% of bankroll per day, in fees alone.` On a $30 bankroll that is ~$2.58/day,
charged whether the signal wins or loses. To merely break even the edge must exceed ~8.6%/day — far above what a
red/green candle heuristic delivers. A per-minute flip on the same settings costs ~130%/day: mathematically
certain ruin.
**Funding is separate and additive.** Perp funding accrues hourly against the position; a directional carry of a
few bp/hour is another ~1%/day at 10x. Quote it alongside fees when the user is holding, not just flipping.
**How to advise.** Compute the number and say it plainly — "this pays ~X%/day in fees regardless of whether it
wins" — then name the levers that actually move it: **lower leverage** (linear), **fewer trades / a longer
candle interval** (linear), **smaller size per trade** (linear), or **maker/resting entries** (~3x cheaper per
fill, but they may not fill). This is a WARNING, never a refusal: state the cost honestly and let the user
decide. Aspen's composer already emits this estimate for the `candle_reversal` archetype
(`compose/candleReversal.ts` `candleReversalWarnings`); the same arithmetic applies to any re-entering strategy —
grid, scalping, momentum flips, DCA on short intervals.
**HIP-3 builder DEXes** may add a builder fee on top of the venue fee (the `builder` order tag,
`{b:address, f:fee_tenths_bp}`), so a builder-market strategy is never cheaper than the same core-market one.
## action: order
**Function:** `order(name, is_buy, sz, limit_px, order_type, reduce_only=False, cloid=None, builder=None)` (python SDK `exchange.py`); wire action `{type:"order", orders:[{a,b,p,s,r,t,c}], grouping}` (`exchange-endpoint`)
**Contract:** role `venue` (off-chain — no registry address)
**Use when:** opening or resting a perp order — a limit at a price, or a marketable IOC. For a plain "market long/short" prefer `market_open`.
### params
- `name` — coin/asset (string ticker → resolved to perp asset id = index in `meta.universe`).
- `is_buy` — true = long, false = short.
- `sz` — position size in the coin's units; **rounds to `szDecimals`**.
- `limit_px` — limit price; **rounds to the asset tick**. For a marketable order pass an aggressive px with an Ioc tif.
- `order_type` — `{"limit":{"tif":"Gtc"|"Ioc"|"Alo"}}` (Gtc rests, Ioc immediate-or-cancel, Alo post-only/add-liquidity-only) OR `{"trigger":{"triggerPx":str,"isMarket":bool,"tpsl":"tp"|"sl"}}` for stop/TP orders.
- `reduce_only` — true = may only shrink an existing position, never flip it.
- `cloid` — optional 128-bit hex client order id (for `cancel_by_cloid`).
- `builder` — optional `{b:address, f:fee_tenths_bp}` builder-fee tag (must be pre-approved via `approve_builder_fee`).
### pitfalls
- Order **size rounds to `szDecimals`** and price to the tick — un-rounded values are rejected.
- TP/SL are separate **trigger** orders (`grouping:"normalTpsl"|"positionTpsl"`), not a field on the entry order; they execute as market orders by default (a limit px and a partial position size are configurable).
- `reduce_only` on a size larger than the open position clamps to the position; it never opens the opposite side.
- The **agent must be approved with a NON-EMPTY name** (`approve_agent(name)`) or HL rejects its actions. Docs: an account may hold 1 unnamed + up to 3 named agents (+2 named per subaccount); a named approval's `valid_until` expiry can be at most 180 days out.
- Margin lives on the **perp** side — deposit/convert via `usdClassTransfer(toPerp=true)` first; a spot-only USDC balance can't margin a perp.
### safety
- Kill switch is enforced at the engine's single execution chokepoint (`LiveExecutor.__init__`); a killed strategy places no orders.
- The HL agent is **trade-only** — it can place/cancel orders for the user's account but can never withdraw or move funds off the venue.
- Per-user isolation: one user's agent trades only that user's HL account; manual orders default to `mode:"paper"` until promoted.
## action: market_open / market_close
**Function:** `market_open(name, is_buy, sz, px=None, slippage=0.05, cloid=None, builder=None)` and `market_close(coin, sz=None, px=None, slippage=0.05, cloid=None, builder=None)` (`exchange.py`)
**Contract:** role `venue` (off-chain)
**Use when:** immediate market entry/exit. `market_close` with `sz=None` reads and closes the full current position.
### params
- `slippage` — max slippage as a fraction (default **0.05 = 5%**); the helper computes an aggressive Ioc limit px from the mark.
- `sz` — omit on `market_close` to close 100% of the open position.
### pitfalls
- Slippage default is 5% — set it tighter for thin markets or you may fill far from mark.
### safety
- Same engine kill switch + trade-only agent as `order`.
## action: update_leverage / update_isolated_margin
**Function:** `update_leverage(leverage, name, is_cross=True)` (wire `{type:"updateLeverage", asset, isCross, leverage}`); `update_isolated_margin(amount, name)` (wire `{type:"updateIsolatedMargin", asset, isBuy, ntli}` — `ntli` is a 6-decimal micro-USD integer, `1000000` = $1) (`exchange.py`, `exchange-endpoint`)
**Contract:** role `venue` (off-chain)
**Use when:** setting per-asset leverage/margin mode before or between orders.
### params
- `leverage` — integer 1..maxLeverage(asset).
- `is_cross` — true = cross margin (shared collateral), false = isolated (fenced to this asset).
- `amount` (isolated only) — USDC margin to add/remove on the isolated position.
### pitfalls
- Leverage is **per asset**, not global; changing it does not close positions but affects liquidation price immediately.
- Isolated margin can be removed (unless "strict isolated", where margin cannot be removed and is proportionally released as the position closes); over-removal raises liquidation risk.
### safety
- A leverage change is a config action, not fund movement; still gated by the engine and never touches vault custody.
## action: cancel / schedule_cancel
**Function:** `cancel(name, oid)`, `cancel_by_cloid(name, cloid)`, `schedule_cancel(time)` (`exchange.py`)
**Contract:** role `venue` (off-chain)
**Use when:** pulling resting orders; `schedule_cancel` is a dead-man switch that cancels ALL open orders at a UTC-ms time (at least 5s out).
### params
- `oid`/`cloid` — order id or client order id to cancel.
- `time` — UTC millis, at least 5s in the future.
### pitfalls
- `schedule_cancel` cancels **all** open orders when it fires — arm it deliberately. Max 10 triggers per day, count reset at 00:00 UTC.
### safety
- Cancels only reduce exposure; always permitted through the kill switch.
