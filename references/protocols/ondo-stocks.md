---
protocol: ondo-stocks
category: other
chains: [1]
archetype: rwa_mint_redeem
executor: knowledge-only
aliases:
  - "buy tokenized AAPL stock"
  - "mint Ondo Global Markets stock token"
  - "swap USDC for USDon"
  - "buy tokenized TSLA"
  - "redeem my tokenized stock back to USDon"
  - "hold a tokenized equity on-chain"
roles: [manager, usdonManager, oracle]
actions: [swapToUsdon, mintWithAttestation, redeemWithAttestation, redeemUsdon]
tokens: [USDC, USDon]
---

# Ondo Stocks (Ondo Global Markets)

**Ondo Stocks** (branded "Ondo Global Markets", "GM" in contract names) issues **100+ tokenized US stocks
and ETFs** (e.g. AAPLon, TSLAon, NVDAon, SPY) as on-chain ERC20s tracking the underlying security's price
1:1, for **non-US investors**. It is live on Ethereum, BNB Chain, and Solana (Ethereum only is registered
here — this app's home chains don't include BNB/Solana). Two contracts matter: **`GMTokenManager`** (role
`manager`) mints/redeems the stock tokens themselves, and **`USDonManager`** (role `usdonManager`) mints/
redeems **USDon** — Ondo's own USD-denominated settlement stablecoin that is the ONLY currency
`GMTokenManager` accepts. So buying a tokenized stock is a **two-step** flow: USDC → USDon (via
`usdonManager`), then USDon → stock token (via `manager`). A **`SyntheticSharesOracle`** (role `oracle`,
read-only) prices each stock token; individual stock-token addresses are NOT hand-maintained here (100+ and
growing) — resolve them from Ondo's own asset API (`GET api.gm.ondo.finance/v1/assets/all/addresses`) or
`app.ondo.finance`, never guess an address.

> **executor: knowledge-only for `mintWithAttestation`/`redeemWithAttestation`.** Two things set the PRIMARY
> issuance path apart from every runnable primitive in this repo: (1) **every mint/redeem requires an
> Ondo-signed attestation** fetched from Ondo's off-chain API (`POST /attestations/mint-or-redeem`) BEFORE
> the on-chain call — a strategy wallet cannot mint by encoding calldata alone; and (2) **KYC/eligibility is
> enforced off-chain by Ondo**, same as USDY/OUSG — an un-onboarded wallet's attestation request itself is
> refused, upstream of any transaction. This file is the knowledge that a future attestation-integrated
> executor builds against.
>
> **Practical test path: the DEX-AGGREGATOR SWAP — and this is REAL, not a workaround.** Ondo tokenized
> stocks are total-return trackers designed for exactly this: MetaMask Swaps already lets users acquire GM
> tokens with USDC on Ethereum mainnet through DEX aggregation, so `swap_via_aggregator`/
> `close_via_aggregator` is the intended, live secondary-market path, sidestepping the attestation gate
> entirely (which only applies to Ondo's OWN primary mint/redeem, not to trading an already-issued token on
> a public pool).
>
> **Why this isn't wired for "any ticker" yet: Ondo's own resolver API is access-gated too.** The 100+-ticker
> catalog is out of scope for hand-maintenance, and the intended fix — resolving a ticker to its address
> live via Ondo's own `GET api.gm.ondo.finance/v1/assets/all/addresses` — turns out to require an API key
> from a business relationship with Ondo (`onboarding@ondo.finance`; confirmed 2026-07-15, the public OpenAPI
> spec marks this endpoint auth-required), which this repo doesn't have. Until that's arranged, a **curated
> flagship set** (same pattern as LlamaLend's curated markets) is the practical substitute: **METAon, AAPLon,
> TSLAon, NVDAon, SPYon** — each verified two ways (a web search cross-checking CoinGecko/CoinMarketCap's
> listed contract, AND an independent Etherscan read of `name()`/`symbol()`/`decimals()`, source verified),
> registered in the token book 2026-07-15. `swap_via_aggregator` (USDC → ticker) / `close_via_aggregator`
> (the exit) works for any of these five today. See `compose/examples.ts` `SWAP_THEN_ONDO_STOCK` (a factory,
> not one hardcoded example — pass any curated ticker). **A ticker NOT in this list still correctly
> `needs_research`s** (fails closed — never guesses an address) until it's added the same two-source way.

## action: swapToUsdon
**Function:** `subscribe(address token, uint256 amount, uint256 minReceived)`
**Contract:** role `usdonManager` (registry: `other/ondo-stocks/usdonManager` — `USDonManager`)
**Use when:** converting an accepted stablecoin (USDC) into USDon, the prerequisite for minting any stock token.

### params
- `token` — the accepted subscription token address (USDC); resolve from the token book.
- `amount` — the deposit amount in the token's own decimals (6 for USDC).
- `minReceived` — the minimum USDon out (18 decimals); a slippage/price floor — never pass 0.

### pitfalls
- Approve the stablecoin to `usdonManager` first (approve leg must be in the plan).
- USDon is meant to track $1 but is still a distinct asset with its own subscription/redemption fees
  (`setOndoSubscriptionFees`) — do not assume a flat 1:1 with no slippage.

### safety
- USDon is minted to the caller — the caller MUST be the vault (or the isolated strategy wallet).

## action: mintWithAttestation
**Function:** `mintWithAttestation(tuple attestation, bytes signature, address stockToken, uint256 usdonAmount)`
(tuple layout not decoded here — verify against the current `GMTokenManager` ABI before building an executor)
**Contract:** role `manager` (registry: `other/ondo-stocks/manager` — `GMTokenManager`)
**Use when:** minting a specific tokenized stock (e.g. AAPLon) by spending USDon, AFTER fetching a mint
attestation for this exact trade from Ondo's attestation API.

### params
- `attestation` / `signature` — the signed attestation object Ondo's API returns for THIS mint (asset,
  amount, price, expiry); it cannot be constructed locally.
- `stockToken` — the target stock token's address, resolved from Ondo's live asset API/app, never guessed
  or hardcoded (the catalog of 100+ tickers is out of scope for the static registry).
- `usdonAmount` — the USDon amount to spend (18 decimals).

### pitfalls
- **The attestation has an expiry** — stale attestations revert; fetch immediately before sending.
- Approve USDon to `manager` first.
- `GMTokenManager` also exposes `adminProcessMint` (bank-wire/admin path) and per-asset
  `pauseGMTokenMints(address)` — a paused asset reverts; check pause state before attesting.

### safety
- This is the load-bearing security gap vs. every other card in this corpus: correctness depends on
  TRUSTING Ondo's off-chain attestation service to only sign what the user actually requested. An executor
  must treat the attestation fetch itself as consent-gated (show the user exactly what will be minted before
  requesting the signature), not just the final transaction.

## action: redeemWithAttestation
**Function:** `redeemWithAttestation(tuple attestation, bytes signature, address stockToken, uint256 shareAmount)`
(tuple layout not decoded here — verify against the current `GMTokenManager` ABI before building an executor)
**Contract:** role `manager` (registry: `other/ondo-stocks/manager`)
**Use when:** redeeming a tokenized stock back to USDon, after fetching a redeem attestation.

### params
- Mirrors `mintWithAttestation`: an Ondo-signed redeem attestation + the stock token + share amount to redeem.
  USDon proceeds return to the caller.

### pitfalls
- Same attestation-expiry and per-asset-pause caveats as the mint leg
  (`pauseGMTokenRedemptions(address)`/`pauseGlobalRedeems()`).

### safety
- Redeem from the vault/strategy wallet only; proceeds MUST land back there, never an external address.

## action: redeemUsdon
**Function:** `redeem(uint256 amount, address token, uint256 minReceived)`
**Contract:** role `usdonManager` (registry: `other/ondo-stocks/usdonManager`)
**Use when:** converting USDon back to a stablecoin (USDC) after exiting a stock position.

### params
- `amount` — the USDon amount to redeem (18 decimals).
- `token` — the stablecoin to receive (USDC).
- `minReceived` — the minimum stablecoin out; never pass 0.

### pitfalls
- Approve USDon to `usdonManager` first.

### safety
- Redeem from the vault only; proceeds MUST land back there, never an external address.
