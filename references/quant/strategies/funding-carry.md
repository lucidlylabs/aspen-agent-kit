---
section: quant
group: strategies
title: Funding carry (delta-neutral)
type: carry
triggers: >-
  funding arb, farm the funding spread, delta neutral funding, carry trade,
  collect funding, cross venue funding, funding rate arbitrage
---

# Funding carry (delta-neutral)

## Mechanism

Perp funding is a payment from the crowded side to the unpopular side. If you hold the unpopular side
while hedging away price exposure, you collect the payment and do not care where the price goes.

**Who is on the other side and why do they stay?** Leveraged directional traders who want exposure
more than they mind paying for it. That demand is persistent because it is structural — leverage
demand in crypto is chronically long-biased — which is what makes this the most durable strategy
family available on these venues.

## Constructions

| Form | Long leg | Short leg | Notes |
|---|---|---|---|
| **Spot–perp** | Spot asset | Perp on the same asset | Classic. Needs spot inventory and spot custody. Hyperliquid has native spot. |
| **Cross-venue perp** | Perp where funding is cheap/negative | Perp where funding is rich | No spot needed. **Short the higher-funding venue.** Both legs are perps, so both can be levered. |
| **Cross-representation** | An asset's perp on one DEX | The same underlying on another market | Requires the two to be genuinely the same underlying. |

The cross-venue form is the most practical here: Hyperliquid and Lighter both list the majors, both
publish funding, and neither requires you to hold spot.

## Entry

Enter when the **expected net carry over the intended holding period exceeds all-in costs with
margin to spare.**

```
net carry  =  funding_received_annualised
            − funding_paid_annualised
            − (entry fees + exit fees, both legs, annualised over the hold)
            − expected slippage, both legs
            − borrow/collateral opportunity cost
```

Practical entry conditions:

- **Funding z-score above a threshold**, not a raw rate. Raw thresholds do not port across markets or
  regimes ([../indicators/crypto-native.md](../indicators/crypto-native.md)).
- **Persistence check.** The rate should have been consistently on this side over a meaningful lookback.
  A single rich print is a spike, not a yield.
- **Depth check.** Both legs fillable at your size within your slippage budget. The trade is bounded
  by the thinner leg.
- **The direction of each leg is read from live funding and decided in code.** Never chosen by a
  model, never inferred from a stale snapshot.

## Exit

- **Carry compresses.** The funding spread narrows below the threshold that justified entry, allowing
  for the round-trip cost of re-entering later.
- **Basis divergence guard.** If the two legs' prices diverge beyond a threshold, the "hedge" is not
  hedging. Exit rather than hope.
- **Portfolio PnL guards** on both sides — a take-profit and a stop expressed on the combined
  position, not per leg.
- **Funding flips sign** against you.

## Sizing

Size the **pair**, not the legs. Both legs must be equal in notional (or in delta, if the instruments
are not identical). Compute the size from the thinner leg's depth and from your capital allocation,
then apply it symmetrically.

Leverage on a delta-neutral pair is safer than on a directional position but not safe: each leg can
be liquidated individually if margin is not managed per-venue. **Cross-venue carry has a specific
failure mode: the winning leg's margin does not automatically help the losing leg.** A violent move
can liquidate one side while the other side is deeply profitable and inaccessible. Keep meaningful
margin buffers on both venues, sized to a move well beyond anything you consider likely.

## Failure modes

1. **Sign error.** Shorting the low-funding venue instead of the high one converts the trade into
   paying carry with double exposure. Make it a test failure, with an exhaustive sign table.
2. **Leg liquidation.** Covered above. This is the dominant real-world risk and it is an operational
   problem, not a market one.
3. **Funding regime change.** Rates mean-revert and can flip. The trade is not "set and forget";
   monitor and be willing to exit.
4. **The two legs are not the same underlying.** A perp on a builder-deployed market with its own
   oracle is not necessarily the same asset as the first-party perp, however similar the ticker.
5. **Clamped funding.** On Lighter, if the premium sits inside ±5bp the rate defaults to about 1bp per
   8 hours. A screen that ignores the clamp will predict carry that will not arrive.
6. **Crowding.** Carry trades are crowded precisely when they look best. Unwinds are correlated across
   participants, which means slippage is worst exactly when everyone wants out.
7. **Capital efficiency illusion.** The annualised rate assumes continuous deployment. If you are in
   the trade 40% of the time, your realised return is roughly 40% of the headline.

## Why this is the recommended starting point

- **Nearly fee-insensitive.** Two fills for a hold of days or weeks. The turnover arithmetic that
  kills most strategies ([../../perpetuals/fees.md](../../perpetuals/fees.md)) does not apply.
- **No forecast required.** You are not predicting anything, which removes the largest source of error.
- **The signal is directly observable**, not inferred. You can see exactly what you are being paid.
- **It teaches the right habits**: cost modelling, sign discipline, margin management, and
  cross-venue operations — all of which transfer to everything else.

Its limitation is capacity and rate: carry is usually a modest single-to-low-double-digit annualised
return, and levering it to make that exciting reintroduces the liquidation risk you removed.
