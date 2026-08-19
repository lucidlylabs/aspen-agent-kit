---
protocol: curve
category: dex
chains: [1, 8453, 42161, 10]
archetype: swap
executor: knowledge-only
aliases:
  - "swap USDC for USDT on curve"
  - "trade stablecoins on curve"
  - "exchange DAI to USDC"
  - "provide liquidity to a curve pool"
  - "deposit into the 3pool"
  - "add liquidity to crvUSD/USDC"
  - "withdraw one coin from a curve pool"
roles: [pool]
actions: [exchange, add_liquidity, remove_liquidity_one_coin]
tokens: [USDC, USDT, DAI, crvUSD, WETH]
---

# Curve

Curve is a StableSwap / crypto-swap AMM optimised for low-slippage swaps between like-priced assets
(stablecoins, LSTs). Unlike a router-fronted DEX, you call the **pool** contract itself (role `pool`)
directly — each pool holds a fixed set of coins addressed by integer index (`i`, `j`), not by address.

> **executor: knowledge-only.** No engine executor runs a Curve `exchange` / LP archetype yet (the live
> `swap_tp_sl` executor is Uniswap-v3-specific). The harness will `needs_research` a Curve request until
> a pool-based executor exists. This file is the knowledge that executor is built against.
>
> **Coin indices are per-pool, not global.** `i`/`j` must be resolved from the specific pool's coin list
> (`coins(i)`), never guessed — a wrong index swaps the wrong asset. Classic pools take `int128` indices;
> newer NG / crypto pools take `uint256`. Match the pool's actual ABI.

## action: exchange
**Function:** `exchange(int128 i, int128 j, uint256 dx, uint256 min_dy)`
**Contract:** role `pool` (registry: `dex/curve/pool`)
**Use when:** swapping coin `i` for coin `j` within a single Curve pool.

### params
- `i` / `j` — the source and destination coin indices for THIS pool; resolve from `coins(i)` against the
  token book, `i != j`. NG / crypto pools use `uint256` indices — use the pool's real signature.
- `dx` — the input amount, in coin `i`'s decimals; scale from the token book, never a hardcoded 10^n.
- `min_dy` — the slippage floor on the output. Derive it from `get_dy(i, j, dx)` and `maxSlippageBps`;
  **never leave it at 0.**

### pitfalls
- Approve coin `i` to the `pool` first (approve leg must be in the plan) or the exchange reverts / is default-DENYed.
- A wrong `i`/`j` silently trades a different pair — resolve indices from the pool, do not assume ordering.
- `min_dy = 0` is an unbounded-slippage swap — refuse; floor it from a fresh `get_dy`.
- Some pools expose `exchange_underlying` (lending/meta pools) — that is a different index space; don't mix them.

### safety
- The received coin `j` must be swept home to the vault; the swap output lands with `msg.sender` = the vault.
- Re-read `get_dy` immediately before sending; a stale quote widens real slippage past the bound.

## action: add_liquidity
**Function:** `add_liquidity(uint256[2] amounts, uint256 min_mint_amount)`
**Contract:** role `pool` (registry: `dex/curve/pool`)
**Use when:** depositing one or more of the pool's coins to mint LP tokens.

### params
- `amounts` — a fixed-length array (length == the pool's coin count; `[2]` shown, use the pool's real N;
  NG pools take a dynamic `uint256[]`). Each entry in that coin's decimals; unbalanced deposits are allowed
  but incur an imbalance fee.
- `min_mint_amount` — the minimum LP tokens to accept. Derive from `calc_token_amount(amounts, true)` and
  the slippage bound; **never 0.**

### pitfalls
- Approve EVERY non-zero coin in `amounts` to the `pool` first, each in its own decimals.
- Passing the wrong array length or mis-ordered coins deposits into the wrong slots — resolve against `coins(i)`.
- `min_mint_amount = 0` accepts any mint under an imbalanced/attacked pool — refuse; floor it.

### safety
- The LP token is minted to the vault (`msg.sender`); no third-party recipient exists on this call — good.
- Imbalanced deposits realise the imbalance fee immediately; size the leg with that fee in the expected delta.

## action: remove_liquidity_one_coin
**Function:** `remove_liquidity_one_coin(uint256 _burn_amount, int128 i, uint256 _min_received)`
**Contract:** role `pool` (registry: `dex/curve/pool`)
**Use when:** redeeming LP tokens for a single underlying coin `i`.

### params
- `_burn_amount` — LP tokens to burn, in the LP token's decimals (18).
- `i` — the coin index to receive; resolve from `coins(i)`. NG pools use `uint256`.
- `_min_received` — the slippage floor on the withdrawn coin. Derive from
  `calc_withdraw_one_coin(_burn_amount, i)` and the bound; **never 0.**

### pitfalls
- Withdrawing to a single coin realises the full imbalance slippage — for large exits, a balanced
  `remove_liquidity` may be cheaper; only single-coin when intended.
- `_min_received = 0` accepts any output — refuse; floor it from `calc_withdraw_one_coin`.

### safety
- The withdrawn coin lands with the vault (`msg.sender`); sweep is implicit but confirm it stays home.
- LP token approval to the pool is generally not needed (the pool burns its own token), but confirm per pool.
