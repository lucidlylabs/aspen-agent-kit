---
section: perpetuals
title: Perp risk controls
kind: risk
triggers: >-
  liquidation price, margin mode, cross vs isolated, maintenance margin, ADL,
  stop loss, reduce only, dead man switch, kill switch, risk limits, position limits
---

# Perp risk controls

Leverage is a credit facility. The venue lends you notional against collateral and reserves the right
to close you out when the collateral stops covering the risk. Every control below exists because that
close-out is not negotiable and not gradual.

## The liquidation cascade, and where you sit in it

The general shape is the same on both venues; the parameters are not, and must be read live.

1. **Healthy.** Account value (including unrealised PnL) exceeds the initial margin requirement.
2. **Pre-liquidation.** Account value has fallen below initial margin. You typically cannot increase
   risk — only health-improving actions are permitted. This state is a warning you can act on.
3. **Partial liquidation.** The engine cancels your orders and starts closing the position on the
   book, usually in tranches. On Hyperliquid, large positions liquidate partially rather than all at
   once. On Lighter this stage feeds an insurance fund (LLP) and can charge a fee.
4. **Full liquidation / backstop.** A liquidator vault or insurance fund takes the position over.
   **On Hyperliquid, below roughly 2/3 of maintenance margin the backstop takes it and the
   maintenance margin is not returned to you.** That is a discontinuity: your loss is not a smooth
   function of the price move.
5. **Auto-deleveraging (ADL).** If the insurance mechanism cannot absorb it, profitable traders on
   the other side get closed out at the bankruptcy price. You can be ADL'd while *right*. Any
   strategy assuming a hedge leg stays open through a violent move must account for this.

**Everything triggers on mark price, not last trade.** A wick that never touches the mark does not
liquidate you; a mark that moves without prints does. Backtests that use trade prices for stop and
liquidation logic systematically misstate both.

## Margin mode is a blast-radius decision

- **Cross margin** shares collateral across all positions. Most capital-efficient, and the reason a
  single bad position can take the whole account. Correlated positions in cross margin are not
  diversification — they are one position wearing several tickers.
- **Isolated margin** fences collateral to one position. You lose at most that allocation. The right
  default for anything experimental, anything on a builder-deployed or thin market, and anything you
  are not watching.

For a portfolio of strategies, isolated-per-strategy is usually correct even though it costs capital
efficiency. The alternative is that strategy A's drawdown liquidates strategy B's working position.

## Sizing to a liquidation distance, not to a leverage number

The useful question is never "what leverage?" It is **"how far can price move against me before I am
forced out, and how does that compare to this asset's normal movement?"**

```
approximate liquidation distance ≈ (1 / leverage) − maintenance_margin_rate
```

At 10× with a 2.5% maintenance rate you have roughly 7.5% of room. If the asset's daily volatility is
5%, a 1.5-sigma day ends the position. Compute the distance in **units of realised volatility** (see
[../quant/indicators/volatility.md](../quant/indicators/volatility.md)) and set leverage from that,
not from a round number that felt reasonable.

Note the interaction with maintenance margin tiers: on both venues the maintenance requirement rises
with position size, so scaling up a position moves your own liquidation price against you.

## The control surface

These are the primitives. Use all of them; each covers a failure the others do not.

| Control | What it protects against |
|---|---|
| **`reduce_only`** | The close order that accidentally opens the opposite side. It clamps to the position and can never flip it. Every exit path should set it. |
| **`post_only` / ALO** | Paying taker fees by accident, and crossing the spread on what you intended as a passive quote. Rejects rather than crossing. |
| **Isolated margin** | One position taking the account. |
| **Server-side stop / TP** | Your process dying while a position is open. A stop that lives only in your bot's memory does not exist. |
| **Dead-man switch** | Your process dying while *orders* are open. Hyperliquid's scheduled cancel and Polymarket's heartbeat both auto-cancel everything if you stop checking in. Arm it for any unattended system. |
| **Scoped API key** | Key compromise becoming fund loss. Trade-only keys that cannot withdraw are available on all three venues. Use them. There is no reason a trading bot holds withdrawal authority. |
| **Local kill switch** | Everything else. One chokepoint in your own code that every order passes through and that can be flipped off without a deploy. |

## The controls that must be code

A control that depends on an LLM deciding correctly in the moment is not a control. These belong in
deterministic code with tests, and the tests should assert the *failure* case:

- **Maximum position size and maximum leverage**, checked before every order.
- **Maximum daily loss**, after which the system flattens and stops. Enforced against realised equity,
  not against a model's opinion.
- **Liquidation-distance floor.** Refuse any order that would put the liquidation price inside N
  volatility units.
- **Sign conventions on hedged legs.** A sign error in a delta-neutral position silently converts a
  carry harvest into paying the carry with double the exposure. This is the highest-frequency
  catastrophic bug in perp strategies and it must fail at test time, not at runtime.
- **Order-size sanity vs book depth.** Refuse an order larger than a set fraction of visible depth.
- **Stale-data refusal.** If the last mark update is older than N seconds, place nothing. Fail closed.

## Operational failure modes specific to these venues

- **HTTP 200 means accepted, not executed.** Both Hyperliquid and Lighter can accept an order at the
  API layer and reject it downstream. Confirm fills on the account/order WebSocket channel. Any
  system that treats a 200 as a fill will eventually double-size a position.
- **Nonce desynchronisation on Lighter** — a rejected taker order still consumes the nonce. Separate
  keys per order type.
- **Builder-market oracle risk on HIP-3.** The deployer controls the oracle and can settle or delist.
  Position limits on builder markets should be a fraction of what you would run on a first-party one.
- **Rate limits are a risk control you did not choose.** Hitting them during a fast move means you
  cannot cancel. Reserve headroom for the emergency path — never budget your rate limit to be fully
  consumed by normal operation.
- **Funding is charged on a schedule you do not control.** A position held across the funding
  timestamp pays it; a strategy that flips frequently may pay funding on both sides.

See [../quant/risk/position-sizing.md](../quant/risk/position-sizing.md) for how much to bet, and
[../quant/risk/risk-management.md](../quant/risk/risk-management.md) for portfolio-level control.
