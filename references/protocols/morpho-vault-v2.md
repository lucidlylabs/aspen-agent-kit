---
protocol: morpho-vault-v2
category: vault
chains: [1, 8453, 42161, 10]
archetype: deposit_vault
executor: knowledge-only
aliases:
  - "deposit into a morpho vault v2"
  - "earn yield with morpho earn"
  - "supply USDC to a morpho v2 vault"
  - "mint morpho vault shares"
  - "withdraw from morpho earn"
  - "redeem all my morpho vault v2 shares"
  - "morpho vault v2 yield"
roles: [vault]
actions: [deposit, mint, withdraw, redeem]
tokens: [USDC, WETH, wstETH]
---

# Morpho Vault V2

Morpho Vault V2 is an ERC4626 tokenized vault with an adapter-based allocation layer. A vault holds one
underlying asset and can allocate it across configured adapters, including Morpho Market and Morpho Vault
V1 adapters. Each deployed vault is its own contract (role `vault`). Discovery can nominate an instance and
`verifyMorphoVaultProvenance` can prove that the registered V2 factory deployed it and that `asset()` matches
the intended token, but the factory is permissionless: neither fact vets its curator, adapters, or markets.
The exact vault must still be human/CI-reviewed and registered before execution. Never assume that one
address represents all Morpho vaults.

> **executor: knowledge-only.** No engine executor runs the `deposit_vault` archetype yet; the harness
> will `needs_research` a Morpho Vault V2 request until one exists.

## action: deposit
**Function:** `deposit(uint256 assets, address receiver)`
**Contract:** selected role `vault` instance; verify through registered `morpho-vault-v2.factory`
**Use when:** depositing an exact amount of the vault's underlying asset and receiving a variable number
of shares.

### params
- `assets` — in the underlying asset's decimals; use `previewDeposit` to estimate shares before execution.
- `receiver` — **MUST be the Aspen vault's own address.**

### pitfalls
- Approve the underlying asset to the selected vault first (approve leg must be in the plan).
- The asset must equal `asset()` for that vault; same-symbol or unrelated Morpho vaults are not fungible.
- Morpho Vault V2's `maxDeposit` returns zero by design and is not an availability signal. Do not reject
  the action solely because that view returns zero; use a preview/simulation and an explicit amount.

### safety
- `receiver` != self mints the shares to another account — refuse.
- Apply a minimum-shares/slippage guard in the transaction path; a preview is not an execution guarantee.

## action: mint
**Function:** `mint(uint256 shares, address receiver)`
**Contract:** selected role `vault` instance; verify through registered `morpho-vault-v2.factory`
**Use when:** acquiring an exact number of vault shares and allowing the required asset amount to vary.

### params
- `shares` — the exact share amount to mint; use `previewMint` to estimate the assets pulled.
- `receiver` — **MUST be the Aspen vault's own address.**

### pitfalls
- `maxMint` returns zero by design and cannot be used as the mint limit.
- Rounding or share-price movement can increase assets required after preview; enforce a maximum-assets
  bound in the transaction path.

### safety
- Prefer `deposit` for a user-specified asset amount. Use `mint` only when exact shares are intentional.

## action: withdraw
**Function:** `withdraw(uint256 assets, address receiver, address owner)`
**Contract:** selected role `vault` instance; verify through registered `morpho-vault-v2.factory`
**Use when:** withdrawing an exact amount of underlying assets and allowing shares burned to vary.

### params
- `assets` — the exact underlying-asset amount; use `previewWithdraw` to estimate shares burned.
- `receiver` — **the Aspen vault**. `owner` — **the Aspen vault** whose shares burn.

### pitfalls
- `maxWithdraw` always returns zero by design; it does not mean the position is necessarily illiquid.
- Adapter liquidity can still make a withdrawal fail. Preview and simulate the explicit amount near
  execution instead of treating the ERC4626 max view as authoritative.

### safety
- Refuse `receiver` or `owner` != self. Apply a maximum-shares/slippage bound for partial withdrawals.

## action: redeem
**Function:** `redeem(uint256 shares, address receiver, address owner)`
**Contract:** selected role `vault` instance; verify through registered `morpho-vault-v2.factory`
**Use when:** redeeming an exact share amount; use the full share balance for a clean full exit.

### params
- `shares` — shares to burn; use `previewRedeem` to estimate assets returned.
- `receiver` — **the Aspen vault**. `owner` — **the Aspen vault** whose shares burn.

### pitfalls
- `maxRedeem` always returns zero by design and cannot determine whether redemption is available.
- The asset amount can move after preview, and adapter liquidity can constrain execution.

### safety
- Prefer full-balance `redeem` for a full exit so no share dust remains. Enforce minimum assets out and
  refuse `receiver` or `owner` != self.
