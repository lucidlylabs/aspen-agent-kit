---
section: quant
group: risk
title: Risk management and operational controls
triggers: >-
  risk management, drawdown limit, kill switch, max loss, circuit breaker,
  portfolio risk, correlation risk, operational risk, monitoring, controls
---

# Risk management and operational controls

Sizing decides how much you bet ([position-sizing.md](position-sizing.md)). This is everything else:
the limits, the automatic responses, and the operational failures that lose money without any market
move at all.

**The organising principle: every control must be code that executes without you.** A limit you have
to remember is not a limit. A strategy that requires supervision to be safe is unsafe, because
supervision fails exactly when markets are most active.

## The limit hierarchy

Set these top-down, and enforce every one in code:

| Level | Limit | Enforcement |
|---|---|---|
| **Account** | Maximum total notional; maximum aggregate leverage | Pre-trade check on every order |
| **Account** | Maximum daily loss → flatten and halt | Continuous, against realised equity |
| **Account** | Maximum drawdown from high-water mark → halt and require manual restart | Continuous |
| **Strategy** | Capital allocation; maximum positions | Pre-trade |
| **Market** | Maximum position per market; maximum share of book depth | Pre-trade |
| **Factor** | Maximum exposure per underlying risk factor | Aggregated across instruments |
| **Position** | Stop loss; liquidation-distance floor | Server-side where possible |

The daily-loss and drawdown halts are the two that matter most, and they are the two most often
omitted because they feel pessimistic. They are the difference between a bad week and a terminal one.

## Portfolio risk: the correlation trap

The most common serious error, and it is not subtle:

**Crypto assets converge toward correlation 1 in stress.** A portfolio of ten perp longs looks
diversified in calm markets and behaves as one leveraged position in a drawdown. Sample correlation
computed over a quiet period tells you nothing about the moment you need it.

Practical responses:

- **Compute correlation in stress periods specifically**, not over the full sample. Size on that.
- **Aggregate exposure by risk factor.** For crypto perps, most of the variance is one factor (call it
  "crypto beta"). Measure your portfolio's net beta to BTC and limit it explicitly — a "market-neutral"
  book with a net beta of 0.6 is a directional position.
- **Count correlated positions as one** for limit purposes. Ten markets on one election is one bet.
- **Stress test.** What happens to the whole book if BTC drops 20% in an hour and every correlation
  goes to 1? If the answer is liquidation, you are too big regardless of what the sizing model said.

## Tail risk

Crypto tails are fat, and standard risk measures understate them systematically.

- **VaR tells you a threshold, not a magnitude.** "5% chance of losing more than X" says nothing about
  how much more. **Use expected shortfall (CVaR)** — the average loss *given* you are in the tail —
  which is what actually determines survival.
- **Use empirical quantiles from your own data**, not Gaussian assumptions. And ensure your sample
  contains at least one violent regime; a dataset with no crash cannot inform your tail estimate.
- **Model the reflexive case.** In crypto, a large move triggers liquidations that force market orders
  that extend the move. Your stop and the market's liquidation cascade are correlated: you will be
  filled at the worst prices precisely when you most need out. Assume slippage several times your
  normal estimate in a stress exit.
- **Assume the hedge fails.** In a cross-venue trade, model the case where one leg is liquidated and
  the other is not.

## Operational risk — where the money actually goes

Market risk is what people plan for. These are what actually cause losses in automated systems:

| Failure | Control |
|---|---|
| Process dies with position open | **Server-side stops.** A stop in your bot's memory does not exist. |
| Process dies with orders open | **Dead-man switch** — Hyperliquid scheduled cancel, Polymarket heartbeat. Arm it always. |
| Duplicate orders on retry | **Idempotency via client order ids.** Never retry blindly. |
| Treating HTTP 200 as a fill | **Confirm on the account stream.** All three venues can accept then reject. |
| Rate limit hit during volatility | **Reserve headroom for cancels.** Never budget the limit to be fully used by normal operation. |
| Stale data driving decisions | **Fail closed.** No fresh mark within N seconds → place nothing. |
| Nonce desync (Lighter) | **Separate API keys per order type.** A rejected taker still consumes a nonce. |
| Key compromise | **Trade-only, non-withdrawal credentials.** Available on all three venues; there is no reason a bot can withdraw. |
| Wrong decimals / scaling | **Validate against live metadata at startup and assert on every order.** This is a total-loss bug class. |
| Config change deployed live | **Kill switch + staged rollout.** One chokepoint every order passes through. |
| Silent strategy drift | **Reconcile positions against the venue continuously**, not from your own model of what you did. |

## The kill switch

One function, in your code, that every order passes through, that can be turned off without a deploy.

It should trigger automatically on: daily loss limit, drawdown limit, data staleness, reconciliation
mismatch between your position model and the venue's, an unexpected exception rate, or an explicit
manual flag.

**When it fires, the correct behaviour is: cancel all orders, stop opening, and alert.** Whether it
also flattens positions is a decision to make deliberately in advance — flattening into a crisis is
itself expensive.

## Monitoring: what to actually watch

Not PnL. PnL is the slowest and noisiest signal you have.

- **Reconciliation** — your position model vs the venue's, continuously. Any mismatch is an emergency.
- **Fill quality** — implementation shortfall and effective spread vs your backtest assumptions. Drift
  here means your model is wrong before your PnL says so.
- **Rejected/failed orders** — a rising rate means something structural changed.
- **Data freshness and feed latency** — event time vs receive time.
- **Margin ratio and liquidation distance** per venue, per position.
- **Realised vs expected funding** on carry trades.
- **Strategy behaviour vs backtest distribution** — trade frequency, holding period, win rate. If live
  trade count is double the backtest, something is different and you should find out what before
  looking at returns.

## The pre-deployment checklist

Before any strategy runs with money:

1. Costs modelled: fees, spread, slippage from real book snapshots, funding over the hold.
2. Backtest survives [../validation/backtesting.md](../validation/backtesting.md).
3. Sizing is volatility-scaled with a hard floor rule.
4. Every limit above is implemented and **tested by asserting the failure case**.
5. Server-side stops and a dead-man switch are armed.
6. Credentials are trade-only.
7. Kill switch exists and has been triggered in a test.
8. Paper traded against live books (Lighter's official kit does this) or run at minimum size first.
9. Reconciliation and monitoring are running *before* the strategy is.
10. You have written down what would make you turn it off — in advance, in specifics.

Point 10 is the one that gets skipped and the one that matters. Decide the exit criteria while you are
calm.
