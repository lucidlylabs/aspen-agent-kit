---
protocol: ondo-usdy
category: yield
chains: [1]
archetype: deposit_vault
executor: knowledge-only
aliases:
  - "subscribe to USDY with USDC"
  - "mint USDY from USDC"
  - "earn treasury yield with ondo"
  - "buy USDY for yield"
  - "wrap USDY into rebasing rUSDY"
  - "redeem my USDY back to USDC"
  - "hold a treasury-backed yield token"
roles: [manager, rusdy]
actions: [subscribe, redeem, wrap]
tokens: [USDC, USDY, rUSDY]
---

# Ondo USDY

**USDY** is Ondo's yield-bearing token backed by short-term US Treasuries + bank deposits. USDY is an
**accumulating** ERC20 — its price rises against USD (yield is in the price, balance is fixed). Minting and
redemption run through the **USDY Manager** (role `manager`): you subscribe with USDC and, after settlement
(and the standard onboarding/hold window), receive USDY. A separate **rUSDY** wrapper (role `rusdy`) gives a
**rebasing** 1:1-USD representation for venues that expect a stable unit balance. Access is subject to Ondo's
eligibility (non-US, KYC) — this file describes the on-chain shape; the executor must respect eligibility.

> **executor: knowledge-only for the `subscribe`/`redeem` mint path.** Ondo's `subscribe`/`redeem` on the
> Manager, and USDY's own transfer restrictions (an on-chain `AllowlistClientUpgradeable`/
> `SanctionsListClientUpgradeable` compliance stack — verified in the deployed bytecode), both require
> Ondo's off-chain KYC/eligibility onboarding before an address is allowed to hold or move USDY at all. A
> disposable strategy burner can never clear that, so the harness will cleanly `needs_research` a
> `subscribe`/`redeem` request forever — not a gap to fill.
>
> **Practical test path: the DEX-AGGREGATOR SWAP.** USDY is registered as a plain token
> (`strategy/tokenBook.ts`, chains 1 + 42161), so `swap_via_aggregator` (USDC → USDY) / `close_via_aggregator`
> (the exit) are the already-wired, already-live path to get USDY exposure through this harness — the SAME
> quote-off every other swap uses, no new block, no capability gate. If USDY's compliance stack blocks the
> transfer to/from an unwhitelisted wallet, the swap simply fails to route or reverts on-chain — fails
> closed either way, never a forced/guessed execution. See `compose/examples.ts` `SWAP_THEN_USDY`.

## action: subscribe
**Function:** `subscribe(address token, uint256 amount, uint256 minReceived)` (verified 2026-07-15 against the
`USDY_InstantManager` contract's published ABI — an earlier version of this file misnamed this
`requestSubscription(uint256)`, which does not exist on the deployed contract; corrected here)
**Contract:** role `manager` (registry: `yield/ondo-usdy/manager`)
**Use when:** minting USDY by depositing an accepted stablecoin (USDC).

### params
- `token` — the accepted subscription token address (USDC); resolve from the token book, never guess.
- `amount` — the deposit amount in **the token's own decimals** (6 for USDC); scale from the token book,
  never a hardcoded 10^n.
- `minReceived` — the minimum USDY out (18 decimals); a slippage/price floor — never pass 0.
- The USDY is minted **to the caller** (`msg.sender`) — the caller **MUST be the vault.**
- A `subscribeRebasingUSDY(address, uint256, uint256)` variant mints straight into **rUSDY** instead of USDY
  (same param shape) — use it to skip a separate `wrap` call.

### pitfalls
- Approve the subscription token to the `manager` first (approve leg must be in the plan).
- "Instant" manager settlement is typically same-tx on Ethereum, but Ondo's standard onboarding/hold window
  and eligibility checks still apply off-chain before a wallet is allowed to call this at all.
- A minimum subscription size applies (`setMinimumDepositAmount`); a below-minimum deposit reverts.

### safety
- Yield accrues in the USDY price; there is no separate claim. Do not treat 1 USDY as 1 USD — read the
  current price/rate before computing `minReceived`.

## action: redeem
**Function:** `redeem(uint256 amount, address token, uint256 minReceived)` (verified 2026-07-15 against the
`USDY_InstantManager` contract's published ABI — an earlier version of this file misnamed this
`requestRedemption(uint256)`, which does not exist on the deployed contract; corrected here)
**Contract:** role `manager` (registry: `yield/ondo-usdy/manager`)
**Use when:** redeeming USDY back to an accepted stablecoin (USDC).

### params
- `amount` — the USDY amount to redeem (18 decimals).
- `token` — the accepted redemption token to receive (USDC); resolve from the token book.
- `minReceived` — the minimum stablecoin out; a slippage/price floor — never pass 0. The proceeds are
  returned **to the caller** = the vault.
- A `redeemRebasingUSDY(uint256, address, uint256)` variant redeems straight from an **rUSDY** balance
  (same param shape) — use it to skip a separate `unwrap` call.

### pitfalls
- Approve USDY (or rUSDY, for the rebasing variant) to the `manager` first.
- The stablecoin returned reflects USDY's current price, not a flat 1:1 — surface the expected proceeds
  before computing `minReceived`.

### safety
- Redeem from the vault only; the settled stablecoin MUST land back in the vault, never an external address.

## action: wrap
**Function:** `wrap(uint256 _USDYAmount)`
**Contract:** role `rusdy` (registry: `yield/ondo-usdy/rusdy`)
**Use when:** converting accumulating USDY into rebasing **rUSDY** for venues that want a stable unit balance.

### params
- `_USDYAmount` — the USDY amount to wrap (18 decimals). rUSDY is minted **to the caller** = the vault.
- Reverse later with `unwrap(uint256 _rUSDYAmount)` back to USDY, `msg.sender` = the vault.

### pitfalls
- Approve USDY to the `rusdy` contract first (approve leg must be in the plan).
- rUSDY **rebases** (balance grows) — the opposite mechanic to USDY; don't mix accounting between the two.

### safety
- Wrapping/unwrapping is value-preserving (same underlying yield); it only changes the balance representation.
