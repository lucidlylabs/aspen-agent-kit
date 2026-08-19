---
protocol: syrup
category: yield
chains: [1]
archetype: deposit_vault
executor: knowledge-only
aliases:
  - "earn yield on syrupUSDC"
  - "deposit into Maple Syrup"
  - "lend on Maple"
  - "buy syrupUSDC"
  - "swap into syrupUSDC"
  - "get syrupUSDT yield"
roles: [permissionManager]
actions: [deposit, requestRedeem]
tokens: [USDC, USDT, syrupUSDC, syrupUSDT]
---

# Maple Syrup (syrupUSDC / syrupUSDT)

Syrup is Maple Finance's retail-facing lending product: **syrupUSDC** and **syrupUSDT** are ERC4626-shaped
pool tokens that earn Maple's institutional-lending yield. Despite Maple's "permissionless DeFi" marketing,
**first-time LENDER deposits are still gated on-chain**: the pool's `deposit()`/`authorizeAndDeposit()` path
checks `PoolPermissionManager.hasPermission(poolManager, owner, "P:deposit")` — a bitmap that requires a
Maple-issued ECDSA authorization signature (obtained by contacting `partnerships@maple.finance`) before an
address's FIRST deposit; every subsequent deposit from that same authorized address is a plain `deposit()`.
Withdrawal from the pool is a **request-then-claim queue** (`requestRedeem`, settled after Maple's redemption
window), not an instant ERC4626 `redeem`.

> **executor: knowledge-only for MINTING.** No engine executor runs Maple's own `deposit`/`requestRedeem`
> archetype — `PoolPermissionManager` authorization is a one-off, human, per-address process (an email +
> a signature) fundamentally incompatible with this repo's **disposable, single-use burner wallet** model: a
> fresh burner is a brand-new never-before-seen address, so it would need a fresh manual authorization from
> Maple before every single strategy — impractical to automate, and Syrup will `needs_research` if composed
> as a mint/redeem primitive.
>
> **Practical test path: the DEX-AGGREGATOR SWAP, not the mint.** syrupUSDC/syrupUSDT are, once issued,
> ordinary ERC20 tokens (registered in the token book, `strategy/tokenBook.ts`) — the `PoolPermissionManager`
> gate is scoped to calling INTO the Pool contract (`deposit`/`requestRedeem`), not to holding or trading the
> already-minted share token on a public DEX. So the **live, already-wired path** to get syrupUSDC/syrupUSDT
> exposure through this harness is `swap_via_aggregator` (USDC/USDT → syrupUSDC/syrupUSDT) and
> `close_via_aggregator` for the exit — the SAME quote-off (0x/KyberSwap/fly.trade/Bebop) every other swap
> uses, no new block, no capability gate (both are already in the default catalog). This sidesteps the
> permission gate by construction: if a public pool has liquidity, the swap fills; if it doesn't, the
> quote-off reports no route and the composer fails closed — never a guessed or forced execution either way.
> See `compose/examples.ts` `SWAP_THEN_SYRUP_USDC`.

## action: deposit
**Function:** `deposit(uint256 assets, address receiver)` (first-time lenders instead call
`authorizeAndDeposit(uint256 assets, address receiver, uint256 bitmap, uint256 deadline, uint8 v, bytes32 r,
bytes32 s)` with Maple's issued signature)
**Contract:** role `permissionManager` gates the call; the actual deposit target is the pool's `PoolManager`
(not separately registered here — see the note above on why this isn't wired as an executable block)
**Use when:** lending USDC/USDT into a Syrup pool to earn Maple's lending yield — **requires prior
authorization from Maple** (see above).

### params
- `assets` — the USDC/USDT amount to deposit (6 decimals); scale from the token book, never a hardcoded 10^n.
- `receiver` — **MUST be the depositor's own address** (the syrupUSDC/syrupUSDT shares mint to the caller).

### pitfalls
- **A never-authorized address's `deposit()` reverts** — `hasPermission` fails closed. There is no way to
  self-serve authorization on-chain; it is a human process (email Maple, receive a signature).
- Approve USDC/USDT to the pool first (approve leg must be in the plan) — but this is moot until
  authorization exists.

### safety
- `receiver` ≠ self mints the shares elsewhere — refuse.

## action: requestRedeem
**Function:** `requestRedeem(uint256 shares, address owner)`
**Contract:** the pool's `PoolManager` (not registered — see above)
**Use when:** starting a withdrawal — Syrup redemptions are a **request-then-settle queue**, not instant.

### params
- `shares` — the syrupUSDC/syrupUSDT amount to redeem.
- `owner` — **MUST be the vault's own address** (self-request needs no separate approval).

### pitfalls
- This does **not** return USDC/USDT immediately — it queues the request; funds arrive after Maple's
  redemption window processes it (window length varies by pool/liquidity conditions).

### safety
- Only the request owner can later claim the settled proceeds; pin `owner` to the caller.
