---
protocol: balancer-v2
category: dex
chains: [1, 8453, 42161, 10]
archetype: swap
executor: knowledge-only
aliases:
  - "swap on balancer"
  - "swap USDC for WETH on balancer"
  - "trade through a balancer pool"
  - "multi-hop swap on balancer"
  - "batch swap on balancer"
  - "join a balancer pool"
  - "provide liquidity to a balancer weighted pool"
roles: [vault]
actions: [swap, batchSwap, joinPool]
tokens: [USDC, WETH, wstETH, BAL]
---

# Balancer v2

Balancer v2 routes ALL swaps and LP actions through a single **Vault** contract (role `vault`) per chain —
the pools themselves hold only math, the Vault holds the tokens. A swap references a pool by its `bytes32
poolId`, and token approvals go to the Vault (not to a pool).

> **executor: knowledge-only.** No engine executor runs a Balancer archetype yet (the live `swap_tp_sl`
> executor is Uniswap-v3-specific). The harness will `needs_research` a Balancer request until a
> Vault-based executor exists. This file is the knowledge that executor is built against.
>
> **One Vault, many pools.** The single signed-tx target is the Vault; the `poolId` selects the pool. All
> src-token approvals are to the Vault. Never approve or call a pool address directly.

## action: swap
**Function:** `swap((bytes32 poolId, uint8 kind, address assetIn, address assetOut, uint256 amount, bytes userData) singleSwap, (address sender, bool fromInternalBalance, address recipient, bool toInternalBalance) funds, uint256 limit, uint256 deadline)`
**Contract:** role `vault` (registry: `dex/balancer-v2/vault`)
**Use when:** a single-pool swap of `assetIn` for `assetOut`.

### params
- `singleSwap.poolId` — the `bytes32` id of the pool to trade through; resolve from the pool registry, not guessed.
- `singleSwap.kind` — `0 = GIVEN_IN` (spend exactly `amount` of `assetIn`). Use GIVEN_IN for a market spend.
- `singleSwap.assetIn` / `assetOut` — resolved from the token book by symbol; `assetIn != assetOut`.
- `singleSwap.amount` — the input amount (for GIVEN_IN), in `assetIn`'s decimals; scale from the token book.
- `funds.sender` — **the vault.** `funds.recipient` — **the vault.** `fromInternalBalance` / `toInternalBalance` — `false`.
- `limit` — for GIVEN_IN this is the **minimum `assetOut`** (the slippage floor). Derive it from a
  `queryBatchSwap` read and `maxSlippageBps`; **never 0.**
- `deadline` — a near-future timestamp; not `type(uint256).max`.

### pitfalls
- Approve `assetIn` to the **Vault** first (not the pool) or the swap reverts / is default-DENYed.
- `recipient`/`sender` other than the vault leaks funds — refuse.
- `limit = 0` (for GIVEN_IN) is an unbounded-slippage swap — refuse; floor it from a fresh query.
- `userData` is `0x` for standard pools; non-empty only for specific pool types — do not hand-craft it.

### safety
- `queryBatchSwap` (read-only) prices the swap; re-read immediately before sending to keep `limit` honest.
- Output lands with the vault via `funds.recipient`; confirm it is the vault, not internal balance.

## action: batchSwap
**Function:** `batchSwap(uint8 kind, (bytes32 poolId, uint256 assetInIndex, uint256 assetOutIndex, uint256 amount, bytes userData)[] swaps, address[] assets, (address sender, bool fromInternalBalance, address recipient, bool toInternalBalance) funds, int256[] limits, uint256 deadline)`
**Contract:** role `vault` (registry: `dex/balancer-v2/vault`)
**Use when:** a multi-hop swap across several pools (e.g. USDC → WETH → wstETH) in one call.

### params
- `kind` — `0 = GIVEN_IN`.
- `assets` — the deduplicated list of all tokens in the route; each `swaps[].assetInIndex`/`assetOutIndex`
  points into this array. Order and indices MUST be consistent or funds route wrong.
- `limits` — per-asset signed bounds: positive = max you send, negative = **min you receive** (the slippage
  floor on the final leg). Derive from `queryBatchSwap`; the output-token limit **must not be 0.**
- `funds` — `sender` and `recipient` both **the vault**; both internal-balance flags `false`.

### pitfalls
- A mis-indexed `assetInIndex`/`assetOutIndex` swaps the wrong hop — resolve indices against `assets` exactly.
- Leaving the negative output `limit` at 0 removes the slippage floor — refuse; set it from the query.
- Approve only the first-hop input token to the Vault; intermediate hops stay inside the Vault.

### safety
- Price the whole path with `queryBatchSwap` at send time; intermediate liquidity moves between quote and send.

## action: joinPool
**Function:** `joinPool(bytes32 poolId, address sender, address recipient, (address[] assets, uint256[] maxAmountsIn, bytes userData, bool fromInternalBalance) request)`
**Contract:** role `vault` (registry: `dex/balancer-v2/vault`)
**Use when:** depositing tokens to mint a pool's BPT (LP) shares.

### params
- `sender` — **the vault** (whose tokens are pulled). `recipient` — **the vault** (who receives BPT).
- `request.assets` — the pool's full token list in the pool's canonical order (include the BPT slot for
  composable-stable pools); resolve exactly against the pool.
- `request.maxAmountsIn` — the ceiling per token you will contribute, in each token's decimals.
- `request.userData` — ABI-encodes the join kind + amounts + **minimum BPT out** (the slippage floor).
  Encode `minBPTOut` from a query; **never 0.** Do not hand-wave the encoding.

### pitfalls
- Approve every contributed token to the **Vault** first.
- The `assets` array order and (for composable pools) the BPT-in-array slot are pool-specific — a wrong
  order deposits into the wrong slots.
- Omitting / zeroing `minBPTOut` inside `userData` removes the mint floor — refuse.

### safety
- BPT is minted to `recipient` = the vault; confirm no third-party recipient and `fromInternalBalance = false`.
