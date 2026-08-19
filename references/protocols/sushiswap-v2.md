---
protocol: sushiswap-v2
category: dex
chains: [1, 8453, 42161, 10]
archetype: liquidity_provision
executor: knowledge-only
aliases:
  - "lp on sushi"
  - "provide liquidity on sushiswap"
  - "add liquidity to a sushi pool"
  - "deposit into a sushiswap pair"
  - "remove liquidity from sushi"
  - "withdraw my sushi lp"
roles: [router, factory]
actions: [addLiquidity, removeLiquidity]
tokens: [USDC, WETH]
---

# SushiSwap V2 (classic AMM)

SushiSwap V2 is the original constant-product (`x*y=k`) AMM — a Uniswap-V2 fork deployed across many
chains. Depositing a tokenA/tokenB pair through the **Router** (role `router`) mints an SLP (Sushi LP)
token: the pair contract is its own ERC20, so the LP position is just a token balance. The **Factory**
(role `factory`) maps a token pair to its pair address (`getPair`) — used to discover or confirm a pool.

> **executor: knowledge-only.** The compose blocks exist (`compose/sushiV2Blocks.ts`, the `lp` capability,
> alongside Aerodrome's) and are engine-encodable, but the `lp` capability isn't opted into the live
> composer's default menu yet. The harness will `needs_research` a SushiSwap-V2 LP request until that
> capability is turned on. This file is the knowledge that build-out is against.

## action: addLiquidity
**Function:** `addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`
**Contract:** role `router` (registry: `dex/sushiswap-v2/router`)
**Use when:** depositing a token pair to mint SLP tokens. Unlike Aerodrome/Solidly, there is **no `stable`
flag** — every SushiSwap V2 pool is constant-product.

### params
- `tokenA` / `tokenB` — resolved from the token book.
- `amountADesired` / `amountBDesired` — the amounts you'd contribute, each in its own decimals.
- `amountAMin` / `amountBMin` — the minimum actually deposited per side (slippage floors against a moving
  ratio). **Never both 0.**
- `to` — **the vault/wallet itself** (who receives the SLP tokens). `deadline` — near-future.

### pitfalls
- Approve BOTH `tokenA` and `tokenB` to the `router` first.
- The router deposits at the current reserve ratio and refunds the excess side — size `amountAMin`/
  `amountBMin` to bound how much ratio drift you accept; zeroing them accepts any ratio.
- `to` other than the vault/wallet leaks the LP position — refuse.

### safety
- SLP tokens are minted to `to`; confirm no third-party recipient.
- The unused portion of one side is refunded; account for it in the expected delta.

## action: removeLiquidity
**Function:** `removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`
**Contract:** role `router` (registry: `dex/sushiswap-v2/router`)
**Use when:** burning SLP tokens to withdraw the underlying tokenA/tokenB pair.

### params
- `liquidity` — the SLP amount to burn, in the SLP token's own decimals (18dp for the pairs curated so far).
- `amountAMin` / `amountBMin` — the minimum you'll accept back per side; **never both 0.**

### pitfalls
- Approve the SLP token to the `router` first (it is a standard ERC20).
- `to` other than the vault/wallet leaks the underlying — refuse.

### safety
- Both underlying tokens land with `to`; confirm it is the vault/wallet and swept home on close.
