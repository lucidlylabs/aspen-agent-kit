---
protocol: pendle-v2
category: yield
chains: [1, 8453, 42161]
archetype: pendle_yield
executor: knowledge-only
aliases:
  - "buy fixed yield on pendle"
  - "lock in a fixed rate"
  - "buy PT for fixed yield"
  - "long yield with YT on pendle"
  - "provide liquidity to a pendle market"
  - "redeem my pendle PT at maturity"
  - "claim pendle rewards"
roles: [router]
actions: [swapExactTokenForPt, swapExactPtForToken, addLiquidityDualSyAndPt, removeLiquidityDualSyAndPt, redeemSyToToken, redeemPyToSy, redeemDueInterestAndRewards]
tokens: [USDC, WETH, wstETH]
---

# Pendle V2

Pendle tokenizes future yield. A yield-bearing asset is wrapped into **SY** (standardized yield), which
splits into **PT** (principal — redeems 1:1 for the underlying at maturity → a *fixed yield* when bought
at a discount) and **YT** (the yield stream — *long yield/points*). Every action goes through
**Router V4** (role `router`), a single deterministic entrypoint deployed at the same address on every
chain. Each PT/YT/SY/LP is **market-specific** — its address comes from the Pendle market (via the
`marketFactory` / Pendle API), NOT from the token book. Dev docs: `https://docs.pendle.finance/pendle-v2-dev/Overview`.

> **executor: knowledge-only.** No engine executor runs the `pendle_yield` archetype yet; the harness
> will `needs_research` a Pendle request until one exists. Signatures below are the vetted Router path
> from boring-vault's `PendleRouterDecoderAndSanitizer.sol` (the SY-level flow the vault integration uses);
> the token-level `swapExactTokenForPt` / `swapExactPtForToken` convenience entrypoints wrap the same path.
>
> **Market resolution is off-chain and per-market.** PT/YT/SY/market are not plain ERC20s in the token
> book — an executor resolves them from the Pendle market for the chosen underlying + maturity, and MUST
> pin the exact market + maturity (a wrong market silently buys a different asset). The `receiver` on
> every call is the field the decoder sanitizes — it MUST be the vault.

## action: swapExactTokenForPt
**Function (SY-level, vetted):** `mintSyFromToken(address receiver, address SY, uint256 minSyOut, TokenInput input)` then `swapExactSyForPt(address receiver, address market, uint256 exactSyIn, uint256 minPtOut, ApproxParams guess, LimitOrderData limit)`
**Contract:** role `router` (registry: `yield/pendle-v2/router`)
**Use when:** buying PT for a fixed yield to maturity.

### params
- `receiver` — **MUST be the vault.** (The field the decoder sanitizes on every Router call.)
- `input` — a `TokenInput` describing the token spent (e.g. USDC/WETH from the token book) and how to
  wrap it into SY; amounts in the token's real decimals, scaled from the registry.
- `minPtOut` / `minSyOut` — slippage floors. **Derive from an oracle/quote + slippage bound; never 0.**
- `market` — the exact Pendle market (fixes the underlying + maturity). Resolve off-chain, pin it.

### pitfalls
- Wrong `market` buys a different maturity/underlying — pin the market; refuse an ambiguous one.
- `minPtOut = 0` is an unbounded-slippage buy — refuse; floor it.
- The spent token must be approved to the `router` first (approve leg must be in the plan).

### safety
- PT is fixed yield ONLY if held to maturity; selling early realizes market price. Price PT with the
  `oracle` role (`yield/pendle-v2/oracle`), never a hardcoded rate.

## action: swapExactPtForToken
**Function (SY-level, vetted):** `swapExactPtForSy(address receiver, address market, uint256 exactPtIn, uint256 minSyOut, LimitOrderData limit)` then `redeemSyToToken(address receiver, address SY, uint256 netSyIn, TokenOutput output)`
**Contract:** role `router` (registry: `yield/pendle-v2/router`)
**Use when:** exiting a PT position back to a token before maturity.

### params
- `receiver` — the vault. `output` — a `TokenOutput` for the token received; `minTokenOut` floored, never 0.

### pitfalls
- Exiting before maturity is at market price (may be below face value) — surface the expected token-out.

### safety
- After maturity, prefer `redeemPyToSy` (1:1 principal redemption) over a market swap.

## action: addLiquidityDualSyAndPt
**Function:** `addLiquidityDualSyAndPt(address receiver, address market, uint256 netSyDesired, uint256 netPtDesired, uint256 minLpOut)`
**Contract:** role `router` (registry: `yield/pendle-v2/router`)
**Use when:** providing SY+PT liquidity to a market to earn swap fees + incentives.

### params
- `receiver` — the vault. `minLpOut` — floored, never 0.

### pitfalls
- LP is exposed to PT price + impermanent loss vs. just holding PT — not a pure fixed yield.

### safety
- Only LP into a market whose maturity you intend to hold through; exiting near maturity thins liquidity.

## action: removeLiquidityDualSyAndPt
**Function:** `removeLiquidityDualSyAndPt(address receiver, address market, uint256 netLpToRemove, uint256 minSyOut, uint256 minPtOut)`
**Contract:** role `router` (registry: `yield/pendle-v2/router`)
**Use when:** withdrawing SY+PT liquidity.

### params
- `receiver` — the vault. `minSyOut` / `minPtOut` — floored, never 0.

### safety
- Remove before maturity if you want SY back; after maturity redeem the PT leg 1:1.

## action: redeemSyToToken
**Function:** `redeemSyToToken(address receiver, address SY, uint256 netSyIn, TokenOutput output)`
**Contract:** role `router` (registry: `yield/pendle-v2/router`)
**Use when:** unwrapping SY back to the underlying token.

### params
- `receiver` — **the vault.** `output.minTokenOut` — floored, never 0.

### pitfalls
- `receiver` other than the vault leaks the unwrapped token — refuse.

## action: redeemPyToSy
**Function:** `redeemPyToSy(address receiver, address YT, uint256 netPyIn, uint256 minSyOut)`
**Contract:** role `router` (registry: `yield/pendle-v2/router`)
**Use when:** redeeming PT (+YT) to SY — the clean 1:1 principal redemption AT/after maturity.

### params
- `receiver` — the vault. Before maturity this consumes matching PT+YT; after maturity PT alone redeems.

### safety
- This is the maturity exit — no market slippage, principal returns 1:1. Prefer it over a swap post-maturity.

## action: redeemDueInterestAndRewards
**Function:** `redeemDueInterestAndRewards(address user, address[] sys, address[] yts, address[] markets)`
**Contract:** role `router` (registry: `yield/pendle-v2/router`)
**Use when:** claiming accrued YT interest + LP/market reward tokens.

### params
- `user` — **the vault** (whose positions accrue). Pass the exact SY/YT/market arrays for the held positions.

### safety
- Read-of-record only moves rewards to the vault; it cannot move principal — but still pin `user` to the vault.
