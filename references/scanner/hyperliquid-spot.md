---
module: hyperliquid-spot
instrument: Hyperliquid spot
venue: hyperliquid
triggers: spot opportunities — buying and holding a token outright, accumulation and DCA,
  the spot leg of a delta-neutral basis trade, HIP-1 tokens, HIP-2 Hyperliquidity, "should
  I buy spot or perp", "cash and carry", spot vs perp dislocation
---

# Hyperliquid spot

## What it is, from first principles

Spot is **ownership**. You exchange USDC for a token and hold the token. There is no counterparty paying or
charging you to keep it, no expiry, and no price at which someone can take it away from you.

That last property is the whole point, and it is what separates spot from every other instrument here. A perp
long and a spot buy express the same view, but the perp can be **liquidated** — an adverse move large enough
ends the position at a loss even if the view was ultimately right. Spot has no such failure mode. The cost of
that safety is capital: spot ties up the full notional, while a perp posts a fraction as margin.

So the first-principles question is never "spot or perp?" in the abstract. It is: **does this thesis need to
survive a drawdown, and can it afford full collateral?** A thesis measured in months that would be liquidated
in a week belongs in spot. A short-horizon trade with a defined invalidation level does not.

## How it works on Hyperliquid

- **HIP-1 tokens**, each quoted against **spot USDC**, on the same on-book venue as perps, reached by the same
  signed order action. Spot is distinguished by its asset id (offset into the spot universe), not by a
  different endpoint.
- **No leverage, no margin, no liquidation, no funding.** Fully collateralized by construction.
- **Perp USDC and spot USDC are separate balances.** Moving between them is an explicit class transfer. A
  strategy holding spot while shorting a perp needs collateral on both sides — plan the split, don't discover
  it.
- **HIP-2 "Hyperliquidity"** optionally seeds automated on-book liquidity for a pair: a ~0.3% spread refreshed
  every few seconds, USDC-quoted pairs only. Many bridged assets opt out. Where it is active it sets a floor
  on available liquidity; where it is not, the book may be genuinely thin.
- **Token identity is a hash, not a name.** Display tickers can collide. Resolve the market from the venue,
  never from a name a user or a model typed.

## Where the opportunities are

**The neutralizing leg of a basis trade — the most valuable role spot plays here.** Long spot plus short perp
on the same asset is delta-neutral: the price exposures cancel, and the position collects funding for as long
as the rate is positive. The return comes from the funding rate net of both legs' fees, not from the asset
going anywhere. This is *the* reason to scan spot alongside perps rather than separately, and it is the
cleanest carry available on Hyperliquid. Screen the funding rate first, then confirm both legs have depth for
the ticket. Note the asymmetry: the spot leg cannot be liquidated, but the **perp leg can** if the pair is
under-collateralized — a delta-neutral position is not a risk-free one.

**Accumulation with no liquidation risk.** A long-horizon view executed as scheduled spot buys, converting a
timing problem into an averaging one. It gives up leverage entirely, which is exactly what makes it survive
the drawdown a leveraged version would not. The honest framing: this is direction, the weakest payoff source —
it needs the view to be right, and it should be presented that way.

**Spot–perp dislocation.** When the perp trades far from spot, funding is already paying someone to close the
gap. Spot is the leg that lets you take the other side without directional exposure. Same mechanism as the
basis trade, entered on the dislocation rather than on the rate.

**Thin-book pairs where HIP-2 is absent.** Pairs that opted out of Hyperliquidity can carry wide spreads.
That is an opportunity to *supply* liquidity with resting orders, and a hazard for anyone crossing the spread
with a market order. Which one it is depends entirely on whether you rest or cross.

## Screens

- **24h volume and book depth**, walked for the intended size. Spot books are frequently thinner than the
  perp book on the same asset — never infer spot liquidity from perp liquidity.
- **Spread**, and whether HIP-2 is active on the pair. A ~0.3% quoted spread you cross on both sides is 0.6%
  round trip, which swamps most short-horizon edges.
- **The paired perp's funding rate**, whenever spot is being considered as a basis leg — that rate *is* the
  return on the trade.
- **Free spot USDC vs perp USDC**, so a two-legged plan doesn't stall on collateral sitting in the wrong pot.

## What kills a spot position

Nothing forces an exit — that is the instrument's defining strength — so the real risks are opportunity cost
(full collateral tied up at zero yield while the thesis takes longer than expected) and the spread on a thin
pair eating a small edge on entry and again on exit. In a basis pair, the killer is the **perp leg**: funding
flipping negative turns the carry into a cost, and an under-margined short can be liquidated while the spot
leg sits there fully intact.
