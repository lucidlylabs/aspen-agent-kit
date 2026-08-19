---
protocol: moonwell
category: credit
chains: [8453, 10]
archetype: lend_borrow
executor: knowledge-only
aliases:
  - "supply USDC to moonwell"
  - "earn yield on moonwell"
  - "borrow against my ETH on moonwell"
  - "post collateral on moonwell base"
  - "repay my moonwell loan"
  - "withdraw from moonwell"
  - "lend cbBTC on moonwell"
roles: [mtoken, comptroller]
actions: [mint, borrow, repayBorrow, redeemUnderlying]
tokens: [USDC, WETH, cbBTC, DAI]
---

# Moonwell

Moonwell is a pooled, cross-collateral lending market (a Compound v2 fork) on Base and Optimism. You supply an
asset to its **mToken** market (role `mtoken`) — `mint` deposits the underlying and mints mTokens that accrue
supply interest. Enabling a supplied market as collateral (via the **Comptroller**, role `comptroller`,
`enterMarkets`) lets you `borrow` other assets against it. Account health is judged by the Comptroller across
all entered markets. Amounts are always in the **underlying's** decimals; mToken exchange-rate math is
internal.

> **executor: knowledge-only.** No engine executor runs this archetype yet; the harness will
> `needs_research` a Moonwell request until a `lend_borrow` executor exists. This file is the knowledge the
> author + future executor build against.

## action: mint
**Function:** `mint(uint256 mintAmount)`
**Contract:** role `mtoken` (registry: `credit/moonwell/mtoken`)
**Use when:** supplying an asset to earn yield and/or make it available as collateral.

### params
- `mintAmount` — in the **underlying's** decimals; scale from the token book, never a hardcoded 10^n.
- The mToken is picked by the asset being supplied — one mToken market per underlying.

### pitfalls
- Approve the underlying to the `mtoken` first (the market pulls on `mint`).
- Supplying does **not** enable collateral — call the Comptroller's `enterMarkets` for this mToken before
  borrowing against it.
- Compound-v2 forks return a **uint error code** instead of reverting on some failures; a non-zero return is
  a failed supply — don't treat the call as success on code ≠ 0.

### safety
- The minted mTokens are held by `msg.sender` (the vault); there is no recipient arg to misdirect.

## action: borrow
**Function:** `borrow(uint256 borrowAmount)`
**Contract:** role `mtoken` (registry: `credit/moonwell/mtoken`)
**Use when:** drawing a loan of an asset against collateral you've entered.

### params
- `borrowAmount` — in the **borrowed** underlying's decimals; the tokens go to `msg.sender` = the vault.

### pitfalls
- Reverts / returns an error unless the backing markets are `enterMarkets`-ed on the Comptroller first.
- Borrowing from the wrong mToken market draws the wrong asset — match the market to the intended borrow.

### safety
- After the borrow the account's **liquidity (collateral × factor − borrows) must stay positive** with a
  buffer; refuse a borrow that drives account liquidity to/near zero — a price move liquidates it.

## action: repayBorrow
**Function:** `repayBorrow(uint256 repayAmount)`
**Contract:** role `mtoken` (registry: `credit/moonwell/mtoken`)
**Use when:** paying down a borrow to restore account liquidity or close the position.

### params
- `repayAmount` — in the borrowed underlying's decimals. Pass `type(uint256).max` (`-1`) to repay the
  **full** current debt (no dust).
- Approve the underlying to the borrowed-asset `mtoken` first.

### pitfalls
- Repay the **same** mToken market the debt sits in; repaying a different market does nothing for the loan.

### safety
- Repay before redeeming the collateral that backs it, or the redeem drops account liquidity below zero and
  fails.

## action: redeemUnderlying
**Function:** `redeemUnderlying(uint256 redeemAmount)`
**Contract:** role `mtoken` (registry: `credit/moonwell/mtoken`)
**Use when:** withdrawing supplied assets (plus accrued yield) back out, denominated in the underlying.

### params
- `redeemAmount` — amount of **underlying** to pull, in its decimals (cleaner than `redeem`, which takes
  mToken share units). Cap to the supplied balance.

### pitfalls
- Redeeming collateral while a borrow is open can push account liquidity negative and **fail** — repay first.
- `redeem(uint256 redeemTokens)` takes mToken units, not underlying — don't confuse the two; use
  `redeemUnderlying` for asset-denominated amounts.

### safety
- Only redeem down to the buffer above zero account liquidity; a full redeem of collateral requires its debt
  fully repaid.
