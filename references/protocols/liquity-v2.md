---
protocol: liquity-v2
category: credit
chains: [1]
archetype: cdp
executor: knowledge-only
aliases:
  - "open a trove on liquity"
  - "borrow BOLD against my ETH"
  - "mint BOLD on liquity v2"
  - "set my own interest rate on liquity"
  - "add collateral to my trove"
  - "repay my BOLD loan"
  - "close my liquity trove"
roles: [borrowerOperations]
actions: [openTrove, adjustTrove, closeTrove]
tokens: [WETH, wstETH, rETH, BOLD]
---

# Liquity V2

Liquity V2 is a decentralized CDP that mints the **BOLD** stablecoin against ETH/LST collateral. Unlike V1,
the borrower **sets their own annual interest rate**; that rate determines redemption priority (lowest-rate
troves are redeemed against first). Each collateral type is an isolated **branch** with its own
`BorrowerOperations` contract (role `borrowerOperations`) — WETH, wstETH, and rETH are separate branches, so
resolve the branch for the chosen collateral. A position is a **Trove**, identified by a `troveId`. There is
no shared cross-collateral account; each branch is independent, and each has a per-branch minimum collateral
ratio (MCR).

> **executor: knowledge-only.** No engine executor runs the `cdp` archetype yet; the harness will
> `needs_research` a Liquity request until one exists. This file is the knowledge the author + future
> executor build against.

## action: openTrove
**Function:** `openTrove(address _owner, uint256 _ownerIndex, uint256 _collAmount, uint256 _boldAmount, uint256 _upperHint, uint256 _lowerHint, uint256 _annualInterestRate, uint256 _maxUpfrontFee, address _addManager, address _removeManager, address _receiver)`
**Contract:** role `borrowerOperations` (registry: `credit/liquity-v2/borrower-operations`) — the branch for the chosen collateral.
**Use when:** opening a new CDP: lock collateral, mint BOLD, and set the interest rate.

### params
- `_owner` — **the vault.** `_ownerIndex` — the vault's index for this branch (lets one owner hold multiple troves); the `troveId` derives from `(_owner, _ownerIndex)`.
- `_collAmount` — collateral in the branch token's decimals (18 for WETH/wstETH/rETH); scale from the token book, never a hardcoded 10^n.
- `_boldAmount` — BOLD to mint (18 decimals); must be ≥ the branch minimum debt.
- `_annualInterestRate` — the chosen rate, 1e18-scaled (e.g. 5% = 5e16), within the branch's min/max.
- `_maxUpfrontFee` — slippage cap on the one-time upfront borrow fee; **derive from a quote, never leave unbounded.**
- `_addManager` / `_removeManager` — **the vault** (or zero to lock); a non-vault removeManager can pull collateral — refuse.
- `_receiver` — **the vault** (where minted BOLD lands).

### params (hints)
- `_upperHint` / `_lowerHint` — sorted-list insertion hints for the trove's rate; resolve off-chain (a bad hint costs gas, not safety).

### pitfalls
- Approve `_collAmount` of the collateral token to the `borrowerOperations` branch first (approve leg in the plan).
- Wrong branch = wrong collateral silently — pin the branch to the collateral the user named.
- A non-vault `_receiver`/`_removeManager` leaks the BOLD or lets a third party remove collateral — refuse.

### safety
- The opening **collateral ratio MUST sit safely above the branch MCR** — leave a buffer; an ETH price dip
  otherwise pushes the trove into liquidation (or redemption if the rate is low). Never open at the MCR floor.

## action: adjustTrove
**Function:** `adjustTrove(uint256 _troveId, uint256 _collChange, bool _isCollIncrease, uint256 _boldChange, bool _isDebtIncrease, uint256 _maxUpfrontFee)`
**Contract:** role `borrowerOperations` (registry: `credit/liquity-v2/borrower-operations`)
**Use when:** changing an existing trove — add/remove collateral and/or borrow more / repay BOLD in one call.

### params
- `_troveId` — the vault's trove on this branch.
- `_collChange` + `_isCollIncrease` — collateral delta and direction (increase = add, else withdraw).
- `_boldChange` + `_isDebtIncrease` — BOLD delta and direction (increase = borrow more, else repay).
- `_maxUpfrontFee` — bound the fee on any debt increase; from a quote, never unbounded.

### pitfalls
- Adding collateral needs a prior approve; borrowing more mints BOLD to the vault; repaying burns the vault's BOLD (needs BOLD balance).
- Removing collateral **and** increasing debt together compounds the CR drop — check the resulting ratio.

### safety
- Any adjust that lowers the collateral ratio **MUST keep it above MCR with a buffer** — refuse an adjust
  that drops the trove to/near the liquidation threshold.

## action: closeTrove
**Function:** `closeTrove(uint256 _troveId)`
**Contract:** role `borrowerOperations` (registry: `credit/liquity-v2/borrower-operations`)
**Use when:** fully closing the CDP — repay all BOLD debt and reclaim all collateral.

### params
- `_troveId` — the vault's trove. The vault must hold enough **BOLD** to cover the full debt (it is burned on close).

### pitfalls
- Insufficient BOLD balance to cover debt reverts — ensure the full debt amount of BOLD is in the vault first.
- Collateral is returned **to the vault** (the trove owner); it cannot be redirected — good, keep it so.

### safety
- Closing is the safe full unwind (debt → 0, collateral back to the vault). Prefer it over leaving a dust trove.
