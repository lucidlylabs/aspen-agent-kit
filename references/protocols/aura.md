---
protocol: aura
category: yield
chains: [1, 8453, 42161, 10]
archetype: stake
executor: knowledge-only
aliases:
  - "stake my balancer BPT on aura"
  - "deposit balancer LP into aura"
  - "boost my balancer yield with aura"
  - "claim my aura rewards"
  - "unstake from aura"
  - "withdraw my balancer LP from aura"
  - "farm BAL and AURA"
roles: [booster, rewards]
actions: [deposit, withdraw, getReward]
tokens: [BAL, AURA, wstETH]
---

# Aura

Aura is the Balancer analogue of Convex (a Convex fork): you stake a **Balancer Pool Token (BPT)** and
earn boosted BAL plus AURA and any extra incentives, without locking veBAL yourself. Deposits go through
the single **Booster** (role `booster`), keyed by a **pool id (`pid`)** mapping to one Balancer gauge. The
staked position accrues rewards in a per-pool **BaseRewardPool4626** (role `rewards`), where rewards are
claimed and unstaking-with-unwrap happens. The reward pool is ERC4626-shaped but the canonical stake/exit
path is the Booster `deposit` + reward-pool `withdrawAndUnwrap`.

> **executor: knowledge-only.** No engine executor runs the `stake` archetype yet; the harness will
> `needs_research` an Aura request until one exists. This file is the knowledge the author + future
> executor build against.

## action: deposit
**Function:** `deposit(uint256 _pid, uint256 _amount, bool _stake)`
**Contract:** role `booster` (registry: `yield/aura/booster`)
**Use when:** staking a Balancer BPT into Aura to earn boosted BAL + AURA.

### params
- `_pid` — the Aura **pool id** for the exact Balancer gauge/pool. Resolve it per pool; a wrong `pid`
  stakes a different BPT — pin it, refuse an ambiguous one.
- `_amount` — the **Balancer BPT** amount (BPT decimals, usually 18); scale from the token book / pool
  metadata, never a hardcoded 10^n.
- `_stake` — **`true`** to stake into the reward pool in one call (else you only mint the Aura deposit
  token and earn nothing until a separate stake). Use `true`.

### pitfalls
- Approve the BPT to the `booster` first (approve leg must be in the plan).
- The `pid` and the BPT must correspond — depositing the wrong BPT for a `pid` reverts.
- `_stake = false` leaves the position unstaked — prefer `true`.

### safety
- The stake and its rewards accrue to `msg.sender` (the vault). The Booster has no `receiver` argument, so
  the caller is the owner — ensure the vault is the caller.

## action: withdraw
**Function:** `withdrawAndUnwrap(uint256 amount, bool claim)`
**Contract:** role `rewards` (registry: `yield/aura/rewards`)
**Use when:** unstaking the Balancer BPT back out of Aura (and optionally claiming in the same call).

### params
- `amount` — the staked amount to unwind (BPT decimals). Use the full `balanceOf` on the reward pool for a
  full exit.
- `claim` — **`true`** to sweep pending BAL/AURA/extras in the same tx.
- Unstake on the **`rewards`** pool (`withdrawAndUnwrap`), not the Booster — it unstakes and unwraps the
  Aura deposit token back to the BPT for the caller (the vault).

### pitfalls
- The Booster's raw `withdraw(_pid, _amount)` expects the unstaked deposit token; from a staked position
  use the reward pool's `withdrawAndUnwrap` — mixing them reverts.
- `claim = false` leaves rewards unclaimed (still claimable later) — set `true` to collect on exit.

### safety
- The unwrapped BPT and any claimed rewards go to `msg.sender` (the vault). Any other caller receives them
  — refuse.

## action: getReward
**Function:** `getReward(address _account, bool _claimExtras)`
**Contract:** role `rewards` (registry: `yield/aura/rewards`)
**Use when:** harvesting accrued BAL + AURA (and extra incentive tokens) without unstaking.

### params
- `_account` — **the vault** (whose rewards accrue and receive the claim).
- `_claimExtras` — **`true`** to also collect the pool's extra incentive tokens, not just BAL/AURA.

### pitfalls
- `_account` ≠ the vault claims on behalf of another account and sends the rewards there — refuse.

### safety
- Claiming never touches the staked principal — but still pin `_account` to the vault.
