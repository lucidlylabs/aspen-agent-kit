---
protocol: lido
category: staking
chains: [1]
archetype: stake
executor: knowledge-only
aliases:
  - "stake ETH with lido"
  - "get stETH"
  - "stake my ETH on lido"
  - "wrap stETH into wstETH"
  - "convert stETH to wstETH"
  - "unwrap wstETH back to stETH"
  - "deposit ETH to lido"
roles: [staking, wsteth]
actions: [submit, wrap, unwrap]
tokens: [WETH, stETH, wstETH]
---

# Lido

Lido is the largest ETH liquid-staking protocol. Staking native ETH through the **Lido** contract
(role `staking`) mints **stETH**, a rebasing token whose balance grows as staking rewards accrue.
Because a rebasing balance is awkward for DeFi accounting, most integrations then **wrap** stETH into
**wstETH** (role `wsteth`) — a non-rebasing share token whose balance is fixed while its stETH-value
grows.

> **executor: knowledge-only.** No engine executor runs the `stake` archetype yet; the harness will
> `needs_research` a Lido request until a `stake` executor exists.

## action: submit
**Function:** `submit(address _referral) payable returns (uint256)`
**Contract:** role `staking` (registry: `staking/lido/staking`)
**Use when:** staking native ETH to receive stETH.

### params
- **payable — sends native ETH as `msg.value`;** it does NOT take WETH. Unwrap WETH → ETH first if the
  vault holds WETH.
- `_referral` — the referral address; pass the zero address (no referral) unless one is specified.
- The stETH is minted to `msg.sender` (the vault).

### pitfalls
- Passing an ERC20 amount argument is wrong — the stake size is `msg.value`, not a calldata field.
- stETH **rebases**; the credited balance can differ from the deposited wei by 1–2 wei on share rounding.
  Never assert exact-equality on the returned stETH balance.

### safety
- The ETH goes to the vault's own stETH balance. There is no `onBehalfOf` — refuse any framing that
  implies staking to a third party.

## action: wrap
**Function:** `wrap(uint256 _stETHAmount) returns (uint256)`
**Contract:** role `wsteth` (registry: `staking/lido/wsteth`)
**Use when:** converting rebasing stETH into non-rebasing wstETH for use as DeFi collateral.

### params
- `_stETHAmount` — amount of stETH in 18 decimals; scale from the token book, never a hardcoded 10^n.
- Returns the wstETH minted to the vault.

### pitfalls
- Approve stETH to the `wsteth` contract first (the approve leg must be in the plan) — wrap pulls stETH
  via `transferFrom`.
- wstETH is worth *more* than 1 stETH per token; do not treat wstETH and stETH balances as 1:1.

### safety
- Wrap only the vault's own stETH; the minted wstETH lands in the vault. No recipient argument exists.

## action: unwrap
**Function:** `unwrap(uint256 _wstETHAmount) returns (uint256)`
**Contract:** role `wsteth` (registry: `staking/lido/wsteth`)
**Use when:** converting wstETH back into rebasing stETH.

### params
- `_wstETHAmount` — amount of wstETH in 18 decimals.
- Returns the stETH released to the vault.

### pitfalls
- No approval needed — unwrap burns the caller's own wstETH.
- The returned stETH amount reflects the live share rate, not the amount originally wrapped.

### safety
- Unwrapping does not exit the ETH position; stETH is still staked. To reach native ETH, swap or use the
  Lido withdrawal queue (a separate flow).
