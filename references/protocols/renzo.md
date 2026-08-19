---
protocol: renzo
category: staking
chains: [1]
archetype: stake
executor: knowledge-only
aliases:
  - "restake with renzo"
  - "get ezETH"
  - "mint ezETH"
  - "restake my ETH on renzo"
  - "deposit ETH to renzo"
  - "restake stETH with renzo"
  - "deposit an LST into renzo"
roles: [restake-manager]
actions: [depositETH, deposit]
tokens: [WETH, stETH, wbETH, ezETH]
---

# Renzo

Renzo is a liquid **restaking** protocol built on EigenLayer. Depositing native ETH or a supported LST
through the **RestakeManager** (role `restake-manager`) mints **ezETH**, a non-rebasing liquid restaking
token (LRT) whose exchange rate against ETH grows as restaking rewards accrue.

> **executor: knowledge-only.** No engine executor runs the `stake` archetype yet; the harness will
> `needs_research` a Renzo request until a `stake` executor exists.

## action: depositETH
**Function:** `depositETH(uint256 _referralId) payable`
**Contract:** role `restake-manager` (registry: `staking/renzo/restake-manager`)
**Use when:** restaking native ETH to receive ezETH.

### params
- **payable — the deposit amount is `msg.value` (native ETH), NOT a WETH argument.** Unwrap WETH → ETH
  first if the vault holds WETH.
- `_referralId` — pass `0` (no referral) unless one is specified.
- ezETH is minted to `msg.sender` (the vault).

### pitfalls
- Renzo enforces per-collateral **TVL caps**; a deposit that would exceed the cap reverts. Check
  remaining capacity before sizing.
- ezETH is minted at the live exchange rate — do not assert an exact 1:1 ezETH amount.

### safety
- ezETH is minted to the vault; there is no `onBehalfOf`. Refuse any framing that restakes to a third
  party.

## action: deposit
**Function:** `deposit(address _collateralToken, uint256 _amount, uint256 _referralId)`
**Contract:** role `restake-manager` (registry: `staking/renzo/restake-manager`)
**Use when:** restaking a supported LST (e.g. stETH, wBETH) instead of native ETH.

### params
- `_collateralToken` — the LST address, resolved from the token book by symbol; **it MUST be a
  Renzo-supported collateral** or the call reverts.
- `_amount` — in the LST's decimals; scale from the token book, never a hardcoded 10^n.
- `_referralId` — `0` unless specified.

### pitfalls
- Approve `_collateralToken` to the `restake-manager` first (the approve leg must be in the plan).
- Depositing an unsupported token reverts — the matcher must abstain if the collateral isn't in Renzo's
  supported set rather than guess.

### safety
- ezETH is minted to the vault. The same per-collateral TVL cap applies; a capped deposit reverts.
