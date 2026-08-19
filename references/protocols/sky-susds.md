---
protocol: sky-susds
category: yield
chains: [1, 8453]
archetype: deposit_vault
executor: knowledge-only
aliases:
  - "earn the sky savings rate"
  - "put USDS in sUSDS"
  - "stake my USDS for yield"
  - "deposit USDS into sUSDS"
  - "earn yield on USDS"
  - "wrap USDS into sUSDS"
  - "redeem my sUSDS back to USDS"
  - "withdraw from the sky savings rate"
  - "mint sUSDS"
  - "redeem sUSDS for USDS"
  - "swap USDC for USDS"
  - "sell USDC for USDS on the sky psm"
  - "buy USDC with USDS"
  - "convert DAI to USDS"
  - "convert USDS to DAI"
  - "upgrade my DAI to USDS"
roles: [savings, psm, converter]
actions: [deposit, withdraw, redeem, mint, sellGem, buyGem, daiToUsds, usdsToDai]
tokens: [USDS, sUSDS, DAI, USDC]
---

# Sky sUSDS

sUSDS is Sky's (ex-MakerDAO) savings token: an **ERC4626 vault** whose asset is **USDS**. Depositing USDS
mints sUSDS shares that continuously appreciate against USDS at the **Sky Savings Rate (SSR)** — there is no
claim step, yield accrues in the share price. Every action goes through the single sUSDS vault contract
(role `savings`) per chain. USDS is the successor stablecoin to DAI (1:1 convertible via the Sky converter).
Live on **Ethereum (1) and Base (8453)** — the `savings` role and USDS/sUSDS tokens are registered on both.

> **`deposit`/`redeem` below are also the generic `vault_mint_redeem` archetype's `mint`/`redeem` compose
> blocks** (`sky-susds_mint` / `sky-susds_redeem`, `compose/vaultBlocks.ts`) — Sky is the SECOND protocol
> wired through that factory (Ethena's sUSDe vault was first). The fn shapes are already identical to what
> the generic encoder needs, so no separate block-level doc is needed for `mint` — it's the exact same call
> as `deposit`, just named for the archetype.
>
> **executor: knowledge-only.** This flag tracks the OLDER single-skill `dangling` retrieval executor map
> (irrelevant here) — the generic engine DOES run this via the gated `"vault"` capability
> (`loadCatalog({ capabilities: ["vault"] })`), same as Ethena. `withdraw` (the assets-denominated exit) has
> no compose block yet — only the dustless share-denominated `redeem` does; `withdraw` stays knowledge-only.

## action: deposit
**Function:** `deposit(uint256 assets, address receiver)`
**Contract:** role `savings` (registry: `yield/sky-susds/savings`)
**Compose block:** `sky-susds_mint` (intent: `open` — blocked when killed)
**Use when:** putting USDS to work at the Sky Savings Rate.

### params
- `assets` — the USDS amount in **18 decimals**; scale from the token book, never a hardcoded 10^n.
- `receiver` — **MUST be the vault's own address.** The minted sUSDS shares land here.

### pitfalls
- Approve USDS to the `savings` contract first (approve leg must be in the plan).
- `receiver` ≠ the vault mints the shares to someone else — refuse.
- This vault takes **USDS**, not DAI or USDC — convert first (Sky converter / PSM) if the user holds those.

### safety
- Yield is in the share price; there is no separate claim. `redeem`/`withdraw` realizes the accrued SSR.

## action: withdraw
**Function:** `withdraw(uint256 assets, address receiver, address owner)`
**Contract:** role `savings` (registry: `yield/sky-susds/savings`)
**Use when:** pulling a specific USDS amount back out (yield included).

### params
- `assets` — the exact USDS amount wanted out (18 decimals). The vault burns the needed sUSDS.
- `receiver` — **the vault** (where USDS lands). `owner` — **the vault** (whose sUSDS is burned).

### pitfalls
- `owner` must be the vault, and the vault's sUShares must cover the requested `assets` — otherwise reverts.
- Withdrawing to a `receiver` other than the vault leaks funds — refuse.

### safety
- To exit fully without leaving dust, prefer `redeem` with the full share balance over a fixed `assets`.

## action: redeem
**Function:** `redeem(uint256 shares, address receiver, address owner)`
**Contract:** role `savings` (registry: `yield/sky-susds/savings`)
**Compose block:** `sky-susds_redeem` (intent: `reduce` — always allowed through the kill switch)
**Use when:** closing the position — burn sUSDS shares for USDS + accrued yield.

### params
- `shares` — the sUSDS amount to burn; pass the full sUSDS balance for a clean full exit (no dust).
- `receiver` — **the vault.** `owner` — **the vault.**

### pitfalls
- `receiver`/`owner` other than the vault leaks or fails — pin both to the vault.

### safety
- `redeem(fullBalance)` is the dustless close; `withdraw(assets)` leaves residual shares. Prefer redeem to exit.

---

# Sky peg-stability (PSM + DAI/USDS converter)

Two more Sky mechanisms, both **Ethereum-only** (no Base deployment), verified against
`sky-ecosystem/usds-wrappers` (`UsdsPsmWrapper.sol`) and `sky-ecosystem/usds` (`DaiUsds.sol`). Both are fixed-
rate stablecoin EXCHANGES, not vault deposits — no share token, no yield accrual.

## action: sellGem
**Function:** `sellGem(address usr, uint256 gemAmt)`
**Contract:** role `psm` (registry: `yield/sky-susds/psm`, `UsdsPsmWrapper` — Ethereum only)
**Compose block:** `sky_psm_sell` (intent: `open`)
**Use when:** selling USDC for USDS at close to 1:1 (minus the PSM's `tin` fee).

### params
- `gemAmt` — the exact **USDC** amount to sell (6 decimals); scale from the token book, never a hardcoded 10^n.
- `usr` — **MUST be the vault's own address.** The USDS lands here.

### pitfalls
- Approve USDC to the `psm` contract first (approve leg must be in the plan).
- The wrapper takes USDC ("gem") in and issues USDS out — internally it PSM-converts USDC→legacy DAI, then
  converts DAI→USDS via the shared VAT join/exit, so the received USDS is `gemAmt` scaled to 18dp minus `tin`.
- `usr` ≠ the vault mints the USDS elsewhere — refuse.

### safety
- The `tin` fee is set by governance and can be raised to `type(uint256).max` (halting sells) — a stuck
  simulation/revert on this call is expected in that state, not a bug.

## action: buyGem
**Function:** `buyGem(address usr, uint256 gemAmt)`
**Contract:** role `psm` (registry: `yield/sky-susds/psm`, `UsdsPsmWrapper` — Ethereum only)
**Use when:** buying an exact amount of USDC by spending USDS (the reverse of `sellGem`).

> **No compose block — knowledge-only.** The wrapper computes the required USDS pull internally as
> `usdsInWad = gemAmt·1e12 + gemAmt·1e12·psm.tout()/1e18` — a value that depends on a LIVE `tout()` fee read
> and is **not itself a literal arg of the `buyGem` call**. The generic auto-approve encoder can only
> synthesize an approve equal to an existing ABI arg of the SAME call, so it cannot safely size this
> approval without a runtime rate read (the same reason the vault archetype exposes asset-denominated
> `deposit` but not share-denominated `mint`). Wiring this needs a `runtime`-provenance approve amount (a
> live `tout()` quote), the same pattern the DEX-aggregator opaque blocks use — not yet built.

### params
- `gemAmt` — the exact **USDC** amount wanted out (6 decimals).
- `usr` — **MUST be the vault's own address.**

### pitfalls
- The USDS cost is `gemAmt` scaled to 18dp PLUS the `tout` fee — never approve a flat `gemAmt`-equivalent;
  read `psm.tout()` live and add it, or the `transferFrom` inside `buyGem` reverts on insufficient allowance.

### safety
- `usr` ≠ the vault sends the USDC elsewhere — refuse.

## action: daiToUsds
**Function:** `daiToUsds(address usr, uint256 wad)`
**Contract:** role `converter` (registry: `yield/sky-susds/converter`, `DaiUsds` — Ethereum only)
**Compose block:** `sky_dai_to_usds` (intent: `open`)
**Use when:** upgrading legacy DAI to USDS, 1:1, no fee.

### params
- `wad` — the exact **DAI** amount to convert (18 decimals).
- `usr` — **MUST be the vault's own address.** The USDS lands here.

### pitfalls
- Approve DAI to the `converter` contract first (approve leg must be in the plan).
- `usr` ≠ the vault mints the USDS elsewhere — refuse.

### safety
- Genuinely 1:1, no fee, no slippage — the converter is a lock/mint escrow, not a market. `wad` in == `wad`
  out exactly.

## action: usdsToDai
**Function:** `usdsToDai(address usr, uint256 wad)`
**Contract:** role `converter` (registry: `yield/sky-susds/converter`, `DaiUsds` — Ethereum only)
**Compose block:** `sky_usds_to_dai` (intent: `reduce` — always allowed through the kill switch)
**Use when:** converting USDS back to DAI, 1:1, no fee — the reverse of `daiToUsds`.

### params
- `wad` — the exact **USDS** amount to convert (18 decimals).
- `usr` — **MUST be the vault's own address.** The DAI lands here.

### pitfalls
- `usr` ≠ the vault leaks the DAI — refuse.
- The converter's DAI supply is bounded by how much has been locked via prior `daiToUsds` calls system-wide;
  an extreme `wad` can in principle exceed available DAI liquidity (in practice not a retail-size concern).

### safety
- Genuinely 1:1, no fee, no slippage.
