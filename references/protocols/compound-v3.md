---
protocol: compound-v3
category: credit
chains: [1, 8453, 42161, 10]
archetype: lend_borrow
executor: knowledge-only
aliases:
  - "supply USDC to compound"
  - "earn yield on compound v3"
  - "borrow USDC against my ETH on compound"
  - "post wstETH collateral on comet"
  - "repay my compound loan"
  - "withdraw from compound v3"
  - "supply collateral to comet"
roles: [comet]
actions: [supply, withdraw, supplyTo, withdrawTo]
tokens: [USDC, WETH, wstETH, cbBTC]
---

# Compound III (Comet)

Compound III is a **single-borrowable-asset** market: each deployment (a **Comet**, role `comet`) has one
**base asset** you can lend and borrow (e.g. USDC), plus a set of **collateral assets** you can only post to
back a base-asset loan. There is no cross-market pooling — one Comet per base asset per chain. Supplying the
base asset earns yield; supplying a collateral asset earns nothing but lets you **borrow the base asset by
withdrawing it below your supplied balance**. `withdraw` of the base past your balance *is* the borrow;
`supply` of the base *is* the repay.

> **executor: knowledge-only.** No engine executor runs this archetype yet; the harness will
> `needs_research` a Compound III request until a `lend_borrow` executor exists. This file is the knowledge
> the author + future executor build against.

## action: supply
**Function:** `supply(address asset, uint256 amount)`
**Contract:** role `comet` (registry: `credit/compound-v3/comet`)
**Use when:** lending the base asset for yield, posting a collateral asset, **or repaying** an open base
borrow (supplying the base asset first pays down debt, then earns).

### params
- `asset` — the token address, resolved from the token book by symbol. Must be the Comet's base asset **or**
  one of its registered collateral assets — an unlisted asset reverts.
- `amount` — in the asset's decimals; scale from the token book, never a hardcoded 10^n. Pass
  `type(uint256).max` when supplying the **base** asset to repay the exact full debt (no dust).

### pitfalls
- Approve `asset` to the `comet` first (approve leg must be in the plan).
- Supplying to the wrong Comet (mismatched base asset) strands funds in a market you didn't intend.

### safety
- `supply` credits `msg.sender` (the vault). To credit another account use `supplyTo` — never let the model
  redirect the account without cause.

## action: withdraw
**Function:** `withdraw(address asset, uint256 amount)`
**Contract:** role `comet` (registry: `credit/compound-v3/comet`)
**Use when:** pulling supplied collateral/base back out, **or borrowing** the base asset (withdrawing the
base below your supplied balance opens a variable-rate borrow).

### params
- `asset` — base asset to borrow/redeem, or a collateral asset to un-post.
- `amount` — in the asset's decimals. Pass `type(uint256).max` to redeem your **full** base-asset supply
  balance (it will not borrow past it — max only draws down your own position).

### pitfalls
- Withdrawing the base past your supply silently becomes a **borrow** that accrues interest — intended only
  when the plan is a borrow; otherwise it's a mistake.
- Withdrawing collateral while a base borrow is open can push the account under its borrow-collateral
  factor and **revert** (or expose it to liquidation) — repay first.

### safety
- After a borrow-style withdraw the account **must stay above its liquidation collateral factor** with a
  buffer; a borrow that leaves the position near the threshold is refused — a price move liquidates it.

## action: supplyTo
**Function:** `supplyTo(address dst, address asset, uint256 amount)`
**Contract:** role `comet` (registry: `credit/compound-v3/comet`)
**Use when:** supplying (lend/collateral/repay) and crediting the position to a specific account.

### params
- `dst` — **MUST be the vault's own address.** Any other `dst` donates the funds to another account.
- `asset` / `amount` — as in `supply`; approve `asset` to the `comet` first.

### pitfalls
- `dst` ≠ the vault credits someone else's Comet position — refuse.

### safety
- Prefer plain `supply` unless a distinct `dst` is genuinely required; the extra arg is a foot-gun.

## action: withdrawTo
**Function:** `withdrawTo(address to, address asset, uint256 amount)`
**Contract:** role `comet` (registry: `credit/compound-v3/comet`)
**Use when:** redeeming or borrowing and sending the tokens to a specific recipient.

### params
- `to` — **the vault.** `asset` / `amount` — as in `withdraw`.

### pitfalls
- Same borrow-vs-redeem ambiguity as `withdraw`: `to` other than the vault leaks funds — refuse.

### safety
- A borrow-style `withdrawTo` must keep the account above its liquidation collateral factor with a buffer,
  exactly as in `withdraw`.
