---
section: quant
group: strategies
title: Prediction-market strategies
type: mixed
triggers: >-
  prediction market strategy, polymarket strategy, event trading, calibration
  edge, cross venue outcome arb, event gated trade, longshot
---

# Prediction-market strategies

Binary payoffs, bounded prices, and a hard resolution date make this a different game. The good news:
it is the most *learnable* market in this kit, because every resolved market is a labelled data point.

## 1. Calibration edge (forecasting)

**Mechanism:** you have a better probability estimate than the market.

```
edge = your_probability − price − cost
```

This is the purest form and the hardest. It requires genuine forecasting skill in a domain, and it
requires you to be honest about whether you have it.

**How to know if you do:** track your forecasts with a proper scoring rule (log score, Brier) *before*
trading them ([../indicators/prediction-markets.md](../indicators/prediction-markets.md#calibration--the-fundamental-measurement)).
Scores converge far faster than PnL does. If your log score does not beat the market price as a
forecast over a hundred markets, you do not have this edge, and you have learned that cheaply.

**Where individuals plausibly have it:** narrow domains with genuine expertise and low professional
attention. Not elections, not major crypto markets.

## 2. Favorite-longshot / structural bias

**Mechanism:** longshots are systematically overpriced (Thaler & Ziemba 1988; Wolfers & Zitzewitz
2004), and on Polymarket the fee structure taxes cheap shares hardest, compounding it
([../../prediction-markets/fees.md](../../prediction-markets/fees.md)).

**Implementation:** systematically sell longshots / buy favorites, across many markets, sized small.

**The warning that matters:** this has a **negative-skew payoff** — many small wins, rare large
losses. It is the profile that looks brilliant for twelve months and then gives it all back. Size it
accordingly, cap correlated exposure, and never lever it.

**Verify before trading.** Measure the bias yourself on resolved markets by category
([../../prediction-markets/polymarket-data.md](../../prediction-markets/polymarket-data.md#calibration-the-dataset-that-makes-this-venue-special)).
In liquid markets it may be gone.

## 3. Cross-venue and intra-market convergence

**The cleanest opportunities in this kit**, because the mechanism is arithmetic rather than
statistical.

- **Same question, two venues.** Polymarket and HIP-4 both listing a question: buy YES on the cheaper
  and NO on the dearer for a combined cost below 1.00. Pays exactly 1.00 on one leg. Use resting
  limits summing below 1, and **equal contract counts**.
- **Within one market.** A full YES + NO set is worth exactly 1. If both sides can be bought for less
  than 1 net of fees, that is a riskless set — and on Polymarket you can **merge** the set back to
  collateral without touching the book at all.
- **Neg-risk events.** In a mutually exclusive multi-outcome event, the outcome prices should sum to
  approximately 1. Deviations are convergence trades, with the caveat that placeholder buckets
  ("Other") make the arithmetic unreliable.

**Constraints:** small, competitive, and bounded by the thinner leg's depth. Also note resolution
correlation — two venues resolving the "same" question may use different criteria, which turns a
riskless arb into a basis bet. **Read both resolution criteria before treating them as identical.**
This is the failure mode that makes this trade less riskless than it looks.

## 4. Event-gated directional trades (prediction market as signal)

**The best combination shape available**, and it uses no prediction-market capital at all.

The event market tells you a probability. You express the view in the instrument with better liquidity
and lower cost — a perp:

- A market on "asset above X by date D" reprices; you take the perp position it implies.
- An event market's probability moves sharply before price does; that is a signal, and prediction
  markets have documented information value (Wolfers & Zitzewitz 2004).
- A macro event market gates whether a directional perp strategy is allowed to run at all.

Why it is clean: no capital locked in an illiquid binary, no resolution risk, no redemption path, and
the position sits on the venue with real depth. On Hyperliquid, HIP-4 and perps share one connection;
on Polymarket, perps and prediction markets share pUSD collateral.

**Requirement:** state the sign and the mechanism first. "If this resolves YES, the perp goes up,
because ___." If you cannot fill in the blank causally, there is no combination, only two bets.

## 5. Market making on event markets

Covered in [market-making.md](market-making.md#where-a-small-participant-can-actually-compete). Zero
maker fees, rebate programs, thousands of neglected markets. The most accessible market making
available to a small participant.

## 6. Time-decay / convergence harvesting

**Mechanism:** as resolution approaches, prices converge toward 0 or 1. Holding a high-probability
contract to resolution earns the remaining spread to $1.

**This is a carry trade with total-loss risk**, and it must be evaluated as such:

```
annualised return = (1 − price) / price × (365 / days_to_resolution)
```

A 0.95 contract resolving in 30 days returns 5.3% over the period — about 64% annualised — with a 5%
chance (if calibrated) of losing everything. That is a reasonable trade *if calibrated* and if sized
for total loss. It is a terrible trade if the market is overpricing favorites in that category, which
is the opposite of the usual bias and does happen.

**Do not confuse locked-up capital with a free return.** The capital cannot be redeployed and cannot
be exited without crossing a thin spread.

## Sizing across all of these

Binary payoffs make Kelly directly applicable:

```
f* = (p × (1 + b) − 1) / b        where b = (1 − price) / price
```

Use a **fraction** of that (a quarter to a half), because your probability estimate has error and
Kelly is extremely sensitive to it ([../risk/position-sizing.md](../risk/position-sizing.md)).
Over-betting a binary with an overconfident probability is the fastest ruin path in this section.

**Aggregate by underlying event, not by market.** Ten markets on one election are one position.

## Universal failure modes

1. **Resolution risk** — right about the world, wrong about the criteria
   ([../../prediction-markets/risk-controls.md](../../prediction-markets/risk-controls.md)).
2. **Liquidity at exit** — being right and unable to sell.
3. **Capital lockup** — the return is not annualised until you annualise it.
4. **Overconfidence in your probability** — the input Kelly is most sensitive to.
5. **Concentration disguised as diversification** — many markets, one event.
