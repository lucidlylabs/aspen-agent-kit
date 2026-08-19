---
protocol: convex
category: yield
chains: [1, 42161]
archetype: stake
executor: knowledge-only
aliases:
  - "stake my curve LP on convex"
  - "deposit curve LP into convex"
  - "boost my curve yield with convex"
  - "claim my convex rewards"
  - "unstake from convex"
  - "withdraw my curve LP from convex"
  - "farm CRV and CVX"
roles: [booster, rewards]
actions: [deposit, withdraw, getReward]
tokens: [crvUSD, CRV, CVX]
---

# Convex

Convex boosts Curve LP yield: you stake a **Curve LP token** and earn boosted CRV plus CVX and any extra
market incentives, without locking veCRV yourself. Deposits go through the single **Booster** (role
`booster`), keyed by a **pool id (`pid`)** that maps to one Curve pool. Staked LP accrues rewards in a
per-pool **BaseRewardPool** (role `rewards`), where rewards are claimed and unstaking-with-unwrap happens.

> **executor: knowledge-only.** No engine executor runs the `stake` archetype yet; the harness will
> `needs_research` a Convex request until one exists. This file is the knowledge the author + future
> executor build against.

## action: deposit
**Function:** `deposit(uint256 _pid, uint256 _amount, bool _stake)`
**Contract:** role `booster` (registry: `yield/convex/booster`)
**Use when:** staking a Curve LP token into Convex to earn boosted CRV + CVX.

### params
- `_pid` — the Convex **pool id** for the exact Curve pool. Resolve it per pool; a wrong `pid` stakes a
  different LP — pin it, refuse an ambiguous one.
- `_amount` — the **Curve LP token** amount (LP decimals, usually 18); scale from the token book / LP
  metadata, never a hardcoded 10^n.
- `_stake` — **`true`** to stake into the reward pool in one call (else you only mint the Convex deposit
  token and must stake separately). Use `true` unless you have a reason not to.

### pitfalls
- Approve the Curve LP token to the `booster` first (approve leg must be in the plan).
- The `pid` and the LP token must correspond — depositing the wrong LP for a `pid` reverts.
- `_stake = false` leaves you unstaked and earning nothing until a separate stake — prefer `true`.

### safety
- The staked position and its rewards accrue to `msg.sender` (the vault). Ensure the vault is the caller;
  the Booster has no `receiver` argument, so the caller is the owner of the stake.

## action: withdraw
**Function:** `withdrawAndUnwrap(uint256 amount, bool claim)`
**Contract:** role `rewards` (registry: `yield/convex/rewards`)
**Use when:** unstaking Curve LP back out of Convex (and optionally claiming rewards in the same call).

### params
- `amount` — the staked amount to unwind (LP decimals). Use the full `balanceOf` on the reward pool for a
  full exit.
- `claim` — **`true`** to sweep pending CRV/CVX/extras in the same tx (saves a call).
- Unstake on the **`rewards`** pool (`withdrawAndUnwrap`), not the Booster — this both unstakes and
  unwraps the Convex deposit token back to the Curve LP for the caller (the vault).

### pitfalls
- The Booster's raw `withdraw(_pid, _amount)` expects the unstaked deposit token; from a staked position
  use the reward pool's `withdrawAndUnwrap` — mixing them reverts.
- `claim = false` leaves rewards unclaimed (still claimable later) — set `true` to collect on exit.

### safety
- The unwrapped LP and any claimed rewards go to `msg.sender` (the vault). Any other caller receives them
  — refuse.

## action: getReward
**Function:** `getReward(address _account, bool _claimExtras)`
**Contract:** role `rewards` (registry: `yield/convex/rewards`)
**Use when:** harvesting accrued CRV + CVX (and extra incentive tokens) without unstaking.

### params
- `_account` — **the vault** (whose rewards accrue and receive the claim).
- `_claimExtras` — **`true`** to also collect the pool's extra incentive tokens, not just CRV/CVX.

### pitfalls
- `_account` ≠ the vault claims on behalf of another account and sends the rewards there — refuse.

### safety
- Claiming never touches the staked principal — but still pin `_account` to the vault.
