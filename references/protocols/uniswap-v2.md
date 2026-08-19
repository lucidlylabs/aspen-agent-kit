---
protocol: uniswap-v2
category: dex
chains: [1, 8453, 42161, 10]
archetype: liquidity
executor: knowledge-only
aliases:
  - "provide liquidity to USDC/WETH on uniswap v2"
  - "add liquidity to a uniswap v2 pool"
  - "deposit into the uniswap v2 USDC/WETH pair"
  - "remove liquidity from my uniswap v2 position"
  - "withdraw from a uniswap v2 pair"
  - "burn my uniswap v2 LP tokens"
roles: [router, factory]
actions: [addLiquidity, removeLiquidity]
tokens: [USDC, WETH, USDC-WETH-V2]
---

# Uniswap v2

Uniswap v2 is the original constant-product (`x*y=k`) AMM. Every pool is a `UniswapV2Pair` contract that
is ALSO its own ERC20 **LP token** — depositing/withdrawing goes through the singleton **Router02** (role
`router`), which computes the pair address from the **Factory** (role `factory`) internally; you never
call the pair directly for adds/removes.

> **executor: knowledge-only** for the harness's NL decomposer — no engine executor runs a Uniswap V2
> archetype there yet. **BUT the `lp` capability in `@aspen/sdk`'s generic compose engine is BUILT +
> offline-proven** (`compose/ammV2Blocks.ts` — a REUSABLE factory shared with SushiSwap V2/Aerodrome's
> classic AMM, `makeAmmV2LiquidityBlocks()`): `uniswap-v2_add_liquidity` / `uniswap-v2_remove_liquidity`
> are real, byte-exact, encodable graph primitives — `loadCatalog({ capabilities: ["lp"] })` opts them
> in. `add_liquidity` needs no curated pool address (any two token-book symbols); `remove_liquidity`
> needs a curated LP-token row (`lpToken` param) — one flagship pair ships today, **`USDC-WETH-V2`**
> (Ethereum), verified DIRECTLY on-chain (a live `Factory.getPair(USDC,WETH)` `eth_call`) — the long tail
> of pairs is a follow-up (curate more, same pattern). This file is the knowledge those blocks are built
> against; a plain-English Uniswap V2 prompt through the NL harness still `needs_research` until a
> decomposer executor is wired on top.
>
> **Gotcha (verified against Uniswap's own docs, 2026-07-15):** the Factory address is **NOT** the same
> across chains — in particular, Arbitrum's Factory is a DIFFERENT contract from Ethereum mainnet's (a
> documented mistake some integrators make; tracked in a Uniswap/docs GitHub issue). Never assume one
> Factory address works everywhere — resolve it per chain from the registry.

## action: addLiquidity
**Function:** `addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`
**Contract:** role `router` (registry: `dex/uniswap-v2/router`)
**Use when:** depositing a tokenA/tokenB pair to mint LP tokens (creates the pool on first deposit if it
doesn't exist yet).

### params
- `tokenA` / `tokenB` — resolved from the token book by symbol; order doesn't matter for this call (unlike
  Uniswap V3's `mint`, this classic Router sorts internally).
- `amountADesired` / `amountBDesired` — the amounts you'd contribute, each in its own decimals.
- `amountAMin` / `amountBMin` — the minimum actually deposited per side (a moving-ratio slippage floor).
  Derive from the pool reserves and the bound; **never both 0.**
- `to` — **MUST be the trading wallet / vault itself** (where the minted LP tokens land).
- `deadline` — a near-future timestamp, not `type(uint256).max`.

### pitfalls
- Approve BOTH `tokenA` and `tokenB` to the `router` first (two approve legs) or it reverts / is default-DENYed.
- The router deposits at the current reserve ratio and refunds the excess side — size `amountAMin`/
  `amountBMin` to bound how much ratio drift you accept; zeroing them accepts any ratio.
- `to` other than the vault leaks the LP position — refuse.

### safety
- LP tokens are minted to `to` = the vault; confirm no third-party recipient.
- The unused portion of one side is refunded to the vault; account for it in the expected delta.

## action: removeLiquidity
**Function:** `removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`
**Contract:** role `router` (registry: `dex/uniswap-v2/router`)
**Use when:** burning LP tokens to withdraw the underlying tokenA/tokenB pair.

### params
- `tokenA` / `tokenB` — resolved from the token book.
- `liquidity` — the LP-token amount to burn (18 decimals — every Uniswap V2 pair's LP token is 18dp).
- `amountAMin` / `amountBMin` — the minimum you'll accept per side. Derive from the pool reserves and the
  bound; **never both 0.**
- `to` — **MUST be the trading wallet / vault itself.**

### pitfalls
- Approve the pair's own LP-token address to the `router` first (the LP token is a real ERC20 — the
  router's `removeLiquidity` ABI has no separate `lpToken` field, but the underlying `transferFrom` still
  needs an allowance).
- `amountAMin`/`amountBMin = 0,0` accepts any ratio, including a sandwich-manipulated one — refuse.
- `to` other than the vault leaks the withdrawn tokens — refuse.

### safety
- Both underlying tokens land with `to` = the vault in one call; confirm neither is swept to a third party.
