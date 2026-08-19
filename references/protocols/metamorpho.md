---
protocol: metamorpho
category: vault
chains: [1, 8453, 42161]
archetype: deposit_vault
executor: knowledge-only
aliases:
  - "deposit into a morpho vault v1"
  - "deposit into a metamorpho vault"
  - "earn yield on a morpho vault"
  - "supply USDC to a curated morpho vault"
  - "put my funds in a morpho earn vault"
  - "withdraw from my metamorpho vault"
  - "redeem my metamorpho shares"
  - "morpho vault yield"
roles: [vault]
actions: [deposit, mint, withdraw, redeem]
tokens: [USDC, WETH, wstETH]
---

# MetaMorpho (Morpho Vault V1)

MetaMorpho, now called **Morpho Vault V1**, is an ERC4626 curated lender on top of Morpho Blue. You deposit
a single loan asset (e.g. USDC) and receive vault shares; a curator allocates the deposits across a
whitelisted set of Morpho Blue markets subject to per-market supply caps. Each vault is its own contract
for one loan asset (role `vault`). Discovery can nominate an instance and `verifyMorphoVaultProvenance`
can prove that the registered V1.1 factory deployed it and that `asset()` matches the intended token, but
the factory is permissionless: neither fact vets its curator or market risk. The exact vault must still be
human/CI-reviewed and registered before execution. Unlike depositing to Morpho Blue directly, the vault
diversifies and rebalances for you; unlike a fixed market, the risk set is the curator's chosen markets.

> **executor: knowledge-only at the protocol-family level.** Aspen's generic ERC4626 graph executor can run
> `morpho-vault_mint` → `morpho-vault_redeem` for an exact instance that has been promoted into the address
> registry and token book. The curated Yearn OG USDC/WETH set runs on Ethereum and Base; the other initial
> instances remain Ethereum-only. Every other MetaMorpho result remains
> discovery-only and fails closed; this card must not make a permissionless family look globally executable.

## action: deposit
**Function:** `deposit(uint256 assets, address receiver)`
**Contract:** selected role `vault` instance; verify through registered `metamorpho.factoryV1_1`
**Use when:** supplying the loan asset to a curated vault to earn diversified lending yield.

### params
- `assets` — in the **loan asset's** decimals; scale from the token book, never a hardcoded 10^n.
- `receiver` — **MUST be the vault's own address** (the depositor holds the shares).

### pitfalls
- Approve the loan asset to the `vault` first (approve leg must be in the plan).
- The deposited asset must equal the vault's `asset()`; a different token reverts / is refused.
- If every underlying market is at its supply cap the deposit reverts — the queue can't place the funds.

### safety
- `receiver` ≠ self mints the shares elsewhere — refuse.
- A MetaMorpho vault inherits the risk of its allocated markets (oracle, LLTV, collateral). Confirm the
  vault's asset and that it is the intended curator's vault, not a same-symbol lookalike.

## action: mint
**Function:** `mint(uint256 shares, address receiver)`
**Contract:** selected role `vault` instance; verify through registered `metamorpho.factoryV1_1`
**Use when:** acquiring an exact number of Vault V1 shares and allowing the required asset amount to vary.

### params
- `shares` — the exact share amount to mint; use `previewMint` to estimate the assets pulled.
- `receiver` — **MUST be the vault's own address.**

### pitfalls
- The required asset amount can move after preview; cap the assets spent in the transaction path.
- Prefer `deposit` when the user's intent specifies an asset amount rather than a share amount.

### safety
- `receiver` != self mints the shares elsewhere — refuse.

## action: withdraw
**Function:** `withdraw(uint256 assets, address receiver, address owner)`
**Contract:** selected role `vault` instance; verify through registered `metamorpho.factoryV1_1`
**Use when:** pulling a specific amount of the loan asset back out.

### params
- `assets` — the **loan asset** amount to withdraw (loan-asset decimals), burning the shares needed.
- `receiver` — **the vault** (where the asset lands). `owner` — **the vault** (whose shares burn).

### pitfalls
- Withdrawable liquidity is bounded by what the underlying markets can free right now; a large withdraw
  can exceed `maxWithdraw` and revert — size to `maxWithdraw`.

### safety
- `receiver` or `owner` ≠ the vault leaks funds or burns someone else's shares — refuse both.

## action: redeem
**Function:** `redeem(uint256 shares, address receiver, address owner)`
**Contract:** selected role `vault` instance; verify through registered `metamorpho.factoryV1_1`
**Use when:** exiting by share count — pass the full share balance for a clean full exit.

### params
- `shares` — the vault-share amount to burn (share decimals). Use the full `balanceOf` for a full exit.
- `receiver` — **the vault**. `owner` — **the vault** (whose shares burn).

### pitfalls
- `redeem` realizes the current share price; a bad-debt event in an allocated market can make assets-out
  below cost.
- Redeeming more shares than the balance reverts — read `balanceOf` first.

### safety
- Prefer `redeem` with the full share balance over `withdraw` for a full exit — it leaves no share dust.
