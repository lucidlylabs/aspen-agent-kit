---
protocol: hyperlane
category: bridge
chains: [1, 10, 137, 8453, 42161]
archetype: bridge_transfer
executor: knowledge-only
aliases:
  - "bridge USDC to base with hyperlane"
  - "send tokens cross-chain via hyperlane warp route"
  - "transfer WETH to arbitrum with hyperlane"
  - "dispatch a cross-chain message with hyperlane"
  - "move funds across chains on hyperlane"
  - "quote a hyperlane cross-chain transfer"
roles: [mailbox, warpRoute]
actions: [transferRemote, quoteDispatch, dispatch]
tokens: [USDC, WETH]
---

# Hyperlane

Hyperlane is a permissionless interchain messaging layer. Token bridging runs over a **Warp Route** (role
`warpRoute`, a `TokenRouter`/`HypERC20` collateral-or-synthetic contract) whose `transferRemote` locks/burns
on the origin and mints/releases on the destination. Generic messages go through the **Mailbox** (role
`mailbox`) via `dispatch`. Both pay an interchain-gas fee as `msg.value`, priced by `quoteDispatch`.

> **executor: knowledge-only.** No engine executor runs the `bridge_transfer` archetype yet; the harness
> will `needs_research` a Hyperlane request until a `bridge_transfer` executor exists. This file is the
> knowledge that executor is built against.

## action: transferRemote
**Function:** `transferRemote(uint32 destination, bytes32 recipient, uint256 amount) payable returns (bytes32 messageId)`
**Contract:** role `warpRoute` (registry: `bridge/hyperlane/warpRoute`)
**Use when:** bridging a token cross-chain over its Hyperlane warp route.

### params
- `destination` — the Hyperlane **domain id** of the destination chain (for EVM chains this usually equals
  the chain id, but resolve it from the registry — do not assume).
- `recipient` — the destination recipient as a **bytes32-encoded address**; **MUST be the vault's
  destination-chain address**, left-padded to 32 bytes.
- `amount` — in the token's decimals; scale from the token book, never a hardcoded 10^n.
- `msg.value` — the interchain-gas payment from `quoteDispatch` (or the route's `quoteGasPayment`).

### pitfalls
- For a **collateral** warp route, approve `amount` of the token to the `warpRoute` first — the approve leg
  must be in the plan. (A native/synthetic route may differ.)
- `recipient` is `bytes32`, not `address`; an unpadded / wrong-order value mints to a dead address.
- Underpaying `msg.value` leaves the message undelivered until gas is topped up.

### safety
- `recipient` is the whole security surface — bytes32 of the vault's verified destination address, never a
  third party. Refuse otherwise.
- Confirm the warp route on both chains wraps the token you expect (same asset, correct collateral/synthetic
  pairing) before bridging.

## action: quoteDispatch
**Function:** `quoteDispatch(uint32 destinationDomain, bytes32 recipientAddress, bytes messageBody) view returns (uint256 fee)`
**Contract:** role `mailbox` (registry: `bridge/hyperlane/mailbox`)
**Use when:** pricing the interchain-gas fee to pass as `msg.value` for a `dispatch` (or to size a
`transferRemote` payment) before sending.

### params
- Same `destinationDomain` / `recipientAddress` / `messageBody` you will pass to `dispatch`. Read-only.

### pitfalls
- The quote depends on the message body size and current gas config — re-quote at send time, not once at
  creation.

### safety
- Read-only (`eth_call`); it is not a signed-tx destination and must not be added to the plan's targets.

## action: dispatch
**Function:** `dispatch(uint32 destinationDomain, bytes32 recipientAddress, bytes messageBody) payable returns (bytes32 messageId)`
**Contract:** role `mailbox` (registry: `bridge/hyperlane/mailbox`)
**Use when:** sending a generic interchain message (advanced — most token moves should use `transferRemote`
on the warp route instead).

### params
- `destinationDomain` — the Hyperlane domain id, from the registry.
- `recipientAddress` — the destination **handler** contract as bytes32; for a value-bearing message this
  MUST be a vault-controlled recipient on the destination.
- `messageBody` — the payload the destination recipient will `handle`. `msg.value` — from `quoteDispatch`.

### pitfalls
- `dispatch` only delivers a message; it does not move tokens by itself — a hand-rolled token move via a
  generic message is error-prone. Prefer the warp route.
- A `recipientAddress` that is not a Hyperlane message-recipient contract silently drops the message.

### safety
- Any value-bearing or token-composing message must target a vault-controlled recipient — never a third
  party. Prefer `transferRemote` for plain token bridging; reserve `dispatch` for vetted, composed flows.
