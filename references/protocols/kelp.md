---
protocol: kelp
category: staking
chains: [1]
archetype: stake
executor: knowledge-only
aliases:
  - "restake with kelp"
  - "get rsETH"
  - "mint rsETH"
  - "restake my ETH on kelp"
  - "deposit ETH to kelp dao"
  - "restake stETH with kelp"
  - "deposit an LST into kelp"
roles: [deposit-pool]
actions: [depositETH, depositAsset]
tokens: [WETH, stETH, ETHx, rsETH]
---

# Kelp

Kelp DAO is a liquid **restaking** protocol on EigenLayer. Depositing native ETH or a supported LST
through the **LRT deposit pool** (role `deposit-pool`) mints **rsETH**, a non-rebasing liquid restaking
token (LRT) whose exchange rate against ETH grows as restaking rewards accrue.

> **executor: knowledge-only.** No engine executor runs the `stake` archetype yet; the harness will
> `needs_research` a Kelp request until a `stake` executor exists.

## action: depositETH
**Function:** `depositETH(uint256 minRSETHAmountExpected, string referralId) payable`
**Contract:** role `deposit-pool` (registry: `staking/kelp/deposit-pool`)
**Use when:** restaking native ETH to receive rsETH.

### params
- **payable — the deposit amount is `msg.value` (native ETH), NOT a WETH argument.** Unwrap WETH → ETH
  first if the vault holds WETH.
- `minRSETHAmountExpected` — **slippage floor; MUST be > 0**, computed from the live rate minus a
  tolerance. Never pass `0`.
- `referralId` — an empty string unless one is specified.

### pitfalls
- Kelp enforces per-asset **deposit limits**; a deposit that would exceed the limit reverts. Check
  remaining capacity before sizing.
- Passing `minRSETHAmountExpected = 0` disables slippage protection — refuse (bounded-params invariant).

### safety
- rsETH is minted to `msg.sender` (the vault); there is no `onBehalfOf`. Refuse any framing that
  restakes to a third party.

## action: depositAsset
**Function:** `depositAsset(address asset, uint256 depositAmount, uint256 minRSETHAmountExpected, string referralId)`
**Contract:** role `deposit-pool` (registry: `staking/kelp/deposit-pool`)
**Use when:** restaking a supported LST (e.g. stETH, ETHx) instead of native ETH.

### params
- `asset` — the LST address from the token book; **MUST be a Kelp-supported asset** or the call reverts.
- `depositAmount` — in the asset's decimals; scale from the token book, never a hardcoded 10^n.
- `minRSETHAmountExpected` — slippage floor; **MUST be > 0**. `referralId` — empty string unless specified.

### pitfalls
- Approve `asset` to the `deposit-pool` first (the approve leg must be in the plan).
- Depositing an unsupported asset reverts — the matcher must abstain if the token isn't in Kelp's
  supported set.

### safety
- rsETH is minted to the vault. The same per-asset deposit limit applies; a capped deposit reverts.
