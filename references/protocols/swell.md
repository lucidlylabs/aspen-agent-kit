---
protocol: swell
category: staking
chains: [1]
archetype: stake
executor: knowledge-only
aliases:
  - "stake ETH with swell"
  - "get swETH"
  - "mint swETH"
  - "restake with swell"
  - "get rswETH"
  - "stake my ETH on swell"
  - "deposit ETH to swell"
roles: [staking, restaking]
actions: [deposit, depositRestaking]
tokens: [WETH, swETH, rswETH]
---

# Swell

Swell offers both liquid staking and liquid restaking. Staking native ETH through the **swETH** contract
(role `staking`) mints **swETH**, a non-rebasing liquid staking token. Staking through the **rswETH**
contract (role `restaking`) instead mints **rswETH**, a non-rebasing liquid *restaking* token that also
accrues EigenLayer restaking rewards. Both tokens grow in ETH value via their exchange rate rather than
by rebasing.

> **executor: knowledge-only.** No engine executor runs the `stake` archetype yet; the harness will
> `needs_research` a Swell request until a `stake` executor exists.

## action: deposit
**Function:** `deposit() payable`
**Contract:** role `staking` (registry: `staking/swell/staking`)
**Use when:** staking native ETH to receive swETH (liquid staking).

### params
- **payable — the stake amount is `msg.value` (native ETH), NOT a WETH argument.** Unwrap WETH → ETH
  first if the vault holds WETH.
- swETH is minted to `msg.sender` (the vault) at the current exchange rate.

### pitfalls
- A minimum-deposit floor applies; a dust-sized stake reverts.
- swETH is minted at the live rate — do not assert an exact 1:1 swETH amount.

### safety
- swETH is minted to the vault; there is no `onBehalfOf`. Refuse any framing that stakes to a third party.
- swETH's ETH value comes from its exchange rate, not a 1:1 peg — never treat swETH and ETH as equal in NAV.

## action: depositRestaking
**Function:** `deposit() payable`
**Contract:** role `restaking` (registry: `staking/swell/restaking`)
**Use when:** restaking native ETH to receive rswETH instead of swETH (liquid restaking).

### params
- **payable — the stake amount is `msg.value` (native ETH), NOT a WETH argument.** Same `deposit()`
  selector as swETH, but on the `restaking` contract — the target contract is what distinguishes swETH
  from rswETH.
- rswETH is minted to `msg.sender` (the vault).

### pitfalls
- Routing to the wrong contract mints the wrong token — swETH vs rswETH is chosen by the target address
  (via the role), not by the calldata. Resolve the role that matches the requested token.

### safety
- rswETH is minted to the vault. As a restaking token it carries EigenLayer/AVS slashing exposure that
  plain swETH does not — surface that distinction on the consent screen.
