---
archetype: funding_arb
triggers: farm the funding spread / delta-neutral <asset> funding trade on an
  asset that trades on two Hyperliquid DEXs
executor: live
gateBlock: funding_carry_above
capability:
  - perp
  - statarb
promptOrder: 20
grounding:
  - funding_direction
defaults:
  leverage: 3
---

- CROSS-DEX DELTA-NEUTRAL FUNDING ARB (user wants to "farm the funding spread" / "delta-neutral <asset> funding
  trade" on an asset that trades on TWO Hyperliquid DEXs, e.g. gold = PAXG on core + xyz:GOLD on a builder DEX):
  add a TOP-LEVEL "fundingArb" object: "fundingArb": { "asset": "<slug, e.g. gold>", "budget": <total USD across
  BOTH legs>, "leverage": <default 3> }. Emit EXACTLY two legs with NO market and NO collateral — one
  open_long_perp and one open_short_perp (params just { "maxSlippageBps": "50" }) — the system resolves the asset's
  two venues, reads live funding, and DECIDES which venue to long vs short + sizes both legs equally; do NOT pick
  direction, markets, or sizes yourself. Entry gate: a funding_carry_above guard (params { "marketLong": "",
  "marketShort": "", "threshold": 0 } — code fills the markets + floor) pointing at BOTH legs. Exits: a
  pair_basis_above guard (thresholdBps 150) and portfolio_pnl_above/below (0.15 / -0.08) each pointing at close_perp legs.

## Notes

Direction is decided in CODE, never by the LLM: `selectFundingArbLegs` (`compose/fundingArb.ts`) shorts
the higher-funding representation, with an exhaustive funding-sign table — a sign error would silently PAY
the carry, so it is engineered into a test failure. Asset identity resolves through the curated
`ASSET_IDENTITY` map (fail-closed on unmapped/fuzzy). Funding is an ORACLE READ (HL `metaAndAssetCtxs`,
dex-routed), never modeled. The builder-DEX leg auto-funds and auto-sweeps through the dex-aware
`attachFundingBridge`/`attachRepatriation`.
