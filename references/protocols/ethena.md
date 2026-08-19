---
protocol: ethena
category: yield
chains: [1]
archetype: stake
executor: knowledge-only
aliases:
  - "stake USDe for sUSDe"
  - "earn the ethena yield"
  - "stake my USDe"
  - "get sUSDe"
  - "start unstaking my sUSDe"
  - "cooldown my sUSDe"
  - "claim my USDe after cooldown"
  - "mint sUSDe"
  - "redeem sUSDe for USDe"
  - "deposit into the ethena vault"
roles: [staking]
actions: [deposit, cooldownShares, unstake, mint, redeem]
tokens: [USDe, sUSDe]
---

# Ethena

Ethena's staking module lets you stake **USDe** to receive **sUSDe** and earn the protocol's yield. The
staking contract (StakedUSDeV2, role `staking`) is an **ERC4626** vault whose asset is USDe and whose
share is sUSDe; the sUSDe/USDe rate rises as yield accrues. Exiting is **two-step with a cooldown**: you
call a cooldown to burn sUSDe and start the timer, then `unstake` after the cooldown window to claim the
USDe from the silo. While a non-zero cooldown is configured, the plain ERC4626 `withdraw`/`redeem` are
disabled — use the cooldown path.

> **Not USDe primary-market minting.** Ethena also runs a separate primary-market "Mint and Redeem"
> contract where USDe itself is minted against collateral (stETH/USDT/…) — that path is **permissioned**
> (Minter/Redeemer roles held by Ethena-controlled EOAs, gated by an EIP-712-signed order + KYC'd
> benefactor/beneficiary whitelisting), so a self-custody vault/burner can never call it directly. Nothing
> here targets that contract. Everything below is the sUSDe **vault** (mint/redeem SHARES of an already-
> issued USDe, permissionless) — the first protocol wired through the generic `vault_mint_redeem` compose
> primitive (`compose/vaultBlocks.ts`), alongside its own existing `stake` (deposit/cooldown/unstake) actions.

> **executor: knowledge-only.** No engine executor runs the `stake` archetype (or the generic vault
> mint/redeem blocks) yet; the harness will `needs_research` an Ethena request until one exists. This file
> is the knowledge the author + future executor build against.

## action: deposit
**Function:** `deposit(uint256 assets, address receiver)`
**Contract:** role `staking` (registry: `yield/ethena/staking`)
**Use when:** staking USDe to mint sUSDe and start earning yield.

### params
- `assets` — the **USDe** amount to stake (USDe decimals = 18); scale from the token book, never a
  hardcoded 10^n.
- `receiver` — **MUST be the vault's own address** (the sUSDe must mint to the staker).

### pitfalls
- Approve USDe to the `staking` contract first (approve leg must be in the plan).
- sUSDe is the receipt — it is not USDe; don't treat the two as 1:1, the rate is `convertToAssets`.

### safety
- `receiver` ≠ self mints the sUSDe elsewhere — refuse.

## action: cooldownShares
**Function:** `cooldownShares(uint256 shares)`
**Contract:** role `staking` (registry: `yield/ethena/staking`)
**Use when:** starting an unstake by burning sUSDe and moving the USDe into the cooldown silo.

### params
- `shares` — the **sUSDe** amount to redeem (share decimals). Use the full `balanceOf` to exit fully.
  (The sibling `cooldownAssets(uint256 assets)` starts the cooldown by a target USDe amount instead.)

### pitfalls
- This does **not** return USDe immediately — it burns sUSDe and starts the cooldown timer; the USDe is
  claimable only after the cooldown period via `unstake`.
- While cooldown > 0, `withdraw`/`redeem` revert — this is the required exit path; don't reach for ERC4626
  redeem.

### safety
- The USDe held in the silo during cooldown is claimable by the account that started it (the vault); pin
  the eventual `unstake` receiver to the vault.

## action: unstake
**Function:** `unstake(address receiver)`
**Contract:** role `staking` (registry: `yield/ethena/staking`)
**Use when:** claiming the USDe from the silo after the cooldown window has elapsed.

### params
- `receiver` — **the vault** (where the released USDe lands).

### pitfalls
- Calling before the cooldown has elapsed reverts — wait out the full window.
- `unstake` claims the whole silo balance for the account, not a partial amount — cooldown the intended
  amount up front.

### safety
- `receiver` ≠ the vault leaks the unstaked USDe — refuse.

## action: mint
**Function:** `deposit(uint256 assets, address receiver)` — the ERC4626 asset-denominated vault entry
(the generic `vault_mint_redeem` archetype's `mint` block; functionally the same call as `## action:
deposit` above, offered as its own composable primitive so a future ERC4626 vault reuses the identical
shape via `compose/vaultBlocks.ts` `makeVaultBlocks()`).
**Contract:** role `staking` (registry: `yield/ethena/staking`)
**Use when:** minting sUSDe shares by depositing an exact amount of USDe.

### params
- `assets` — the **USDe** amount to spend (18 decimals); scale from the token book, never a hardcoded 10^n.
- `receiver` — **MUST be the vault's own address** — the minted sUSDe shares land there.

### pitfalls
- Approve USDe to the `staking` contract first (approve leg must be in the plan).
- The asset-denominated `deposit` (name how much USDe to spend) is used instead of the share-denominated
  `mint(shares, receiver)` — sizing `mint`'s approve correctly needs a live `previewMint` rate read (the
  sUSDe/USDe rate drifts above 1 as yield accrues), which the generic auto-approve encoder cannot do from
  symbols+numbers alone; `deposit` sidesteps that and is exact.

### safety
- `receiver` ≠ self mints the sUSDe elsewhere — refuse.

## action: redeem
**Function:** `redeem(uint256 shares, address receiver, address owner)` — the ERC4626 share-denominated
vault exit (the generic `vault_mint_redeem` archetype's `redeem` block).
**Contract:** role `staking` (registry: `yield/ethena/staking`)
**Use when:** burning an exact number of sUSDe shares for the USDe they're currently worth — **only when
StakedUSDeV2's cooldown duration is 0**; otherwise this reverts and the `cooldownShares` → `unstake` path
above is the required exit.

### params
- `shares` — the **sUSDe** amount to redeem (18 decimals); use the full `balanceOf` for a clean full exit.
- `receiver` / `owner` — **MUST both be the vault's own address**: `owner` = the vault self-redeems its own
  shares (no ERC20/share approval needed when `msg.sender == owner`); `receiver` is where the released
  USDe lands.

### pitfalls
- **Reverts while `cooldownDuration > 0`** (Ethena's current mainnet configuration is a non-zero cooldown)
  — `withdraw`/`redeem` are disabled by the contract itself in that state, unconditionally, regardless of
  caller. Don't reach for `redeem` as the default exit; use `cooldownShares` → `unstake` unless the
  cooldown is confirmed to be 0.
- `owner` ≠ self would require a spent allowance for someone else's shares — refuse.

### safety
- `receiver`/`owner` ≠ the vault leaks the redeemed USDe or someone else's shares — refuse.
- Redeeming realizes the current share price (principal + accrued yield); no principal loss absent a
  protocol shortfall.
