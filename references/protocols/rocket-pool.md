---
protocol: rocket-pool
category: staking
chains: [1]
archetype: stake
executor: knowledge-only
aliases:
  - "stake ETH with rocket pool"
  - "get rETH"
  - "mint rETH"
  - "stake my ETH on rocket pool"
  - "deposit ETH to rocket pool"
  - "swap ETH for rETH via rocket pool"
roles: [deposit-pool]
actions: [deposit]
tokens: [WETH, rETH]
---

# Rocket Pool

Rocket Pool is a decentralized ETH liquid-staking protocol. Staking native ETH through the **deposit
pool** (role `deposit-pool`) mints **rETH**, a non-rebasing token whose exchange rate against ETH
increases as staking rewards accrue (its balance stays fixed; its ETH value grows).

> **executor: knowledge-only.** No engine executor runs the `stake` archetype yet; the harness will
> `needs_research` a Rocket Pool request until a `stake` executor exists.

## action: deposit
**Function:** `deposit() payable`
**Contract:** role `deposit-pool` (registry: `staking/rocket-pool/deposit-pool`)
**Use when:** staking native ETH to receive rETH.

### params
- **payable — the stake amount is `msg.value` (native ETH), NOT a WETH ERC20 argument.** Unwrap WETH →
  ETH first if the vault holds WETH.
- rETH is minted to `msg.sender` (the vault) at the current exchange rate.

### pitfalls
- The deposit pool enforces a **maximum pool size**; a deposit that would overflow the pool cap reverts.
  Check available deposit capacity before sizing the stake.
- There is a **minimum deposit** (a small dust floor); a stake below it reverts.
- A per-deposit fee is applied — the rETH received corresponds to ETH net of that fee, not the raw
  `msg.value`. Do not assert an exact rETH amount.

### safety
- rETH is minted to the vault; there is no `onBehalfOf` argument. Refuse any framing that stakes to a
  third party.
- rETH's ETH value is read from its exchange rate, not a 1:1 peg — never treat rETH and ETH as equal
  when computing NAV.
