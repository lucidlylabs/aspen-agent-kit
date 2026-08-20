---
section: quant
group: indicators
title: Prediction-market indicators
triggers: >-
  prediction market indicators, probability, calibration, favorite longshot,
  time decay, brier score, log score, implied probability, event market signals
---

# Prediction-market indicators

Prices here live in `(0,1)`, converge to a boundary on a known date, and carry an explicit
probabilistic meaning. **Most chart indicators are a category error in this space.** The right
toolkit is different, and mostly borrowed from forecasting rather than from technical analysis.

## First: the price is a probability, so treat it as one

A contract at 0.30 is a claim that the event happens 30% of the time. That means your edge is
expressible in the only terms that matter:

```
edge = your_probability − market_price − cost
```

You need a probability estimate to trade this at all. If you cannot produce one, you are not trading
a prediction market, you are guessing with extra steps. This is a *feature*: it forces the discipline
that the four questions ([../README.md](../README.md#the-four-questions)) demand.

**Small caveat worth knowing:** the price is not exactly a probability. It is a risk-neutral price,
shaded by the time value of locked capital, by the cost of the collateral, and by participants'
preferences. Over long horizons this matters — a 0.95 contract resolving in a year is not a 95%
probability, because the capital is locked for a year.

## Calibration — the fundamental measurement

**Grade: A.** This is the closest thing to ground truth available in any market.

Bucket historical markets by price; measure the realised frequency of YES in each bucket. A
well-calibrated market has 30¢ contracts resolving YES 30% of the time.

Scoring rules for evaluating your own forecasts:

- **Brier score** = `mean((forecast − outcome)²)`. Lower is better; 0.25 is what you get by always
  saying 50%. Decomposes into calibration + resolution + uncertainty.
- **Log score** = `mean(−ln(probability assigned to the actual outcome))`. Punishes confident errors
  harshly, which is correct — it is the proper scoring rule that corresponds to the growth rate of a
  Kelly bettor.

**Use log score to evaluate a trading model, Brier for intuition.** Track them on your own forecasts
from day one; they will tell you whether you have any edge long before your PnL does, because they
are far less noisy than returns.

## Favorite-longshot bias

**Grade: A as a documented phenomenon, B as a tradable edge today.**

The most durable empirical regularity in betting markets: longshots are systematically overpriced and
favorites underpriced (Thaler & Ziemba 1988; surveyed by Wolfers & Zitzewitz 2004). Bettors overpay
for small chances of large payoffs.

On Polymarket this is **compounded by the fee structure**, which charges a far higher percentage of
notional on cheap shares — `feeRate × (1−p)`
([../../prediction-markets/fees.md](../../prediction-markets/fees.md)). The instrument that is
statistically overpriced is also the one that is expensive to buy.

The implied posture is to be a structural **seller of longshots and buyer of favorites**. Two
warnings:

1. **Measure it on the venue, by category, before trading it.** Magnitude varies enormously, and in
   liquid political markets it may be arbitraged away.
2. **Selling longshots has a terrible payoff profile.** You win small, often, and lose large,
   rarely — the classic pattern that looks brilliant for a year and then is not. Size it as the
   negative-skew strategy it is ([../risk/position-sizing.md](../risk/position-sizing.md)).

## Time to resolution — the dominant variable

**Grade: A.** Nothing else matters as much, and it has no analogue in perps.

- **Probabilities become more extreme as information arrives**, converging to 0 or 1. Under a
  martingale, price is a fair estimate at every moment, but its *variance* shrinks as the date
  approaches.
- **Late-life "momentum" is mostly convergence**, not sentiment. A contract drifting from 0.85 to 0.95
  in the final days is time decay, not a trend to trade.
- **Mean reversion works best mid-range and far from expiry** — roughly 0.20–0.80, with meaningful
  time left — where genuine disagreement still exists and prices can move on noise.
- **Annualise your returns.** A contract at 0.90 offering 11.1% is not comparable to one at 0.60
  offering 66.7% until you divide by time and adjust for total-loss risk. Locked capital is the real
  cost of a prediction-market position, and it does not appear on any fee schedule.

## Liquidity and spread indicators

Because books are thin, these dominate.

- **Spread in cents** is the number that matters, not spread in percent. A 2¢ spread on a 5¢ contract
  is 40%; the same 2¢ on a 90¢ contract is 2.2%.
- **Depth at price** — how many shares you can buy without moving the price more than N cents. Compute
  it for your intended size before forming an opinion about the trade.
- **Volume relative to the market's own history**, not to other markets — attention is extremely
  uneven across a venue with tens of thousands of markets.
- **Tick size relative to price.** A 1¢ tick on a 3¢ contract is a 33% price grid. Fine structure does
  not exist down there.

## Flow and participant indicators

Available because everything settles on-chain
([../../prediction-markets/polymarket-data.md](../../prediction-markets/polymarket-data.md)).

- **Holder concentration** — a top holder with a large share of open interest means the price reflects
  one opinion, not a consensus. **Grade C**, useful as a caution.
- **Smart-money tracking** — following wallets with strong realised PnL histories. **Grade C.**
  Leaderboards overweight recent hot streaks; require a minimum number of closed positions and
  diversity across categories before granting a wallet credibility, and expect address churn.
- **Fresh-wallet conviction** — a new wallet taking a large one-sided position in a niche market.
  **Grade C, and explicitly a heuristic**: hedgers, market makers and bridged flow all look like this.
  Treat as a research flag, never as an accusation or an automated trigger.
- **Cross-venue disagreement** — the same question priced differently on Polymarket and HIP-4 is a
  convergence signal with a mechanism, which makes it stronger than any of the above.

## What does not transfer from technical analysis

- **Moving-average crossovers** — the series is not a random walk with drift; it is a martingale
  converging to a boundary. Trend-following logic does not apply.
- **RSI / stochastic "overbought"** — a contract at 0.95 is not overbought. It may be correctly priced
  at 95%.
- **Fibonacci, chart patterns, Elliott waves** — no basis at all in a series whose dynamics are
  information arrival plus convergence.
- **Volatility indicators** need reinterpretation: price variance is mechanically bounded by
  `p(1−p)` and shrinks toward resolution. A falling volatility reading may be pure convergence.

## The one summary statistic worth building

For each market you consider, compute:

```
edge  =  your_probability − ask_price
cost  =  fee(p) + half_spread + expected_slippage
holding period = time to resolution
annualised expected return = (edge − cost) / ask_price × (365 / days_to_resolution)
```

Rank by that, not by edge alone. It is the number that makes a 3-day 2% edge and a 9-month 15% edge
comparable, and it is the discipline that stops a portfolio filling up with long-dated positions that
tie up capital for a year to earn a mediocre return.
