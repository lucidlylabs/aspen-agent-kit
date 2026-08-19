---
protocol: bungee
category: bridge
chains: [1, 10, 137, 8453, 42161]
archetype: bridge_transfer
executor: knowledge-only
aliases:
  - "bridge USDC from base to arbitrum"
  - "move ETH to optimism"
  - "send USDC cross-chain to ethereum"
  - "bridge my tokens to another chain"
  - "get the best bridge route with bungee"
  - "transfer WETH from arbitrum to base"
roles: [gateway]
actions: [quote, approve, bridge, status]
tokens: [USDC, USDT, WETH, ETH, DAI]
---

# Bungee (Socket)

Bungee is a **bridge + swap aggregator** — it routes a token move across chains (and same-chain swaps)
over hundreds of underlying bridges and DEXs, picking the best route. The underlying protocol is **Socket**;
on-chain, a single **SocketGateway** contract (role `gateway`) receives every bridge/swap transaction and
dispatches it to the chosen underlying route. It spans 30+ EVM chains.

Bungee is **API-driven**: an app calls the Socket/Bungee HTTP API to (1) `quote` a route, (2) build an
approval tx if needed, (3) build the bridge tx, then (4) poll status until the destination settles. The
transaction the wallet signs is **opaque calldata (`txData`) built by the API**, sent to the SocketGateway
(`txTarget`). The app never encodes the route itself.

> **executor: knowledge-only (as a composable graph node).** There is no generic `bridge_transfer` graph
> primitive yet — you cannot compose an arbitrary "bridge X to chain Y" step into a strategy graph. BUT the
> **cross-chain FUNDING phase is wired**: the strategy engine's async `bridging` lifecycle (`services/
> strategy-engine/src/bridge.ts`) uses Socket/Bungee to move a burner's funds from the vault's home chain
> (Base) to the execution chain (Polygon) so a Polymarket strategy deploys with one signature. It is exactly
> the two-phase machine this card specifies (`send → sent → arrived → wrapped`), with the mandatory source
> simulation + recipient pinning below.
>
> **API is Socket Swap V3**, not the legacy v2 flow described action-by-action below (kept for the model's
> conceptual map). The live shape is a SINGLE `GET /v3/swap/quote?userOps=tx&originChainId&destinationChainId&
> inputToken&inputAmount&outputToken&receiverAddress&userAddress&slippage` that returns the route's opaque
> `txData.object` + `approval.spenderAddress` + `output.minAmountOut` inline (no separate build-tx), polled by
> `GET /v3/swap/status?quoteId`. The tx `to` + approve `spender` resolve to the vetted **Socket** contracts
> (roles `socket/openRouter` + `socket/allowanceHolder` — one deterministic address each on every chain,
> supplied by the registry), which the SDK adapter (`bridge/socket.ts`) PINS and refuses otherwise. The destination
> `recipient` is pinned to the burner (the whole security boundary); arrival is verified by the status poll +
> the on-chain balance, never the source receipt.

## action: quote
**Function:** `GET /quote` (Socket/Bungee API — off-chain, read-only)
**Contract:** none (off-chain route discovery)
**Use when:** finding the best cross-chain route + expected output before building a tx.

### params
- `fromChainId` / `toChainId` — source and destination chain ids.
- `fromTokenAddress` / `toTokenAddress` — the token on each chain (resolve from the token book, never guess).
- `fromAmount` — in the source token's decimals; scale from the token book, never a hardcoded 10^n.
- `userAddress` — the sender (the strategy wallet).
- `recipient` — the destination address; **MUST be a vault-controlled address on the destination chain**.
- `defaultBridgeSlippage` — bridge slippage bound (0–100%); the SAME value must be passed to `build-tx`.
- route controls — `uniqueRoutesPerBridge`, `sort` (output | gas | time), `singleTxOnly`.

### pitfalls
- The quote is time-sensitive (routes + gas move); re-quote at build time, do not reuse a stale route.
- `recipient` defaults to `userAddress` if omitted — but for a vault the destination address is DIFFERENT
  from the source wallet; set it explicitly to the vault's destination-chain address.

### safety
- Read-only; it is not a signed-tx target. The route it returns still has to be simulated at execution.

## action: approve
**Function:** `approve(address spender, uint256 amount)` on the source ERC20 (calldata from `GET /approval/build-tx`)
**Contract:** the source token; `spender` = the SocketGateway (role `gateway`)
**Use when:** bridging an ERC20 whose allowance to the SocketGateway is below `fromAmount` (native ETH needs no approval).

### params
- `spender` — the SocketGateway address for the source chain (from the registry, never the API blindly).
- `amount` — exactly `fromAmount`; do not grant an unbounded allowance from a strategy wallet.

### pitfalls
- The approve leg must be in the plan/allowlist or the bridge tx is default-DENYed at signing.
- Check the current allowance first and skip the approve when it already covers `fromAmount`.

## action: bridge
**Function:** opaque `SocketGateway` call — `txData` built by `POST /build-tx` from the chosen route
**Contract:** role `gateway` (registry: `bridge/bungee/gateway`) — the `txTarget` the wallet sends to
**Use when:** executing the cross-chain move for a quoted route.

### params
- `route` — the route object returned by `quote` (echoed into `build-tx`).
- `defaultBridgeSlippage` — the same slippage passed to `quote`.
- `txData` / `txTarget` / `value` — returned by the API; `value` is non-zero for a native-token bridge.

### pitfalls
- **`txData` is OPAQUE** — an encoded route through arbitrary underlying bridges. A signer cannot read
  intent from it, so it MUST be fork-simulated (destination recipient, min received, no unexpected token
  outflow) before broadcast. This is the whole security surface.
- Settlement is **asynchronous** — the source tx confirming does NOT mean funds arrived. Track `status`.
- Underpaying `value` (native bridge) or wrong slippage leaves the move stuck or reverting.

### safety
- **The destination `recipient` is the whole security boundary** — it must be a vault-controlled address on
  the destination chain, never a third party. Refuse otherwise (and confirm it in the simulation).
- Only the SocketGateway (per the vetted registry) is an allowed `txTarget`; reject any other target the
  API returns.

## action: status
**Function:** `GET /bridge-status` (Socket/Bungee API — off-chain)
**Contract:** none (off-chain settlement check)
**Use when:** confirming a bridge completed on the destination before continuing a strategy.

### params
- `transactionHash` — the source-chain bridge tx hash.
- `fromChainId` / `toChainId` — the route's chains.

### pitfalls
- Returns `PENDING` until the destination settles; poll with backoff, do not assume completion from the
  source receipt. The destination-arrival check is what advances a two-phase bridge executor.

### safety
- Read-only. Treat "arrived" as confirmed only when the API reports completion AND the destination balance
  reflects it (verify on-chain, don't trust the API alone).
