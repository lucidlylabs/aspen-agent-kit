---
protocol: ether-fi
category: staking
chains: [1]
archetype: stake
executor: knowledge-only
aliases:
  - "stake ETH with ether.fi"
  - "restake with ether.fi"
  - "get eETH"
  - "wrap eETH into weETH"
  - "stake my ETH on etherfi"
  - "deposit ETH to ether.fi liquidity pool"
  - "convert eETH to weETH"
roles: [liquidity-pool, weeth]
actions: [deposit, wrap, unwrap]
tokens: [WETH, eETH, weETH]
---

# ether.fi

ether.fi is a liquid **restaking** protocol. Staking native ETH through the **liquidity pool** (role
`liquidity-pool`) mints **eETH**, a rebasing token that accrues both staking and EigenLayer restaking
rewards. As with Lido's stETH, most DeFi use wraps eETH into **weETH** (role `weeth`) — a non-rebasing
share token — for clean accounting and collateral use.

> **executor: knowledge-only.** No engine executor runs the `stake` archetype yet; the harness will
> `needs_research` an ether.fi request until a `stake` executor exists.

## action: deposit
**Function:** `deposit() payable returns (uint256)`
**Contract:** role `liquidity-pool` (registry: `staking/ether-fi/liquidity-pool`)
**Use when:** staking native ETH to receive eETH.

### params
- **payable — the stake amount is `msg.value` (native ETH), NOT a WETH argument.** Unwrap WETH → ETH
  first if the vault holds WETH.
- Returns the eETH shares; eETH is minted to `msg.sender` (the vault).

### pitfalls
- eETH **rebases**; the credited balance can differ from the deposited wei by a few wei on share
  rounding. Never assert exact-equality on the eETH balance.
- A minimum deposit floor applies; a dust-sized stake reverts.

### safety
- eETH is minted to the vault. There is no `onBehalfOf` — refuse any framing that stakes to a third party.

## action: wrap
**Function:** `wrap(uint256 _eETHAmount) returns (uint256)`
**Contract:** role `weeth` (registry: `staking/ether-fi/weeth`)
**Use when:** converting rebasing eETH into non-rebasing weETH for use as collateral or in DeFi.

### params
- `_eETHAmount` — amount of eETH in 18 decimals; scale from the token book, never a hardcoded 10^n.
- Returns the weETH minted to the vault.

### pitfalls
- Approve eETH to the `weeth` contract first (the approve leg must be in the plan) — wrap pulls eETH via
  `transferFrom`.
- weETH is worth *more* than 1 eETH per token; never treat weETH and eETH balances as 1:1.

### safety
- Wrap only the vault's own eETH; the minted weETH lands in the vault. No recipient argument exists.

## action: unwrap
**Function:** `unwrap(uint256 _weETHAmount) returns (uint256)`
**Contract:** role `weeth` (registry: `staking/ether-fi/weeth`)
**Use when:** converting weETH back into rebasing eETH.

### params
- `_weETHAmount` — amount of weETH in 18 decimals.
- Returns the eETH released to the vault.

### pitfalls
- No approval needed — unwrap burns the caller's own weETH.
- The eETH returned reflects the live share rate, not the amount originally wrapped.

### safety
- Unwrapping does not exit the ETH position; eETH remains staked/restaked. Reaching native ETH requires
  the ether.fi withdrawal flow or a swap.
