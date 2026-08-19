---
protocol: cap
category: yield
chains: [1]
archetype: vault
executor: knowledge-only
aliases:
  - "mint cUSD"
  - "get cUSD"
  - "burn cUSD"
  - "redeem cUSD"
  - "stake cUSD for stcUSD"
  - "earn the cap yield"
  - "get stcUSD"
  - "unstake my stcUSD"
  - "deposit into the cap vault"
  - "deposit into cap"
roles: [vault, staking]
actions: [vault_mint, vault_burn, vault_redeem, mint, redeem]
tokens: [cUSD, stcUSD]
---

# Cap

Cap (docs.cap.app) is a credit-backed stablecoin protocol with TWO distinct contracts that must never be
confused — they share a family name but not a shape:

1. **The cUSD Vault** (role `vault`, `CapToken` — the token contract itself inherits the Vault/Minter/
   FractionalReserve modules). A **multi-asset** basket vault: deposit a whitelisted backing asset to mint
   cUSD, burn cUSD back for a single asset, or redeem cUSD proportionally across every backing asset. This
   is **NOT a plain ERC4626** — every entrypoint carries an explicit `_minAmountOut`/deadline and a asset
   selector, and `redeem` returns an array (one amount per vault asset), not a single value.
2. **The stcUSD staking vault** (role `staking`, `StakedCap`). A **standard ERC4626** vault: deposit cUSD,
   receive stcUSD shares; redeem shares back for cUSD plus accrued yield. This is the leg wired through the
   generic `vault_mint_redeem` compose primitive (`compose/vaultBlocks.ts` `makeVaultBlocks()`), reusing the
   exact same shape as Ethena's sUSDe and Sky's sUSDS — `## action: mint` / `## action: redeem` below.

> **executor: knowledge-only.** No engine executor runs this archetype yet; the harness will
> `needs_research` a Cap request until one exists. The `mint`/`redeem` actions below (the stcUSD leg) ARE
> already composable graph blocks (`cap_mint`/`cap_redeem`, gated behind `loadCatalog({ capabilities:
> ["vault"] })`) — they just have no live composer/executor entry point yet. The `vault_*` actions (the
> cUSD Vault's own multi-asset mint/burn/redeem) are **not** modeled as compose blocks at all: the generic
> asset/share factory only fits a plain two-arg ERC4626 `deposit`/`redeem`, and this entrypoint's 5-arg
> signature (asset selector + slippage + deadline, one-to-many on redeem) does not fit it. Documented here
> as knowledge for a future bespoke block.

## action: vault_mint
**Function:** `mint(address _asset, uint256 _amountIn, uint256 _minAmountOut, address _receiver, uint256 _deadline)`
**Contract:** role `vault` (registry: `yield/cap/vault`)
**Use when:** minting cUSD by depositing a whitelisted backing asset (e.g. USDC).

### params
- `_asset` — the backing asset to deposit. **Never guess the whitelist** — read the live `assets()` array
  on the vault before offering a choice; an asset not in that set reverts with `AssetNotSupported`.
- `_amountIn` — amount of `_asset` to deposit, scaled by that asset's own decimals.
- `_minAmountOut` — slippage floor on the cUSD received; **never 0** — read `getMintAmount(user, asset,
  amountIn)` first and apply a tolerance.
- `_receiver` — **MUST be the vault's own address** (the minted cUSD must land with the depositor).
- `_deadline` — a near-term unix timestamp; a stale/omitted deadline risks execution at a worse price.

### pitfalls
- `_amountIn` is **silently capped** to the remaining deposit cap for that asset — the actual amount
  deposited (and thus cUSD received) may be less than requested; don't assume `_amountIn` fully lands.
- Approve `_asset` to the `vault` contract first (approve leg must be in the plan).

### safety
- `_receiver` ≠ self mints the cUSD elsewhere — refuse.
- `_minAmountOut` of 0 removes slippage protection entirely — refuse.

## action: vault_burn
**Function:** `burn(address _asset, uint256 _amountIn, uint256 _minAmountOut, address _receiver, uint256 _deadline)`
**Contract:** role `vault` (registry: `yield/cap/vault`)
**Use when:** burning cUSD for a SINGLE named backing asset.

### params
- `_asset` — the backing asset to withdraw (must be one the vault currently holds via `assets()`).
- `_amountIn` — cUSD to burn (18 decimals).
- `_minAmountOut` — slippage floor on `_asset` received; never 0.
- `_receiver` — **MUST be the vault's own address**.
- `_deadline` — near-term unix timestamp.

### pitfalls
- Can revert with `InsufficientReserves` if the vault's available balance of `_asset` (supplied minus
  borrowed by Operators) is below the requested amount — a single-asset burn is not always available even
  when the equivalent value exists in OTHER backing assets; `redeem` (below) is the fallback.

### safety
- `_receiver` ≠ self leaks the withdrawn asset — refuse.
- `_minAmountOut` of 0 removes slippage protection entirely — refuse.

## action: vault_redeem
**Function:** `redeem(uint256 _amountIn, uint256[] calldata _minAmountsOut, address _receiver, uint256 _deadline)`
**Contract:** role `vault` (registry: `yield/cap/vault`)
**Use when:** burning cUSD for a **proportional share of every backing asset** at once (the always-available
exit, unlike `vault_burn`'s single-asset path).

### params
- `_amountIn` — cUSD to burn (18 decimals).
- `_minAmountsOut` — **one entry per vault asset, in the exact order `assets()` returns** — read `assets()`
  and `getRedeemAmount(user, amountIn)` live to size this array; a wrong length reverts
  `InvalidMinAmountsOut`, and any entry of 0 removes slippage protection for that asset.
- `_receiver` — **MUST be the vault's own address**.
- `_deadline` — near-term unix timestamp.

### pitfalls
- The receiver ends up holding a BASKET of assets (not a single token) — downstream logic (e.g. a sweep)
  must handle N different assets, not one.

### safety
- `_receiver` ≠ self leaks the withdrawn basket — refuse.
- Any `_minAmountsOut[i] == 0` removes slippage protection for that asset — refuse.

## action: mint
**Function:** `deposit(uint256 assets, address receiver)` — the ERC4626 asset-denominated vault entry (the
generic `vault_mint_redeem` archetype's `mint` block, `compose/vaultBlocks.ts` `makeVaultBlocks()` —
byte-identical shape to Ethena's `sUSDe`/Sky's `sUSDS`).
**Contract:** role `staking` (registry: `yield/cap/staking`, `StakedCap`)
**Use when:** staking cUSD to mint stcUSD and start earning Cap's protocol yield.

### params
- `assets` — the **cUSD** amount to stake (18 decimals); scale from the token book, never a hardcoded 10^n.
- `receiver` — **MUST be the vault's own address** (the stcUSD must mint to the staker).

### pitfalls
- Approve cUSD to the `staking` contract first (approve leg must be in the plan).
- stcUSD is the receipt — not cUSD; don't treat the two as 1:1, the rate is `convertToAssets` /
  `totalAssets()/totalSupply()`, and newly notified yield vests linearly over `lockDuration` (profit-locking
  against flashloan manipulation) — the share price can be temporarily below its eventual settled value
  right after a `notify()`.
- To GET cUSD in the first place (rather than already holding it), see `## action: vault_mint` above — a
  separate, knowledge-only, multi-asset path on a different contract.

### safety
- `receiver` ≠ self mints the stcUSD elsewhere — refuse.

## action: redeem
**Function:** `redeem(uint256 shares, address receiver, address owner)` — the ERC4626 share-denominated
vault exit (the generic `vault_mint_redeem` archetype's `redeem` block).
**Contract:** role `staking` (registry: `yield/cap/staking`, `StakedCap`)
**Use when:** burning an exact number of stcUSD shares for the cUSD (principal + accrued yield) they're
currently worth.

### params
- `shares` — the **stcUSD** amount to redeem (18 decimals); use the full `balanceOf` for a clean full exit.
- `receiver` / `owner` — **MUST both be the vault's own address**: `owner` = the vault self-redeems its own
  shares (no ERC20/share approval needed when `msg.sender == owner`); `receiver` is where the released cUSD
  lands.

### pitfalls
- `owner` ≠ self would require a spent allowance for someone else's shares — refuse.
- Unlike Ethena's sUSDe (which disables plain `redeem` while a cooldown is configured), StakedCap is a
  standard ERC4626 with no cooldown gate documented — `redeem` is the direct exit.

### safety
- `receiver`/`owner` ≠ the vault leaks the redeemed cUSD or someone else's shares — refuse.
- Redeeming realizes the current share price (principal + accrued, vested yield); no principal loss absent
  a protocol shortfall (Cap's stcUSD holders are the last-protected party in the liquidation waterfall —
  see the protocol overview for the underwriter/borrower liquidation mechanics that back this).
