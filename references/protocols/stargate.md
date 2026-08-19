---
protocol: stargate
category: bridge
chains: [1, 10, 137, 8453, 42161, 43114]
archetype: bridge_transfer
executor: knowledge-only
aliases:
  - "bridge USDC to arbitrum with stargate"
  - "move USDT cross-chain via stargate"
  - "send USDC from base to mainnet on stargate"
  - "bridge funds with layerzero stargate"
  - "cross-chain transfer USDC to optimism"
  - "stargate bridge to avalanche"
roles: [router, pool]
actions: [swap, sendToken]
tokens: [USDC, USDT, WETH]
---

# Stargate

Stargate is a LayerZero-based liquidity bridge. It moves a token from a pool on the origin chain to the
same-asset pool on the destination chain, delivering the **native asset** (not a wrapped IOU) to the
recipient. **Stargate v1** bridges via the **Router** (role `router`, function `swap`); **Stargate v2**
bridges via the per-asset **pool/OFT** contract (role `pool`, function `sendToken`). Both charge a native
LayerZero messaging fee passed as `msg.value`.

> **executor: knowledge-only.** No engine executor runs the `bridge_transfer` archetype yet; the harness
> will `needs_research` a Stargate request until a `bridge_transfer` executor exists. This file is the
> knowledge that executor is built against.

## action: swap
**Function:** `swap(uint16 dstChainId, uint256 srcPoolId, uint256 dstPoolId, address payable refundAddress, uint256 amountLD, uint256 minAmountLD, (uint256 dstGasForCall, uint256 dstNativeAmount, bytes dstNativeAddr) lzTxParams, bytes to, bytes payload) payable`
**Contract:** role `router` (registry: `bridge/stargate/router`)
**Use when:** bridging a token cross-chain on **Stargate v1**.

### params
- `dstChainId` — the **LayerZero chain id** (NOT the EVM chain id), resolved from the registry.
- `srcPoolId` / `dstPoolId` — the Stargate pool ids for the asset on each chain (e.g. USDC pool), from the
  registry; they must be the same underlying asset.
- `amountLD` — input amount in local (token) decimals; scale from the token book, never a hardcoded 10^n.
- `minAmountLD` — the minimum received on the destination, the slippage floor. **Derive it from the pool's
  equilibrium fee and the slippage bound; never 0.**
- `refundAddress` — the vault (excess native fee refund). `to` — the destination recipient as **abi-encoded
  bytes of the vault's destination-chain address**; **MUST be the vault.**
- `payload` — empty unless composing a destination call. `msg.value` must cover the LayerZero fee (quote it
  via `quoteLayerZeroFee`).

### pitfalls
- Approve `amountLD` of the token to the `router` first — the approve leg must be in the plan.
- `dstChainId` is the LayerZero id, not the EVM chain id — mixing them routes to the wrong chain or reverts.
- `to` is bytes, not an `address`; a mis-encoded recipient can send funds to a dead address — encode the
  vault's verified destination address.

### safety
- `to` (the recipient) is the entire bridge security surface — it must be the vault's destination-chain
  address, never a third party. Refuse otherwise.
- `minAmountLD = 0` accepts any output under fee/rebalance conditions — floor it from a fresh quote.

## action: sendToken
**Function:** `sendToken((uint32 dstEid, bytes32 to, uint256 amountLD, uint256 minAmountLD, bytes extraOptions, bytes composeMsg, bytes oftCmd) sendParam, (uint256 nativeFee, uint256 lzTokenFee) fee, address refundAddress) payable returns (bytes32, (uint256 amountSentLD, uint256 amountReceivedLD))`
**Contract:** role `pool` (registry: `bridge/stargate/pool`)
**Use when:** bridging a token cross-chain on **Stargate v2** (the OFT-style interface).

### params
- `sendParam.dstEid` — the LayerZero **v2 endpoint id** of the destination, from the registry.
- `sendParam.to` — the destination recipient as a **bytes32-encoded address**; **MUST be the vault's
  destination-chain address** (left-pad the 20-byte address to 32 bytes).
- `sendParam.amountLD` — input in token decimals; scale from the token book, never a hardcoded 10^n.
- `sendParam.minAmountLD` — the slippage floor on the destination; **derive from a fresh quote, never 0.**
- `fee.nativeFee` — the LayerZero fee from `quoteSend`, paid as `msg.value`. `refundAddress` — the vault.

### pitfalls
- Approve `amountLD` of the token to the `pool` (the v2 OFT contract) first — the approve leg must be in the
  plan.
- `dstEid` is a LayerZero v2 endpoint id, distinct from both the EVM chain id and the v1 chain id.
- `to` is `bytes32`, not `address` — a wrongly padded value corrupts the recipient.

### safety
- `sendParam.to` is the recipient and the whole security surface — bytes32 of the vault's destination
  address, never a third party. Refuse otherwise.
- `minAmountLD = 0` is unbounded slippage — floor it from `quoteSend`/`quoteOFT`.
