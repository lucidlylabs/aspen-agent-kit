---
protocol: fluid
category: credit
chains: [1, 42161, 8453]
archetype: lend_borrow
executor: knowledge-only
aliases:
  - "supply USDC to fluid"
  - "lend on fluid to earn yield"
  - "borrow against my ETH on fluid"
  - "open a fluid vault position"
  - "lever up on fluid"
  - "repay my fluid loan"
  - "withdraw from fluid lending"
  - "provide liquidity on fluid dex"
  - "add liquidity to a fluid pool"
  - "remove liquidity from fluid"
  - "open a fluid smart vault"
  - "borrow against a fluid dex position"
roles: [vault, ftoken, pool]
actions: [operate, deposit, withdraw, dexDeposit, dexWithdraw, smartVaultOperate]
tokens: [USDC, USDT, WETH, wstETH, weETH]
---

# Fluid

Fluid (by Instadapp) splits lending into two surfaces. The **Lending** layer is a set of ERC4626 **fTokens**
(role `ftoken`) — deposit an asset, earn supply yield, no borrowing. The **Vault** layer (role `vault`) is
where leverage lives: each Fluid **Vault** is an isolated `(collateral, debt)` market, and a single function
`operate` adjusts collateral and debt together on an NFT-represented position. Positive amounts add
collateral / draw debt; negative amounts withdraw collateral / repay debt — one call can do a full
supply-and-borrow (or repay-and-withdraw) atomically.

> **executor: knowledge-only.** No engine executor runs this archetype yet; the harness will
> `needs_research` a Fluid request until a `lend_borrow` executor exists. This file is the knowledge the
> author + future executor build against.

## action: operate
**Function:** `operate(uint256 nftId, int256 newCol, int256 newDebt, address to)`
**Contract:** role `vault` (registry: `credit/fluid/vault`)
**Use when:** opening, adjusting, levering, or unwinding a collateral+debt position in one call.

### params
- `nftId` — the position's NFT id; pass **`0` to open a new position** (the call mints a fresh NFT owned by
  `msg.sender` = the vault). Reuse the exact existing id to modify a position — a wrong id reverts or edits
  the wrong position.
- `newCol` — **signed**, in the collateral token's decimals. Positive = deposit collateral, negative =
  withdraw. Pass `type(int256).min` to withdraw the **entire** collateral balance.
- `newDebt` — **signed**, in the debt token's decimals. Positive = **borrow**, negative = repay. Pass
  `type(int256).min` to repay the **entire** debt.
- `to` — recipient of any withdrawn collateral / borrowed debt tokens: **MUST be the vault.**

### pitfalls
- Signs are load-bearing: a sign flip turns a repay into a borrow. Never guess — derive each sign from the
  user's intent explicitly.
- Approve the collateral token to the `vault` before a positive `newCol`; native-ETH markets take `value`
  instead.
- The min-int sentinels mean "max" only for the correct field — `type(int256).min` in `newCol` is full
  collateral withdraw, in `newDebt` is full repay; don't cross them.

### safety
- `to` other than the vault leaks borrowed funds / withdrawn collateral — refuse.
- After the op the position **must stay above the vault's liquidation threshold** with a buffer; refuse an
  `operate` that borrows-up or withdraws-down to near the limit.

## action: deposit
**Function:** `deposit(uint256 assets, address receiver)`
**Contract:** role `ftoken` (registry: `credit/fluid/ftoken`)
**Use when:** pure lending — supplying an asset to a Fluid fToken to earn supply yield (no borrow).

### params
- `assets` — in the underlying asset's decimals; scale from the token book, never a hardcoded 10^n.
- `receiver` — **MUST be the vault** (receives the minted fToken shares).

### pitfalls
- Approve the underlying to the `ftoken` first (ERC4626 pulls on `deposit`).
- Use the fToken for the exact asset you mean to lend — each fToken wraps one underlying.

### safety
- `receiver` ≠ the vault mints shares to someone else — refuse.

## action: withdraw
**Function:** `withdraw(uint256 assets, address receiver, address owner)`
**Contract:** role `ftoken` (registry: `credit/fluid/ftoken`)
**Use when:** redeeming lent assets (plus accrued yield) from a Fluid fToken.

### params
- `assets` — amount of **underlying** to pull, in the asset's decimals (ERC4626 `withdraw` is denominated in
  assets, not shares). To exit fully, prefer `redeem(shares,…)` or read the max redeemable first.
- `receiver` — **the vault.** `owner` — **the vault** (whose shares are burned).

### pitfalls
- ERC4626 `withdraw` reverts if `assets` exceeds what the owner's shares back — cap to the redeemable amount.
- `owner` ≠ the vault requires an ERC4626 allowance you don't have — refuse.

### safety
- `receiver` other than the vault leaks funds — refuse.

# Fluid DEX (liquidity provision)

Fluid also runs a **DEX** — a set of concentrated-liquidity pools, one deployed contract per token pair
(role `pool`). Providing liquidity mints a pool **share balance booked to `msg.sender`** (the vault) — it
is NOT an NFT position (no tokenId to track, unlike Uniswap V3/V4). "Perfect" ops are proportional
(shares-in); the blocks here use the plain imperfect `deposit`/`withdraw` (arbitrary token amounts, shares
bounded).

> **executor: knowledge-only.** The compose blocks are built + offline-proven (`compose/fluidDexBlocks.ts`,
> the `lp` capability, bespoke `fluid-dex-liquidity` encoder). Each block is POOL-SPECIFIC (bakes its pool
> into a fixed `<pair>-pool` registry role — no free-text market key). Curated pools (mainnet, on-chain
> verified via `DexResolver.getDexTokens`): USDC/USDT (clean ERC20/ERC20), wstETH/ETH, USDC/ETH.

> **⚠ NATIVE-ETH GATE.** The wstETH/ETH and USDC/ETH pools settle a native-ETH leg, paid as `vault.manage`
> `value`. These are the FIRST native-value blocks in the engine — they need a burner-policy + mandatory-
> simulation relaxation to permit a non-zero `manage` value before they can run LIVE. The clean USDC/USDT
> pool has no native leg and is the primary offline-proof target. Until that relaxation lands, native-leg
> Fluid markets stay offline-only.

## action: dexDeposit
**Function:** `deposit(uint256 token0Amt_, uint256 token1Amt_, uint256 minSharesAmt_, bool estimate_) payable returns (uint256 shares_)`
**Contract:** role `<pair>-pool` (registry: `dex/fluid-dex/<pair>-pool`)
**Use when:** adding liquidity — deposits token0 + token1 (the pool's own ordering) and credits pool shares
to the vault.

### params
- `token0Amt_` / `token1Amt_` — in each token's decimals; the pool's canonical token0/token1 order (the block
  validates the caller's tokens against it — a flip is refused). A single-sided (one leg 0) deposit is allowed.
- `minSharesAmt_` — the slippage floor on shares minted; **MUST be > 0** (never 0 — the encoder also hardcodes
  `estimate_ = false`; `estimate_ = true` REVERTS with an estimate and does not execute).
- **No recipient** — the LP credit always goes to `msg.sender` (the vault).

### pitfalls
- Approve each ERC20 leg to the **pool** first; a native-ETH leg is sent as `value` (NOT approved).
- `estimate_ = true` is a quote-only revert path — never send it live (the encoder forces `false`).

### safety
- Shares credit to the vault (msg.sender) — there is no recipient arg to leak to.

## action: dexWithdraw
**Function:** `withdraw(uint256 token0Amt_, uint256 token1Amt_, uint256 maxSharesAmt_, address to_) returns (uint256 shares_)`
**Contract:** role `<pair>-pool` (registry: `dex/fluid-dex/<pair>-pool`)
**Use when:** removing liquidity — specify the EXACT token0/token1 amounts to receive; `maxSharesAmt_` caps
the pool shares burned (slippage bound). Burns the caller's own pool balance (no approve).

### params
- `token0Amt_` / `token1Amt_` — the EXACT out per side, in each token's decimals.
- `maxSharesAmt_` — the max pool shares burned; **MUST be > 0.** `to_` — **the vault.**

### safety
- `to_` other than the vault leaks the withdrawn tokens — refuse. Both underlying tokens land at `to_`.

# Fluid smart-collateral / smart-debt Vaults (T2 / T3 / T4)

Beyond the T1 vault (`operate(nftId, newCol, newDebt, to)` above), Fluid has **smart** vaults where the
collateral and/or debt is a Fluid **DEX position** (a token0/token1 pair) rather than a single token. The
`operate(...)` signature grows accordingly:

- **T2** — smart collateral + normal debt: `operate(uint256 nftId, int256 newColToken0, int256 newColToken1, int256 colSharesMinMax, int256 newDebt, address to)`
- **T3** — normal collateral + smart debt: `operate(uint256 nftId, int256 newCol, int256 newDebtToken0, int256 newDebtToken1, int256 debtSharesMinMax, address to)`
- **T4** — smart collateral + smart debt: `operate(uint256 nftId, int256 newColToken0, int256 newColToken1, int256 colSharesMinMax, int256 newDebtToken0, int256 newDebtToken1, int256 debtSharesMinMax, address to)`

**Contract:** role `<market>-vault` (registry: `credit/fluid/<market>-vault`). All `payable`.

### sign conventions (LOAD-BEARING)
- **Positive = deposit collateral / borrow debt; negative = withdraw collateral / repay debt.** A single sign
  flip turns a repay into a borrow — NEVER let the model supply a raw sign.
- Each `*SharesMinMax` bound takes the SAME sign as its side's direction: **positive = a max** (depositing/
  borrowing), **negative = a min** (withdrawing/repaying).
- `type(int256).min` = the "full/max" sentinel (full withdraw / full repay of that leg).
- `nftId = 0` opens a NEW position; a nonzero id modifies that exact position. `to` — **the vault.**

> **executor: knowledge-only.** Built + offline-proven as DIRECTIONAL blocks (`compose/fluidVaultBlocks.ts`,
> the `lending` capability, bespoke `fluid-vault-operate` encoder): an `open` block (deposit collateral +/or
> borrow debt, positive magnitudes) and a `reduce` block (repay debt +/or withdraw collateral; pass `"full"`
> for a leg ⇒ `type(int256).min`). The model supplies only positive magnitudes + which market; the encoder
> derives every sign and each leg's pay-in (approve/value) vs pay-out from the block direction — a sign flip
> is unrepresentable. Curated markets (mainnet, on-chain verified via `VaultResolver.getVaultType`): a T4
> (USDC/ETH smart col + smart debt) and a T2 (weETH/ETH smart col, wstETH normal debt). **T3 has a complete
> encoder but NO curated market yet** — a documented gap; register a verified T3 market to enable it.

### pitfalls
- Approve each ERC20 pay-in leg to the **vault**; a native-ETH pay-in leg is sent as `value` (same native-ETH
  live gate as the DEX above).
- `"full"` is only valid on a pay-OUT leg (full collateral withdraw); a `"full"` REPAY pay-in needs a live
  debt read the encoder doesn't have — it is refused fail-closed.

### safety
- After any `open`, the position **must stay above the vault's liquidation threshold** with a buffer — refuse
  a borrow/withdraw that pushes it near the limit.
- `to` other than the vault leaks borrowed funds / withdrawn collateral — refuse.
