---
protocol: venus
category: credit
chains: [56, 1, 8453, 42161]
archetype: lend_borrow
executor: knowledge-only
aliases:
  - "supply USDC to venus"
  - "earn yield on venus protocol"
  - "borrow against my BNB on venus"
  - "post collateral on venus"
  - "repay my venus loan"
  - "withdraw from venus"
  - "lend USDT on venus bnb"
roles: [vtoken, comptroller]
actions: [mint, borrow, repayBorrow, redeemUnderlying]
tokens: [USDC, USDT, WBNB, WETH, BTCB]
---

# Venus

Venus is a pooled, cross-collateral lending market (a Compound v2 fork) originating on BNB Chain and now on
Ethereum, Base, and Arbitrum. You supply an asset to its **vToken** market (role `vtoken`) via `mint`, which
deposits the underlying and mints interest-bearing vTokens. Entering a market as collateral through the
**Comptroller** (role `comptroller`, `enterMarkets`) lets you `borrow` other assets; account health is judged
by the Comptroller across entered markets. Venus also runs **Isolated Pools** — each isolated pool has its own
Comptroller and vTokens, so confirm which pool a market belongs to.

> **executor: knowledge-only.** No engine executor runs this archetype yet; the harness will
> `needs_research` a Venus request until a `lend_borrow` executor exists. This file is the knowledge the
> author + future executor build against.

## action: mint
**Function:** `mint(uint256 mintAmount)`
**Contract:** role `vtoken` (registry: `credit/venus/vtoken`)
**Use when:** supplying an asset to earn yield and/or make it available as collateral.

### params
- `mintAmount` — in the **underlying's** decimals; scale from the token book, never a hardcoded 10^n.
- One vToken market per underlying (per pool) — pick the market matching the asset and pool.

### pitfalls
- Approve the underlying to the `vtoken` first (the market pulls on `mint`).
- Supplying does **not** enable collateral — call the Comptroller's `enterMarkets` for this vToken before
  borrowing against it.
- Compound-v2 forks return a **uint error code** on some failures instead of reverting — a non-zero return
  is a failed supply; don't treat code ≠ 0 as success.

### safety
- Minted vTokens are held by `msg.sender` (the vault); there is no recipient arg to misdirect. The native
  `vBNB.mint()` is payable with no arg — use the correct market for native vs. BEP20 assets.

## action: borrow
**Function:** `borrow(uint256 borrowAmount)`
**Contract:** role `vtoken` (registry: `credit/venus/vtoken`)
**Use when:** drawing a loan of an asset against collateral you've entered.

### params
- `borrowAmount` — in the **borrowed** underlying's decimals; the tokens go to `msg.sender` = the vault.

### pitfalls
- Reverts / returns an error unless the backing markets are `enterMarkets`-ed on the correct Comptroller
  first (core pool vs. the market's isolated pool).
- Cross-pool confusion: collateral in one isolated pool does not back a borrow in another.

### safety
- After the borrow the account's **liquidity (collateral × factor − borrows) must stay positive** with a
  buffer; refuse a borrow that drives liquidity to/near zero — a price move liquidates it.

## action: repayBorrow
**Function:** `repayBorrow(uint256 repayAmount)`
**Contract:** role `vtoken` (registry: `credit/venus/vtoken`)
**Use when:** paying down a borrow to restore account liquidity or close the position.

### params
- `repayAmount` — in the borrowed underlying's decimals. Pass `type(uint256).max` (`-1`) to repay the
  **full** current debt (no dust).
- Approve the underlying to the borrowed-asset `vtoken` first.

### pitfalls
- Repay the **same** vToken market (and pool) the debt sits in; a different market does nothing for the loan.

### safety
- Repay before redeeming the collateral that backs it, or the redeem drops account liquidity below zero and
  fails.

## action: redeemUnderlying
**Function:** `redeemUnderlying(uint256 redeemAmount)`
**Contract:** role `vtoken` (registry: `credit/venus/vtoken`)
**Use when:** withdrawing supplied assets (plus accrued yield) back out, denominated in the underlying.

### params
- `redeemAmount` — amount of **underlying** to pull, in its decimals (vs. `redeem`, which takes vToken share
  units). Cap to the supplied balance.

### pitfalls
- Redeeming collateral while a borrow is open can push account liquidity negative and **fail** — repay first.
- `redeem(uint256 redeemTokens)` takes vToken units, not underlying — use `redeemUnderlying` for
  asset-denominated amounts.

### safety
- Only redeem down to the buffer above zero account liquidity; a full redeem of collateral requires its debt
  fully repaid.
