---
protocol: across
category: bridge
chains: [1, 10, 137, 8453, 42161]
archetype: bridge_transfer
executor: knowledge-only
aliases:
  - "bridge USDC to arbitrum with across"
  - "move WETH from base to mainnet"
  - "send USDC cross-chain via across"
  - "bridge my funds to optimism"
  - "fast bridge USDC to base"
  - "speed up my stuck across deposit"
roles: [spokePool]
actions: [depositV3, speedUpV3Deposit]
tokens: [USDC, WETH, DAI]
---

# Across

Across is an intents-based bridge: you lock the input token in the origin **SpokePool** (role `spokePool`)
and a relayer fronts the output token on the destination chain immediately, later reimbursed from a
unified liquidity hub. Bridging is a single origin-chain call, `depositV3`; the relayer-fronted output
lands at the `recipient` on the destination chain.

> **executor: knowledge-only.** No engine executor runs the `bridge_transfer` archetype yet; the harness
> will `needs_research` an Across request until a `bridge_transfer` executor exists. This file is the
> knowledge that executor is built against.

## action: depositV3
**Function:** `depositV3(address depositor, address recipient, address inputToken, address outputToken, uint256 inputAmount, uint256 outputAmount, uint256 destinationChainId, address exclusiveRelayer, uint32 quoteTimestamp, uint32 fillDeadline, uint32 exclusivityDeadline, bytes message) payable`
**Contract:** role `spokePool` (registry: `bridge/across/spokePool`)
**Use when:** bridging a token from the current chain to another supported chain.

### params
- `depositor` — the vault on the origin chain (who is locking the input).
- `recipient` — **MUST be the vault (its address on the destination chain).** This is who receives the
  bridged funds; a wrong recipient loses them irrecoverably.
- `inputToken` / `outputToken` — the origin token and its destination-chain equivalent, resolved from the
  token book per chain (they are different addresses on different chains).
- `inputAmount` — in `inputToken` decimals; scale from the token book, never a hardcoded 10^n.
- `outputAmount` — `inputAmount` minus the Across relay fee (the fee is `inputAmount - outputAmount`).
  **Derive it from the Across suggested-fees quote; never set it equal to `inputAmount` (0 fee = never filled)
  and never set it so low you overpay the relayer.**
- `destinationChainId` — the numeric chain id of the destination. `quoteTimestamp` — from the fee quote,
  must be recent. `fillDeadline` — a near-future timestamp after which an unfilled deposit is refundable.
- `exclusiveRelayer` / `exclusivityDeadline` — `address(0)` / `0` for an open (non-exclusive) fill.

### pitfalls
- Approve `inputToken` to the `spokePool` first (unless bridging native, in which case pass value) — the
  approve leg must be in the plan.
- `recipient` set to the origin-chain address blindly can be wrong if the vault has a different address on
  the destination — resolve the vault's destination address explicitly.
- A stale `quoteTimestamp` / mispriced `outputAmount` makes the deposit unfillable — always bridge against
  a fresh fee quote.
- `outputToken = address(0)` (auto-resolve) is convenient but confirm it maps to the token you expect.

### safety
- The `recipient` is the whole security surface of a bridge — it must be the vault or its verified
  destination-chain address, never a third party. Refuse otherwise.
- Set a real `fillDeadline` so a stuck deposit becomes refundable rather than lost; a `message` payload
  (arbitrary destination call) should be empty unless the strategy explicitly composes one.

## action: speedUpV3Deposit
**Function:** `speedUpV3Deposit(address depositor, uint32 depositId, uint256 updatedOutputAmount, address updatedRecipient, bytes updatedMessage, bytes depositorSignature)`
**Contract:** role `spokePool` (registry: `bridge/across/spokePool`)
**Use when:** a submitted deposit is sitting unfilled and you want to raise the relayer incentive (lower
`updatedOutputAmount`) so it fills.

### params
- `depositor` / `depositId` — identify the original deposit. `updatedOutputAmount` — the new (lower)
  output, i.e. a higher relay fee; still bounded, not a giveaway.
- `updatedRecipient` — **keep it the vault**; changing it re-routes the funds.
- `depositorSignature` — signed by the original `depositor` over the update.

### pitfalls
- `updatedOutputAmount` can only be lowered (fee raised), never raised; an out-of-range value is rejected.
- Changing `updatedRecipient` away from the vault redirects the bridged funds — refuse.

### safety
- Only use this to unstick a legitimately slow deposit; keep the recipient invariant and cap how far you
  raise the fee.
