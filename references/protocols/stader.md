---
protocol: stader
category: staking
chains: [1]
archetype: stake
executor: knowledge-only
aliases:
  - "stake ETH with stader"
  - "get ETHx"
  - "mint ETHx"
  - "stake my ETH on stader"
  - "deposit ETH to stader"
  - "swap ETH for ETHx via stader"
roles: [stake-pool-manager]
actions: [deposit]
tokens: [WETH, ETHx]
---

# Stader

Stader is an ETH liquid-staking protocol. Staking native ETH through the **stake pool manager** (role
`stake-pool-manager`) mints **ETHx**, a non-rebasing liquid staking token whose exchange rate against
ETH increases as staking rewards accrue.

> **executor: knowledge-only.** No engine executor runs the `stake` archetype yet; the harness will
> `needs_research` a Stader request until a `stake` executor exists.

## action: deposit
**Function:** `deposit(address _receiver) payable returns (uint256)`
**Contract:** role `stake-pool-manager` (registry: `staking/stader/stake-pool-manager`)
**Use when:** staking native ETH to receive ETHx.

### params
- **payable — the stake amount is `msg.value` (native ETH), NOT a WETH argument.** Unwrap WETH → ETH
  first if the vault holds WETH.
- `_receiver` — **MUST be the vault's own address.** ETHx is minted to `_receiver`.
- Returns the ETHx shares minted.

### pitfalls
- A minimum-deposit floor and a **maximum-deposit ceiling** are enforced; a stake below the floor or
  above the ceiling reverts. Size within bounds.
- `_receiver` ≠ the vault mints ETHx to someone else — refuse.

### safety
- ETHx is minted to the `_receiver`, which must be the vault. Refuse any framing that sets `_receiver`
  to a third party.
- ETHx's ETH value comes from its exchange rate, not a 1:1 peg — never treat ETHx and ETH as equal in NAV.
