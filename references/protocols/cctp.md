---
protocol: cctp
category: bridge
chains: [1, 10, 42161, 8453, 137, 43114]
archetype: bridge_transfer
executor: knowledge-only
aliases:
  - "send USDC cross-chain with cctp"
  - "bridge USDC to base via cctp"
  - "burn and mint USDC to arbitrum"
  - "move native USDC cross-chain"
  - "circle cctp bridge USDC to optimism"
  - "redeem my cctp USDC on the destination chain"
roles: [tokenMessenger, messageTransmitter]
actions: [depositForBurn, depositForBurnWithCaller, receiveMessage]
tokens: [USDC]
---

# CCTP (Circle Cross-Chain Transfer Protocol)

CCTP is Circle's canonical USDC bridge: it **burns** native USDC on the origin chain via the
**TokenMessenger** (role `tokenMessenger`) and **mints** native USDC on the destination chain via the
**MessageTransmitter** (role `messageTransmitter`), gated by a Circle-signed attestation. It moves real
USDC (no wrapped IOU, no liquidity pool) but is **two transactions on two chains**: burn here, then
`receiveMessage` there once the attestation is available.

> **executor: knowledge-only.** No engine executor runs the `bridge_transfer` archetype yet; the harness
> will `needs_research` a CCTP request until a `bridge_transfer` executor exists. This file is the
> knowledge that executor is built against.

## action: depositForBurn
**Function:** `depositForBurn(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient, address burnToken) returns (uint64 nonce)`
**Contract:** role `tokenMessenger` (registry: `bridge/cctp/tokenMessenger`)
**Use when:** starting a USDC bridge — burning USDC on the current chain to be minted on the destination.

### params
- `amount` — USDC in 6 decimals; scale from the token book, never a hardcoded 10^n.
- `destinationDomain` — the **CCTP domain id**, NOT the EVM chain id (Ethereum 0, Avalanche 1, Optimism 2,
  Arbitrum 3, Base 6, Polygon 7). Resolve it from the registry.
- `mintRecipient` — the destination recipient as a **bytes32-encoded address**; **MUST be the vault's
  destination-chain address**, left-padded to 32 bytes.
- `burnToken` — USDC on the origin chain, resolved from the token book.

### pitfalls
- Approve `amount` of USDC to the `tokenMessenger` first — the approve leg must be in the plan.
- `destinationDomain` is the CCTP domain, not the chain id — passing the chain id sends to the wrong chain
  or an invalid domain.
- `mintRecipient` is `bytes32`, not `address`; a mis-encoded (unpadded / wrong-byte-order) value mints to a
  dead address and the USDC is unrecoverable.

### safety
- `mintRecipient` is the entire security surface of the burn — bytes32 of the vault's verified
  destination-chain address, never a third party. Refuse otherwise.
- The burn is irreversible; verify the domain + recipient before signing.

## action: depositForBurnWithCaller
**Function:** `depositForBurnWithCaller(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient, address burnToken, bytes32 destinationCaller) returns (uint64 nonce)`
**Contract:** role `tokenMessenger` (registry: `bridge/cctp/tokenMessenger`)
**Use when:** the same as `depositForBurn`, but restricting **who** may call `receiveMessage` on the
destination (e.g. only the vault's own executor / agent).

### params
- Same as `depositForBurn`, plus `destinationCaller` — a **bytes32-encoded address** that is the ONLY
  address allowed to redeem on the destination. Set it to the vault (or its destination executor).

### pitfalls
- If `destinationCaller` is set, only that address can `receiveMessage`; a wrong value **locks** the mint —
  anyone else's redeem reverts. Set `bytes32(0)` (via plain `depositForBurn`) if you want a permissionless redeem.

### safety
- Same recipient rule as `depositForBurn`. Additionally, `destinationCaller` must be an address the vault
  actually controls on the destination, or the funds are stuck.

## action: receiveMessage
**Function:** `receiveMessage(bytes message, bytes attestation) returns (bool success)`
**Contract:** role `messageTransmitter` (registry: `bridge/cctp/messageTransmitter`)
**Use when:** completing the bridge on the **destination chain** — minting the USDC once Circle's
attestation for the burn is available.

### params
- `message` — the raw message bytes emitted by the origin `depositForBurn` (from its log).
- `attestation` — Circle's signature over `message`, fetched from the Circle attestation API once the burn
  finalizes.

### pitfalls
- Calling before the attestation is issued reverts — poll the attestation service until it is `complete`.
- This runs on the **destination** chain; the origin burn tx does not itself deliver funds.

### safety
- `receiveMessage` mints to the `mintRecipient` baked into the burn; it takes no recipient argument, so the
  security decision was already made at burn time — this leg is safe to submit once the attestation is valid.
