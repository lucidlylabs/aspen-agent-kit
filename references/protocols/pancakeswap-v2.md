---
protocol: pancakeswap-v2
category: dex
chains: [1, 8453, 42161]
archetype: liquidity_provision
executor: knowledge-only
aliases:
  - "lp on pancakeswap"
  - "provide liquidity on pancakeswap"
  - "add liquidity to a pancakeswap pool"
  - "deposit into a pancakeswap v2 pair"
  - "remove liquidity from pancakeswap"
  - "withdraw my pancakeswap lp"
roles: [router, factory]
actions: [addLiquidity, removeLiquidity]
tokens: [USDC, WETH]
---

# PancakeSwap V2 (classic AMM)

PancakeSwap V2 is a constant-product (`x*y=k`) AMM — a byte-identical Uniswap-V2 fork deployed on many
EVM chains (here: Ethereum, Base, Arbitrum). Depositing a tokenA/tokenB pair through the **Router** (role
`router`) mints a Cake-LP token: the pair contract is its own ERC20, so the LP position is just a token
balance. The **Factory** (role `factory`) maps a token pair to its pair address (`getPair`) — used to
discover or confirm a pool.

> **executor: knowledge-only.** The compose blocks exist (`compose/ammV2Blocks.ts`'s shared
> `makeAmmV2LiquidityBlocks()` factory, instantiated for `pancakeswap-v2` — the `lp` capability, alongside
> Uniswap V2 / SushiSwap V2 / Aerodrome) and are engine-encodable, but the `lp` capability isn't opted into
> the live composer's default menu yet. The harness will `needs_research` a PancakeSwap-V2 LP request until
> that capability is turned on. This file is the knowledge that build-out is against. Router+Factory are
> registry-verified on all three chains (a live `eth_call` of `Router.factory()` matched each Factory row).

## action: addLiquidity
**Function:** `addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`
**Contract:** role `router` (registry: `dex/pancakeswap-v2/router`)
**Use when:** depositing a token pair to mint Cake-LP tokens. Like Uniswap/Sushi V2 (and unlike
Aerodrome/Solidly), there is **no `stable` flag** — every PancakeSwap V2 pool is constant-product.

### params
- `tokenA` / `tokenB` — resolved from the token book.
- `amountADesired` / `amountBDesired` — the amounts you'd contribute, each in its own decimals.
- `amountAMin` / `amountBMin` — the minimum actually deposited per side (slippage floors against a moving
  ratio). **Never both 0.**
- `to` — **the vault/wallet itself** (who receives the LP tokens). `deadline` — near-future.

### pitfalls
- Approve BOTH `tokenA` and `tokenB` to the `router` first.
- The router deposits at the current reserve ratio and refunds the excess side — size `amountAMin`/
  `amountBMin` to bound how much ratio drift you accept; zeroing them accepts any ratio.
- `to` other than the vault/wallet leaks the LP position — refuse.

### safety
- LP tokens are minted to `to`; confirm no third-party recipient.
- The unused portion of one side is refunded; account for it in the expected delta.

## action: removeLiquidity
**Function:** `removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`
**Contract:** role `router` (registry: `dex/pancakeswap-v2/router`)
**Use when:** burning Cake-LP tokens to withdraw the underlying tokenA/tokenB pair.

### params
- `liquidity` — the LP amount to burn, in the LP token's own decimals (18dp).
- `amountAMin` / `amountBMin` — the minimum you'll accept back per side; **never both 0.**

### pitfalls
- Approve the LP token to the `router` first (it is a standard ERC20).
- `to` other than the vault/wallet leaks the underlying — refuse.

### safety
- Both underlying tokens land with `to`; confirm it is the vault/wallet and swept home on close.
