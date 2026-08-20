---
section: prediction-markets
title: Prediction-market fees and the p(1−p) curve
kind: economics
docs: >-
  https://docs.polymarket.com/trading/fees ;
  https://hyperliquid.gitbook.io/hyperliquid-docs/trading/fees
triggers: >-
  polymarket fees, prediction market fees, taker fee, maker rebate,
  cost of a bet, break even move, longshot cost
---

# Prediction-market fees and the `p(1−p)` curve

Polymarket's fee is not a flat percentage, and treating it as one will make you wrong at every price
except one. The structure has real strategic consequences — it changes which prices are worth trading
and which exit route you should use.

**Source:** docs → *Trading → Fees*, and *Market Data → Market Details* for a specific market's fee
parameters. Read the rate from the market, not from this table.

## The formula

```
fee = C × feeRate × p × (1 − p)
```

`C` = shares traded, `p` = price per share. **Makers are never charged. Only takers pay.** The fee is
applied by the protocol at match time; you do not include it in your order.

Rates are set per market category:

| Category | Taker rate | Maker rebate share |
|---|---|---|
| Crypto | 0.07 | 20% |
| Sports | 0.05 | 15% |
| Economics, Culture, Weather, Other | 0.05 | 25% |
| Finance, Politics, Mentions, Tech | 0.04 | 25% |
| **Geopolitics / world events** | **0 — fee-free** | — |

Collected fees fund the **Maker Rebates Program**, redistributed daily; there is also a tiered
**Taker Rebate Program**. There is no Polymarket fee to deposit or withdraw.

## What the curve actually does

Rewrite the fee three ways and the strategy implications fall out.

**Per share:** `feeRate × p × (1−p)` — maximal at `p = 0.50`, symmetric around it. A trade at 30¢
costs exactly the same in dollars as a trade at 70¢.

**As a fraction of capital deployed:** notional is `C × p`, so

```
fee / notional = feeRate × (1 − p)
```

This falls monotonically as price rises. **The fee taxes cheap shares hardest.**

| Price | Crypto (0.07) | Politics (0.04) |
|---|---|---|
| $0.01 | 6.93% of notional | 3.96% |
| $0.10 | 6.3% | 3.6% |
| $0.30 | 4.9% | 2.8% |
| $0.50 | 3.5% | 2.0% |
| $0.70 | 2.1% | 1.2% |
| $0.90 | 0.7% | 0.4% |

**As a fraction of maximum payout** (`C × $1`): `feeRate × p × (1−p)`, peaking at `feeRate / 4` at
even odds.

## Three consequences that should change what you do

**1. The fee structure reinforces the favorite-longshot bias.**

Betting markets have a durable, well-documented tendency to overprice longshots and underprice
favorites (Thaler & Ziemba 1988; Wolfers & Zitzewitz 2004). Here the fee *compounds* it from the
other side: buying a 5¢ longshot costs you ~6.7% of stake in fees on a crypto market, while buying a
95¢ favorite costs ~0.35%. The instrument that is already statistically overpriced is also the
expensive one to buy.

The natural expression is therefore to be **structurally a seller of longshots and a buyer of
favorites** — which is also the side the fee is cheapest on. Verify the bias empirically on resolved
markets before trading it ([polymarket-data.md](polymarket-data.md#calibration-the-dataset-that-makes-this-venue-special));
its size varies by category and it is not always present.

**2. The break-even move is large near 50¢, and it is measured in cents.**

For a taker round trip near price `p`, gross profit per share must clear:

```
required move ≈ 2 × feeRate × p × (1 − p)
```

| Price | Crypto (0.07) | Politics (0.04) |
|---|---|---|
| $0.50 | 3.5¢ (7% relative) | 2.0¢ (4%) |
| $0.30 | 2.9¢ (10% relative) | 1.7¢ (6%) |
| $0.10 | 1.3¢ (13% relative) | 0.7¢ (7%) |

A crypto market at even odds needs a **3.5-cent** move to break even on a taker round trip. Short-term
scalping of mid-priced crypto event markets is close to arithmetically hopeless — the same conclusion
the turnover model reaches for perps ([../perpetuals/fees.md](../perpetuals/fees.md)), arrived at from
a different direction.

**3. You can trade this venue at zero explicit fees, and most people don't.**

Makers pay nothing. And the exit routes that are **not** order-book trades are not taker trades:

- **Redeem** after resolution — an on-chain call, no fee.
- **Merge** a full YES+NO set back to collateral — an on-chain call, no fee, no spread, no slippage,
  no counterparty.

So the cost-minimising playbook is: **enter with a resting (maker) order, exit by holding to
resolution or by merging.** That path pays no explicit Polymarket fee at all. What you pay instead is
patience and fill uncertainty — a resting order may never fill, and holding to resolution means
accepting resolution risk you cannot exit.

That is the real trade-off on this venue, and it is a much more interesting one than "what is the fee
rate".

## Hyperliquid HIP-4

Different structure again: **fees are charged only on close, burn, or settlement — opening is free.**
Maker orders pay zero and there are no rebates. Settlement charges against `settle_fraction × size`.

The practical difference from Polymarket: on Polymarket, holding to resolution avoids the exit fee
entirely; on HIP-4, settlement *is* a fee event, so there is no fee saving from holding to expiry.
Details in [hip4.md](hip4.md#fees-are-backwards-deliberately).

## Modelling checklist

- Read `feeRate` from the market's own parameters, per category. Never hardcode.
- Apply the fee to **takers only**. If your backtest charges makers, it understates maker strategies
  badly.
- Apply `p(1−p)` scaling per fill at that fill's price. A flat bp assumption misprices every trade.
- Model the exit route you will actually use — book sale, merge, or redemption — because two of the
  three are free.
- Geopolitics markets are fee-free; a strategy tested on them does not transfer to crypto markets
  without re-running the cost model.
