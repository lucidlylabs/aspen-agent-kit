---
section: quant
group: strategies
title: Market making
type: liquidity-provision
triggers: >-
  market making, provide liquidity, quoting, spread capture, maker rebates,
  avellaneda stoikov, inventory management, volume farming
---

# Market making

## Mechanism

Quote both sides. Buy at the bid, sell at the ask, capture the spread. Repeat thousands of times.

The entire business is one trade-off, formalised by Glosten & Milgrom (1985):

```
profit  =  spread captured + rebates  −  adverse selection  −  inventory risk  −  fees
```

**Adverse selection is the cost that defines the business.** Your quotes fill when someone wants to
trade against them, which is disproportionately when they are about to be wrong. You are systematically
buying just before price falls and selling just before it rises. The spread must exceed that.

**Who is on the other side?** Everyone who needs immediacy. That demand is permanent, which is why
market making is a real business rather than an anomaly.

## First, check the arithmetic gate

Before any of the modelling below, run one comparison:

```
median top-of-book spread   vs.   2 × your maker fee
```

If the fee side is larger, spread capture is impossible at any level of skill. This is not a tuning
problem, it is a sign problem.

**The measured reality on liquid crypto perps:** median top-of-book spreads run around
**0.13–0.16 basis points**, and realised gross capture per round trip is smaller still — of order
**0.07–0.12bp** once you account for which fills you actually get. A standard maker fee of **1.5bp**
is therefore roughly **ten times the entire spread**, paid twice.

So on the most liquid markets, classic two-sided spread capture requires a **zero-maker-fee tier at
minimum, and realistically rebates.** Below that, every round trip loses.

Two consequences worth sitting with:

- **The liquid market you have heard of is the one you cannot compete in.** Wide spreads in thin,
  neglected markets are not a warning sign — they are the compensation, and they are where a small
  participant has a real chance.
- **A market-making book can lose money on its market-making leg and still look profitable**, if
  directional beta or carry is quietly covering it. Attribute per sleeve before concluding your
  quoting works. See [../failure-modes.md](../failure-modes.md#5-attribution-failures).

## The reference model

Avellaneda & Stoikov (2008) give the standard framework. Two components:

**Reservation price** — your inventory-adjusted fair value:
```
r = mid − q × γ × σ² × (T − t)
```
where `q` is current inventory, `γ` is risk aversion, `σ` is volatility. **Long inventory pushes your
quotes down**, making you more likely to sell and less likely to buy. This is the core insight and the
thing naive quoting schemes (like grids) lack entirely.

**Optimal spread** — widening with volatility and with order-arrival uncertainty:
```
δ = γσ²(T − t) + (2/γ) ln(1 + γ/k)
```

You do not need to implement this exactly. You need the two behaviours it produces:

1. **Skew quotes against inventory.** Always.
2. **Widen with volatility.** Always.

Those two rules capture most of the model's value and are simple to implement.

## What you must have

- **Inventory management.** A position limit and continuous skew toward flat. Without it, the strategy
  is a random walk in position size that ends at the limit and stays there.
- **Volatility-adaptive spreads.** Fixed spreads are a guarantee of being picked off in fast markets
  and uncompetitive in quiet ones.
- **Fast cancellation.** Your ability to pull quotes on new information is your primary defence. This
  makes cancel latency the most important latency number, more than order-entry latency.
- **A dead-man switch.** Stale quotes in a moved market are free money for others. Hyperliquid's
  scheduled cancel and Polymarket's heartbeat exist for exactly this
  ([../../perpetuals/risk-controls.md](../../perpetuals/risk-controls.md)).
- **Toxicity detection.** When flow turns informed, widen or withdraw. Order flow imbalance and VPIN
  are the standard measures ([../indicators/microstructure.md](../indicators/microstructure.md)).

## Fees are the business model, not a cost

This is the one strategy where the fee schedule is the primary economics rather than a drag.

- **Hyperliquid:** maker 0.015% at base, falling to 0.000% at higher tiers, with **rebates down to
  −0.003%** for high-share makers. At rebate tiers you are paid per fill.
- **Lighter:** Standard is free but latency-penalised — a poor fit, because cancel latency is exactly
  what a maker needs. **Premium is the market-maker tier**: 0.004% maker with no added latency on
  cancels or post-only placements, improving with staked LIT. This is the correct choice.
- **Polymarket:** makers are **never charged**, and a Maker Rebates Program redistributes taker fees to
  makers daily (20–25% of fees by category). Liquidity rewards programs add to this.

**Post-only is mandatory.** A market-making order that crosses the spread has converted your entire
economics from rebate to taker fee, in one fill.

## Where a small participant can actually compete

You will not win on latency against dedicated firms in BTC or ETH perps. What is available:

- **Thin markets that professionals ignore.** Small-cap perps, newly listed markets, HIP-3 builder
  markets. Wider spreads, less competition, and more inventory risk — which is the compensation.
- **Prediction markets.** Polymarket has thousands of markets, most with negligible professional
  presence, permanent zero maker fees, and explicit rebate and liquidity-reward programs. **This is
  the most accessible market-making venue in this kit by a wide margin.** The trade-off is resolution
  risk on inventory and long capital lockup.
- **Incentive programs.** Points, rebates and liquidity mining can dominate the raw spread economics.
  Read the program terms as carefully as the fee schedule.

## Failure modes

1. **Adverse selection exceeding the spread.** The fundamental failure. You are filled on every bad
   trade and missed on every good one. Measured as effective-minus-realised spread
   ([../indicators/microstructure.md](../indicators/microstructure.md#spread)).
2. **Inventory accumulation in a trend.** You buy all the way down. Position limits and skew are the
   defence; without them this is the standard blow-up.
3. **Stale quotes.** Your process hangs, the market moves, you are the only bid. Dead-man switch.
4. **Rate limits during volatility.** You cannot cancel because you have consumed your budget on
   normal-market requoting. **Reserve rate-limit headroom for the emergency path.**
5. **Chasing volume for incentives.** Farming a points program at negative spread economics is paying
   for points. Compute the net.
6. **Self-trading.** Venues have self-trade prevention; understand its mode before quoting both sides
   aggressively.

## The honest assessment

Market making has the most attractive return profile in this kit — high Sharpe, frequent, uncorrelated
to direction — and the highest operational bar. It requires real infrastructure, continuous
supervision, and a correct answer to adverse selection. It is not a strategy you deploy and leave.

But **prediction-market making is a genuine exception**: slow, thin, permanently maker-free, with
programs paying you to be there. If you want to learn this discipline with a realistic chance of
being profitable, that is where to start.
