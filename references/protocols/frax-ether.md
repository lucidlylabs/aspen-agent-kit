---
protocol: frax-ether
category: staking
chains: [1]
archetype: stake
executor: knowledge-only
aliases:
  - "stake ETH with frax"
  - "get frxETH"
  - "get sfrxETH"
  - "stake ETH into frax ether"
  - "stake and deposit into sfrxETH"
  - "deposit ETH to frax minter"
  - "mint sfrxETH from ETH"
roles: [minter]
actions: [submitAndDeposit, submit]
tokens: [WETH, frxETH, sfrxETH]
---

# Frax Ether

Frax Ether is a two-token ETH staking system. The **frxETH minter** (role `minter`) mints **frxETH** 1:1
against staked ETH — but frxETH itself earns **no** staking yield. Yield accrues only to **sfrxETH**, the
ERC-4626 vault that frxETH is deposited into. `submitAndDeposit` does both steps atomically: stake ETH →
frxETH → sfrxETH, so the vault ends up holding the yield-bearing token directly.

> **executor: knowledge-only.** No engine executor runs the `stake` archetype yet; the harness will
> `needs_research` a Frax Ether request until a `stake` executor exists.

## action: submitAndDeposit
**Function:** `submitAndDeposit(address recipient) payable returns (uint256 shares)`
**Contract:** role `minter` (registry: `staking/frax-ether/minter`)
**Use when:** staking native ETH and landing directly in yield-bearing sfrxETH (the common case).

### params
- **payable — the stake amount is `msg.value` (native ETH), NOT a WETH argument.** Unwrap WETH → ETH
  first if the vault holds WETH.
- `recipient` — **MUST be the vault's own address.** sfrxETH is minted to `recipient`.
- Returns the sfrxETH `shares` minted.

### pitfalls
- Do NOT use plain `submit` when the intent is yield — bare frxETH earns nothing; it must reach sfrxETH.
  `submitAndDeposit` is the yield path.
- `recipient` ≠ the vault mints sfrxETH to someone else — refuse.

### safety
- sfrxETH is minted to `recipient`, which must be the vault. Refuse any framing that sets `recipient` to
  a third party.
- sfrxETH is an ERC-4626 share token worth *more* than 1 frxETH; never treat sfrxETH, frxETH, and ETH as
  1:1 in NAV.

## action: submit
**Function:** `submit() payable`
**Contract:** role `minter` (registry: `staking/frax-ether/minter`)
**Use when:** staking native ETH for plain frxETH only (rare — no yield until it is deposited to sfrxETH).

### params
- **payable — the stake amount is `msg.value` (native ETH), NOT a WETH argument.**
- frxETH is minted 1:1 to `msg.sender` (the vault).

### pitfalls
- frxETH held idle earns **zero** yield — most stake intents actually want `submitAndDeposit`. Only use
  bare `submit` when the user explicitly wants unstaked frxETH (e.g. to LP it).

### safety
- frxETH is minted to the vault. To earn yield it must subsequently be deposited into the sfrxETH
  ERC-4626 vault (a separate `deposit` on that vault), or use `submitAndDeposit` in the first place.
