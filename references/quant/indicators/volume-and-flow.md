---
section: quant
group: indicators
title: Volume and order-flow indicators
triggers: >-
  volume, OBV, VWAP, MFI, accumulation distribution, volume profile, CVD,
  cumulative volume delta, order flow, amihud, VPIN, liquidity
---

# Volume and order-flow indicators

**Volume is the most under-used and most abused input in retail technical analysis.** Under-used
because it carries genuine information about conviction and liquidity; abused because most classic
volume indicators are ad-hoc constructions with no theoretical basis.

The modern, defensible version of "volume analysis" is **order flow**: not how much traded, but how
much traded *aggressively on each side*. If your data has an aggressor-side flag, use it. It changes
this family from grade C to grade B.

## VWAP — Volume-Weighted Average Price

`VWAP = Σ(price × volume) / Σ(volume)` over a defined window.

- **Grade: A as an execution benchmark; C as a signal.**
- Its real job is measuring execution quality. "Did I beat VWAP?" is the standard institutional
  question because VWAP approximates the average price available to a participant over the period.
  See [../execution/order-placement.md](../execution/order-placement.md).
- As a signal ("price above VWAP is bullish") there is no robust evidence. It is a moving average
  weighted by volume; treat it as a trend measure.
- **Anchor it deliberately.** Session VWAP is meaningless in 24/7 markets where "session" is a
  convention. Anchor to an event that matters: a funding timestamp, a breakout bar, a news release,
  or your own entry.

## Cumulative Volume Delta (CVD)

`delta = aggressive buy volume − aggressive sell volume`, accumulated.

**This is the volume indicator worth your time.** It requires trade data with an aggressor side —
available on all three venues in this kit via their trade feeds, and one of the strongest reasons to
record trades ([../../perpetuals/hyperliquid-data.md](../../perpetuals/hyperliquid-data.md)).

- **Grade: B.** It measures something real: net aggressive demand.
- **The informative case is divergence between CVD and price**, and unlike oscillator divergence this
  one has a mechanism. Price rising while CVD falls means price is being lifted without aggressive
  buying — passive bids being pulled, or a thin book — which is a genuinely fragile advance. Price
  flat while CVD rises strongly means aggressive buying is being absorbed by a large passive seller,
  which is information about where supply sits.
- **Caveat:** aggressor classification is reliable when the venue provides it and unreliable when
  inferred (the Lee-Ready tick rule and its descendants misclassify a meaningful fraction of trades).
  Use the venue's flag.

## OBV, Accumulation/Distribution, Money Flow Index

- **OBV (On-Balance Volume)** — add the whole bar's volume if the close rose, subtract it if it fell.
  A crude proxy for CVD from before aggressor data was available. **Grade C.** If you have CVD, OBV is
  strictly worse; the whole-bar attribution is a coarse approximation.
- **A/D Line** — weights volume by where the close sat within the bar's range. Slightly less crude
  than OBV, same limitation. **Grade C.**
- **MFI (Money Flow Index)** — RSI computed on price × volume. Inherits RSI's problems and adds
  volume's noise. **Grade C.**

These persist for historical reasons. They are proxies for order flow, and you have order flow.

## Volume Profile / Volume-at-Price

The distribution of volume across price levels over a period, rather than across time. Yields the
**Point of Control** (highest-volume price) and **value area** (typically the 70% band).

- **Grade: C, but conceptually sound.** High-volume price levels are where large amounts of inventory
  changed hands, so they are plausible support/resistance — participants have positions there and
  behave differently around their entry prices.
- Useful as *context* for where to place limit orders and stops. Not a trigger.
- Beware incentive-driven wash volume in crypto, which corrupts the profile entirely on affected
  markets.

## Liquidity measures that actually matter

These are less famous and more useful than any of the above.

### Amihud illiquidity (2002)

```
ILLIQ = mean( |return| / dollar volume )
```

Price impact per unit of volume — how much the price moves for each dollar traded. Simple, robust,
computable from daily data, and one of the most widely used liquidity proxies in the academic
literature. **Grade A as a liquidity measure.**

Use it to rank a perp universe by tradability, to set per-market position caps, and to filter out
markets where your intended size is unrealistic. **A backtest that ignores cross-sectional liquidity
differences will systematically overweight the markets you cannot actually trade.**

### Turnover and volume relative to your own size

The only volume statistic that determines whether you can trade: **your intended order size as a
fraction of typical volume and of visible depth.** Above roughly a few percent of average bar volume,
your own impact becomes a first-order cost and your backtest fills are fiction.

### VPIN — order flow toxicity (Easley, López de Prado & O'Hara)

Volume-synchronised probability of informed trading: measures order-flow imbalance in **volume time**
rather than clock time, as a proxy for how "toxic" flow is to liquidity providers.

- **Grade: B, contested.** It was proposed as an early-warning indicator for liquidity crises and the
  evidence has been actively debated in the literature.
- **Relevant if you are making markets.** Rising toxicity means widening quotes or standing aside.
  Less relevant for directional strategies.

## How to use this family

1. **Use volume for liquidity and feasibility first.** Can I trade this, at this size, at a cost I
   have modelled? That question is answered here and nowhere else.
2. **Use order flow (CVD) as a confirmation of a mechanism**, not as a standalone trigger.
3. **Treat the classic volume oscillators as legacy.** If you have trade-level data with aggressor
   sides, build CVD and skip OBV, A/D and MFI entirely.
4. **Always check for incentive-driven volume.** Points programs, volume quotas and rebate schemes
   generate enormous non-informative volume. On a market with an active incentive program, volume
   indicators measure the program.
