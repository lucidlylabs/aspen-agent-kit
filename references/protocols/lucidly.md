---
protocol: lucidly
category: yield
chains: [1, 42161, 8453, 747474]
archetype: vault
executor: knowledge-only
aliases:
  - "deposit into syUSD"
  - "mint syUSD"
  - "get syUSD"
  - "stake USDC for syUSD"
  - "earn the lucidly yield"
  - "withdraw from syUSD"
  - "redeem syUSD"
  - "request a syUSD withdrawal"
roles: [vault, teller, queue]
actions: [deposit, request_withdraw]
tokens: [syUSD, USDC]
---

# Lucidly

Lucidly (docs.lucidly.finance) is a yield-infrastructure protocol; **syUSD** ("Stable Yield USD") is its
flagship USDC-denominated product — a managed, medium/long-horizon yield vault that takes leveraged
positions on lending markets (Morpho, Aave v3) via bluechip collateral, with allocation decided by the
Lucidly team (not on-chain-automated).

> **Same contract FAMILY as this app's own vault rails, but a completely different, external vault.**
> syUSD is a `BoringVault` stack — `BoringVault` + `TellerWithLayerZero` (a `TellerWithMultiAssetSupport`) +
> `BoringOnChainQueue` — the identical Solidity base this codebase's OWN `@aspen/sdk` vaults descend from
> (see the root `CLAUDE.md` §1/§2). Do not confuse Lucidly's `vault`/`teller`/`queue` roles here with the
> user's OWN connected Aspen vault — depositing into syUSD is taking a POSITION in an external protocol,
> exactly like Ethena/Cap/Sky, not a variant of the user's own vault operations.

> **NOT a plain ERC4626 — does not fit the generic `vault_mint_redeem` compose blocks.** Deposit is a
> 3-arg `deposit(asset, amount, minimumMint)` with **no `receiver` argument** (shares always mint to
> `msg.sender`), and exit is an **asynchronous, two-step withdrawal queue** (request now, a solver fulfills
> later — never a synchronous `redeem`). Both differ from the `makeVaultBlocks()` factory's assumed
> `deposit(assets,receiver)` / `redeem(shares,receiver,owner)` shape (see `compose/vaultBlocks.ts`).
> **executor: knowledge-only** — documented here for a future bespoke, async-aware executor.

## action: deposit
**Function:** `deposit(ERC20 _depositAsset, uint256 _depositAmount, uint256 _minimumMint)`
**Contract:** role `teller` (registry: `yield/lucidly/teller`, `TellerWithLayerZero`)
**Use when:** depositing USDC (or another whitelisted asset) to mint syUSD.
**Publicly callable** — open to any wallet, no allowlisting needed (the sibling `bulkDeposit(...,address to)`
exists but is `SOLVER_ROLE`-gated; do not use it here).

### params
- `_depositAsset` — the asset to deposit. syUSD is marketed as USDC-denominated; **never assume another
  asset is accepted** — a real integration must read the Teller's live `assetData[_depositAsset]
  .allowDeposits` before offering a choice.
- `_depositAmount` — amount of `_depositAsset`, scaled by that asset's own decimals (USDC = 6dp).
- `_minimumMint` — slippage floor on syUSD shares received; **never 0**.

### pitfalls
- **The approve target is the `vault` role (the `BoringVault` contract itself), NOT the `teller`.** The
  Teller calls `vault.enter(...)`, which does `depositAsset.safeTransferFrom(msg.sender, vault, amount)` —
  approving the Teller does nothing; the approve leg must target `vault`.
- No `receiver` argument exists on this entrypoint — shares mint to `msg.sender` only. A vault/burner
  calling this receives its own syUSD; there is no way to mint to a third party here (that's the
  `SOLVER_ROLE`-gated `bulkDeposit`, out of scope for a self-custody caller).
- syUSD is 6dp (matching its USDC-denominated design) — do **not** assume 18dp by analogy to Ethena's
  sUSDe / Cap's stcUSD; scale from the token book, never a hardcoded 10^n.

### safety
- `_minimumMint` of 0 removes slippage protection entirely — refuse.

## action: request_withdraw
**Function:** `requestOnChainWithdraw(address _assetOut, uint128 _amountOfShares, uint16 _discount, uint24 _secondsToDeadline)`
**Contract:** role `queue` (registry: `yield/lucidly/queue`, `BoringOnChainQueue`)
**Use when:** starting an exit from syUSD — **this does NOT return `_assetOut` immediately.**

### params
- `_assetOut` — the asset to receive once the request is fulfilled (e.g. USDC).
- `_amountOfShares` — the syUSD amount to redeem (6dp).
- `_discount` — in bps, how much below fair value you're willing to accept to incentivize a solver to fill
  the request faster; 0 = no discount (slowest, but no value given up). **Never a large discount by
  default** — that is real value surrendered, must be an explicit, bounded user choice.
- `_secondsToDeadline` — how long the request stays valid before it expires (bounded by the queue's
  `MAXIMUM_SECONDS_TO_MATURITY`/deadline limits); an expired, unfulfilled request must be cancelled
  (`cancelOnChainWithdraw`, not modeled here) to recover the escrowed shares.

### pitfalls
- **Approve syUSD shares to the `queue` contract first** (not the `teller`, not the `vault`) — the queue
  calls `boringVault.safeTransferFrom(msg.sender, address(this), amountOfShares)`, escrowing the shares
  immediately even though the asset payout is deferred.
- **This is asynchronous.** The shares leave the caller's balance right away, but `_assetOut` lands only
  once a solver fulfills the request (a separate, later transaction the caller does not control the timing
  of) — a strategy that assumes a synchronous redeem (fire the request, immediately have the asset) will
  break. Any executor built on this needs a poll/reconcile step, not a single-tick assume-it's-done.
- A request can be replaced (`replaceOnChainWithdraw`) or cancelled (`cancelOnChainWithdraw`) before it's
  fulfilled — not modeled here; needed for a real executor to recover from a stuck/expired request.

### safety
- `_discount` is real economic value given up to get faster execution — never default it to a nonzero
  value; surface it explicitly if a user wants faster settlement.
- The escrowed shares are gone from the caller's balance the instant this call lands, before any asset is
  received — an executor must track the pending request (its `requestId`) to avoid double-counting or
  losing track of in-flight capital.
