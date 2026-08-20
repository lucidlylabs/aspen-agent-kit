---
section: quant
group: strategies
title: Trend following and momentum
type: direction
triggers: >-
  trend following, momentum strategy, breakout, donchian, turtle, moving average
  crossover, time series momentum, cross sectional momentum, pyramiding
---

# Trend following and momentum

## Mechanism

Returns exhibit continuation at horizons of roughly one to twelve months. The proposed explanations —
under-reaction to news, gradual information diffusion, flows from systematic and trend-following
capital, and behavioural anchoring — are contested, but the **effect itself is among the
best-documented in finance**: Jegadeesh & Titman (1993) cross-sectionally, Moskowitz, Ooi & Pedersen
(2012) in time series across 58 instruments and decades, Asness, Moskowitz & Pedersen (2013) across
asset classes.

**Who is on the other side?** Participants who need liquidity now, who are rebalancing, or who are
anchored to stale valuations. They persist because those needs are structural.

**Grade: A for the effect at documented horizons. The specific entry rule matters much less than
people think**, and most of the argument about optimal parameters is noise (see
[../indicators/trend.md](../indicators/trend.md)).

## Construction

Two forms, and they combine well:

**Time-series momentum (per market):**
```
signal_i = sign( return_i(lookback) )        # or a continuous, vol-scaled version
size_i   = target_risk / volatility_i
```

**Cross-sectional momentum (across a universe):**
```
score_i = return_i(lookback) / volatility_i(lookback)
long the top k, short the bottom k, each sized inversely to volatility
```

Entry alternatives, all roughly equivalent in the literature: moving-average slope, MA crossover,
Donchian breakout of an N-period high, or simply the sign of the trailing return. **Prefer the
simplest one with the fewest parameters.** Donchian breakout has the advantage of being
non-parametric in price — it is a factual statement that price exceeded all recent supply.

## Entry

- **Long lookbacks.** The documented effect lives at weeks-to-months. Fast crossovers on intraday bars
  are a different phenomenon and mostly a fee-generation machine.
- **Volatility filter.** Breakouts fail disproportionately in low-volatility regimes; a
  volatility-expansion or ADX condition removes a chunk of the false ones.
- **Funding filter — this is the crypto-specific addition that matters.** Going long into extremely
  rich funding means paying carry to join a crowd that is already maximally positioned. Check the
  funding z-score before entering ([../indicators/crypto-native.md](../indicators/crypto-native.md));
  a strong price signal with negative funding is a much better trade than the same price signal with
  extreme positive funding.

## Exit

The exit determines the strategy's character more than the entry does.

- **Trailing stop at N × ATR.** The standard, and it adapts to regime automatically.
- **Opposite signal** — exit when the trend measure flips. Simple, and keeps you in longer.
- **Channel exit** — exit on an M-period low for a long, with M < N. The Turtle construction.
- **Time stop.** If the trend has not developed within a horizon, the thesis is not working.

**Do not use a fixed profit target.** Trend following's entire return comes from the small number of
trades that run very far. Capping them converts a positive-skew strategy into a negative-skew one and
removes the reason the strategy works.

## Sizing and pyramiding

Volatility-scaled sizing is not optional here — it is most of the risk-adjusted performance.

```
units = (equity × risk_fraction) / (N × ATR)
```

**Pyramiding** — adding to a winning position at intervals — increases exposure to the trades that
run. Rules that keep it sane: add only in the direction of the trend, only after a defined favourable
move (e.g. every 0.5 ATR), cap the number of adds, and **move the stop for the whole position** to
protect the aggregate rather than each tranche separately. Total position size after all adds must
still respect your per-market cap.

## Failure modes

1. **Choppy markets.** Trend following loses steadily in ranges. This is not a bug and cannot be
   filtered away entirely — it is the cost of the payoff profile.
2. **Low win rate is normal.** Roughly 30–40% of trades winning is typical. If you cannot tolerate
   long strings of small losses psychologically or operationally, this is the wrong strategy.
3. **Momentum crashes.** Sharp reversals at regime turns, precisely when positioning is crowded.
   Funding is your warning.
4. **Correlated universe.** A cross-sectional book on 20 crypto perps that all correlate 0.8 to BTC is
   not market-neutral. Measure and hedge residual beta explicitly.
5. **Funding drag.** A multi-week long in a positive-funding regime pays continuously; this can exceed
   the trend edge. Net it before concluding the strategy works.
6. **Overfit lookbacks.** If 20 works and 18 and 22 do not, you found noise. Demand a plateau.

## Fee profile

Low turnover, so **fee-friendly**. A trend strategy holding for weeks pays two fills; the dominant
cost is funding, not fees. This makes trend one of the few directional strategies whose economics
work at retail fee levels — the opposite of mean reversion.
