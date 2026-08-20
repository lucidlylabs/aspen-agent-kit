---
section: quant
group: strategies
title: Statistical arbitrage and pairs trading
type: convergence
triggers: >-
  pairs trading, stat arb, cointegration, spread trading, relative value,
  market neutral, cross venue arbitrage, correlation trade
---

# Statistical arbitrage and pairs trading

## Mechanism

Two instruments driven by the same underlying factors should maintain a stable relationship. When they
diverge, one is temporarily mispriced relative to the other. **Trade the spread, not the direction** —
you are neutral to the common factor and exposed only to the relationship.

The canonical study is Gatev, Goetzmann & Rouwenhorst (2006), which documented meaningful excess
returns to a simple distance-based pairs rule in US equities over four decades — and also documented
the decline of those returns as the strategy became widely known. Avellaneda & Lee (2010) formalised
the modern factor-residual version.

**Why this is the best home for mean reversion:** a spread between economically linked instruments has
a *reason* to revert. An outright price does not.

## The spectrum, from airtight to speculative

| Type | Link | Confidence |
|---|---|---|
| **Same asset, two venues** | Identical underlying | Near-certain. This is arbitrage, not statistics. |
| **Perp vs its own spot/index** | Contractual funding pressure | Very high — this is basis ([basis-and-cash-carry.md](basis-and-cash-carry.md)) |
| **Same-sector majors** (e.g. two large L1 perps) | Shared factor exposure | Moderate. Real, but the relationship drifts. |
| **Statistically selected pairs** | Correlation found by search | Low. Almost always overfitting unless an economic story precedes the search. |

**Start at the top of this table.** The cross-venue form is available to you directly: Hyperliquid and
Lighter both list the majors, and price differences between them are genuine convergence
opportunities with no factor risk at all.

## Construction

**1. Establish the relationship, economically first.** State why these two move together before
testing whether they do. A pair discovered by scanning correlations across a universe is a
multiple-testing artifact until proven otherwise.

**2. Estimate the hedge ratio.** Not 1:1 unless the instruments are identical.

```
price_A = α + β × price_B + ε
spread  = price_A − β × price_B
```

Estimate β on a rolling window (OLS, or total least squares if both series have noise). **Re-estimate
periodically** — a stale β is a directional position you did not intend.

**3. Test for cointegration, not correlation.** This is the distinction that matters. Correlated series
can drift apart forever; cointegrated series have a stationary spread that must revert. Use
Engle–Granger or Johansen. **Correlation is not sufficient and is the most common mistake in this
strategy family.**

**4. Trade the spread's z-score.**

```
z = (spread − rolling_mean(spread)) / rolling_std(spread)
enter when |z| > 2,  exit when |z| < 0.5,  stop when |z| > 4 or cointegration fails
```

## Entry, exit, sizing

- **Entry** on |z| above threshold, *plus* a confirmation that the cointegration relationship still
  holds on recent data.
- **Exit** on reversion to near zero, on a time stop, or on relationship breakdown.
- **The stop is a thesis stop, not a price stop.** Exit when the statistical relationship fails, not
  when the spread widens — widening is what you are being paid for, up to the point where the
  relationship is broken. Distinguishing the two is the whole skill.
- **Size both legs to equal risk**, using the hedge ratio, in notional or beta-adjusted terms. Check
  the realised delta of the pair rather than assuming it.

## Failure modes

1. **The relationship breaks.** The reason two things moved together stops being true — a protocol
   failure, a delisting, a fundamental divergence. This is where the large losses come from, and it
   is not detectable from the spread alone until it has cost you.
2. **Correlation mistaken for cointegration.** The spread was never stationary; you have been trading
   a trending series with a mean-reversion rule.
3. **Multiple-testing.** Scanning N assets gives N(N−1)/2 pairs. At 100 assets that is 4,950 tests, and
   many will look cointegrated by chance. Correct for it, or start from economics.
4. **Both legs cost.** Two instruments, two spreads, two sets of fees, entry and exit — **four fills
   per round trip.** The cost bar is double that of a single-leg strategy, which is why medium-to-high
   fee sensitivity applies.
5. **Execution leg risk.** Filling one leg and not the other leaves you naked directional. Either
   execute both as takers accepting the cost, or have an explicit rule for handling a partial hedge.
6. **Crowding.** Popular pairs unwind together.
7. **Asynchronous data.** Two venues' timestamps must be aligned before you compute a spread, or you
   will trade your own infrastructure's lag ([../data/data-quality.md](../data/data-quality.md)).

## The cross-venue version, concretely

The most practical form on these venues:

- Same asset, Hyperliquid perp vs Lighter perp.
- The "spread" is a genuine price difference on an identical underlying — no factor risk, no
  cointegration assumption needed, no relationship to break.
- **But:** two venues means two margin accounts, and a violent move can liquidate one leg while the
  other is profitable and inaccessible. This is the same operational risk as cross-venue funding carry
  ([funding-carry.md](funding-carry.md)), and it is the real constraint.
- The convergence force is arbitrage capital plus funding. It is usually fast, which means the
  opportunity is usually small and competitive. Be honest about whether you can capture it at your
  latency, especially on Lighter's Standard tier.
