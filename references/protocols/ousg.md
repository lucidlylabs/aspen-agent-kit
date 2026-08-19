---
protocol: ousg
category: yield
chains: [1, 137]
archetype: deposit_vault
executor: knowledge-only
aliases:
  - "subscribe to OUSG with USDC"
  - "mint OUSG from USDC"
  - "buy qualified-access US treasuries"
  - "hold short-term treasuries on-chain"
  - "redeem my OUSG back to USDC"
roles: [manager]
actions: [subscribe, redeem]
tokens: [USDC, OUSG]
---

# Ondo OUSG

**OUSG** is Ondo's **qualified-access** token backed by short-term US Treasuries (via BlackRock's BUIDL and
similar underlying funds). Unlike USDY, OUSG is restricted to **qualified purchasers / institutional
investors** who complete Ondo's stricter accredited/qualified-purchaser onboarding — a materially higher
eligibility bar than USDY's general non-US KYC. OUSG is an accumulating ERC20 (price rises against USD;
balance is fixed, same mechanic as USDY). Minting and redemption run through a chain-specific **Manager**
contract (role `manager`): **`OUSG_InstantManager`** on Ethereum, **`CashManager`** on Polygon — both expose
the same `subscribe`/`redeem` shape, verified on-chain 2026-07-15 against each contract's published ABI.
Ethereum also carries a separate on-chain `OndoIDRegistry` + `OndoOracle` (investor eligibility + pricing
infra the manager reads internally) and Polygon a separate investor `Registry` — neither is a call target
for a strategy wallet, so they are not modeled as skill actions here.

> **executor: knowledge-only for the `subscribe`/`redeem` mint path** — same eligibility/compliance-stack
> gap as `ondo-usdy`, plus a STRICTER qualified-purchaser bar. A disposable strategy burner can never clear
> either, so this cleanly `needs_research` forever, not a gap to fill.
>
> **Practical test path: the DEX-AGGREGATOR SWAP.** OUSG is registered as a plain token
> (`strategy/tokenBook.ts`, chains 1 + 137), so `swap_via_aggregator`/`close_via_aggregator` are the
> already-wired path — same pattern as `ondo-usdy`. See `compose/examples.ts` `SWAP_THEN_OUSG`.

## action: subscribe
**Function:** `subscribe(address token, uint256 amount, uint256 minReceived)`
**Contract:** role `manager` (registry: `yield/ousg/manager` — Ethereum `OUSG_InstantManager`, Polygon `CashManager`)
**Use when:** minting OUSG by depositing an accepted stablecoin (USDC).

### params
- `token` — the accepted subscription token address (USDC); resolve from the token book, never guess.
- `amount` — the deposit amount in **the token's own decimals** (6 for USDC); scale from the token book.
- `minReceived` — the minimum OUSG out (18 decimals); a slippage/price floor — never pass 0.
- OUSG is minted **to the caller** (`msg.sender`) — the caller **MUST be the vault.**
- A `subscribeRebasingOUSG(address, uint256, uint256)` variant exists on the Ethereum manager (same shape);
  unlike USDY there is no separate rebasing token registered here — treat it as out of scope until needed.

### pitfalls
- Approve the subscription token to the `manager` first (approve leg must be in the plan).
- **Eligibility is stricter than USDY** — OUSG is qualified-purchaser-gated; a wallet that hasn't cleared
  Ondo's institutional onboarding will have its subscription rejected upstream regardless of on-chain calldata.
- A minimum subscription size applies (`setMinimumDepositAmount`) and is typically large (institutional-scale).

### safety
- Yield accrues in the OUSG price; there is no separate claim. Read the current price/rate before computing
  `minReceived` — do not treat 1 OUSG as 1 USD.

## action: redeem
**Function:** `redeem(uint256 amount, address token, uint256 minReceived)`
**Contract:** role `manager` (registry: `yield/ousg/manager`)
**Use when:** redeeming OUSG back to an accepted stablecoin (USDC).

### params
- `amount` — the OUSG amount to redeem (18 decimals).
- `token` — the accepted redemption token to receive (USDC); resolve from the token book.
- `minReceived` — the minimum stablecoin out; a slippage/price floor — never pass 0. Proceeds are returned
  **to the caller** = the vault.

### pitfalls
- Approve OUSG to the `manager` first.
- The stablecoin returned reflects OUSG's current price, not a flat 1:1 — surface the expected proceeds
  before computing `minReceived`.

### safety
- Redeem from the vault only; the settled stablecoin MUST land back in the vault, never an external address.
