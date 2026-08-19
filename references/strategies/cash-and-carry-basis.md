---
archetype: basis_cash_and_carry
triggers: long spot and short the perp on the SAME asset to collect funding with no
  price exposure — "cash and carry", "basis trade", "spot-perp arb", "earn funding
  delta-neutral on one venue"
executor: live
gateBlock: hl_spot_buy
capability:
  - perp
  - statarb
promptOrder: 100
---

- CASH-AND-CARRY BASIS (user wants to "long spot and short the perp on the same asset" / "cash and carry" /
  "basis trade" / "earn funding delta-neutral on one venue"): emit EXACTLY two legs — one hl_spot_buy and one
  open_short_perp — and SIZE THEM YOURSELF so the two carry EQUAL NOTIONAL, which is what makes the book
  delta-neutral. Split the user's total budget in half: the spot leg's `spend` is budget/2, and the short's
  `collateral` is budget/(2 x leverage) so its notional (collateral x leverage) also equals budget/2. Direction
  is FIXED — long spot, short perp — there is no direction to choose.
  · ⚠ THE TWO LEGS DO NOT CARRY THE SAME TICKER. Hyperliquid's perp is `ETH`, but there is no `ETH/USDC` spot
    pair — spot ETH is the Unit-bridged `UETH` (likewise `UBTC`, `USOL`), while natives like `HYPE` have no
    prefix at all. There is no rule to apply, so CALL `hyperliquid_spot_markets` with the asset and use the
    symbol it confirms for the spot leg; the perp leg keeps the plain ticker. Naming a pair that doesn't exist
    strands the user's funds, because the order only fails after the bridge has moved the money.
  · State the split plainly when you present it ("$250 of spot UETH, $250 notional short ETH") — that is what
    the user reads on the deploy card and signs for.
  · Optional exits: funding_carry_below (funding flipped, carry gone) and portfolio_pnl_above /
    portfolio_pnl_below guards pointing at close_perp legs.
  · Optional DEFENSE (user wants to reinforce the short's margin when price runs against it — "if it rises X%,
    sell some spot and move the proceeds to margin"): on the price trigger, point the SAME guard at TWO nodes —
    an hl_spot_sell (size it with `notionalUsd` when the user gave a dollar amount) and a fund_perp_from_spot
    with no amount (it sweeps the sale's USDC proceeds onto the perp margin). Do NOT try to express the
    transfer as a bridge or a swap — fund_perp_from_spot IS the spot→perp margin move.

## What it is

The classic delta-neutral carry: buy the asset spot, short an equal notional of its perp, and collect funding
while the two legs cancel price risk. Profitable while funding is positive (longs pay shorts); exits are
funding flipping negative or the spot-perp basis blowing out. Single-venue sibling of the cross-DEX
`funding_arb` (which runs both legs as perps across two Hyperliquid DEXs).

## Notes

SCOPE: `hl_spot_buy` joined the early-access launch menu on 2026-08-16, so this card is composable (and its
guidance injected) under the default `launch` catalog. The gate stays honest either way: if the block ever
leaves the menu again, the guidance self-hides and the spoken status flips back to coming-soon.

SIZING IS AGENT-OWNED (changed 2026-07-31). `groundCashAndCarry` and the `cashAndCarry` directive are DELETED.
The split is deliberate arithmetic the user can check on the card — "$250 spot / $250 perp" is either right or
obviously wrong — so it does not need a grounding pass. What stays in code is the part the user cannot check:
`spotMarketResolve` still validates the spot market against the LIVE universe and refuses a pair that isn't
listed, and it still refuses a market unrelated to the user's word. Equal-notional is the property that matters;
if you cannot make the legs equal, say so rather than shipping a book that is quietly directional.

Funding is an ORACLE READ, never modeled. An unwind ordering that closes the perp before selling the spot is a
live-execution follow-up.