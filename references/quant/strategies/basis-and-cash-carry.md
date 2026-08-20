---
section: quant
group: strategies
title: Basis and cash-and-carry
type: convergence
triggers: >-
  cash and carry, basis trade, spot perp basis, futures premium, convergence
  trade, contango, backwardation
---

# Basis and cash-and-carry

## Mechanism

A derivative trading away from its underlying must converge — by expiry for a dated contract, or by
funding pressure for a perp. **Buy the cheap one, sell the dear one, wait.** No forecast of direction
is required, only that convergence happens and that you survive until it does.

This is the oldest trade in derivatives and the mechanism is not in dispute. What varies is whether
the spread is wide enough to pay for the costs and the capital.

## The two variants

**Dated futures (hard convergence).** The contract settles at the index on a known date. Convergence
is contractual. Annualise the basis over the days to expiry and compare against your cost of capital.
Available on these venues only where dated instruments exist — HIP-4 outcome markets are dated, and
Lighter's pre-launch and pre-IPO markets have their own settlement rules.

**Perpetuals (soft convergence).** No expiry, so convergence is enforced only by funding. The basis
can persist far longer than intuition suggests, and it persists *longest* exactly where funding is
weakest — Lighter's clamps and its per-market-class multipliers (1/100 for pre-IPO) mean a basis
there faces almost no corrective pressure. **A perp basis trade is really a funding carry trade
wearing different clothes**; see [funding-carry.md](funding-carry.md), and be honest about which one
you are doing.

## Entry

```
annualised basis = (perp − index) / index × (365 / days_to_convergence)
```

Enter when annualised basis, **net of both legs' fees, expected funding over the hold, borrow cost,
and slippage**, exceeds your hurdle by a comfortable margin.

Checks before sizing:

- **Is the index the one that settles the contract?** Not a proxy, not a different venue's spot. For a
  dated contract this is the whole trade.
- **Can you hold the spot leg?** Custody, and the opportunity cost of the capital sitting in it.
- **Is the convergence date certain?** Builder-deployed markets can be settled or delisted by the
  deployer.
- **What is the margin requirement across the whole path**, not just at entry?

## Exit

- **At convergence**, by design: hold to settlement where the instrument settles.
- **Early, if the basis compresses** enough that the remaining spread no longer pays for the remaining
  capital lockup — this is often the better decision and is systematically under-taken.
- **On a widening stop.** A basis that widens materially against you may mean your convergence
  assumption is wrong (a broken peg, a delisting risk, an oracle divergence). Have a level at which
  you conclude the thesis is broken rather than adding.

## Sizing and the trap

Basis trades look risk-free and are not. The specific trap: **the spread can widen before it
converges**, and if you are levered, the mark-to-market on the widening can liquidate you before the
convergence you correctly predicted arrives.

This is the failure mode that has destroyed large, sophisticated participants repeatedly. Size such
that you can survive a basis move well beyond anything in your sample, and treat the maximum
historical divergence as a floor for your stress case, not as a ceiling.

## Failure modes

1. **Liquidation before convergence.** The dominant risk. Low leverage is not optional here.
2. **The legs are not actually linked.** A perp on a builder market with a manipulable oracle does not
   have to converge to anything you can observe.
3. **Settlement risk on the short leg** — delisting, forced settlement, oracle failure.
4. **Funding costs eating the basis** on the perp form: you may be paying funding while waiting for a
   convergence that funding itself is supposed to drive. Compute the net.
5. **Capital opportunity cost.** A 6% annualised basis that ties up capital for three months is a 1.5%
   return, and worse if you could have deployed the capital elsewhere.
6. **Correlated unwind.** When basis trades unwind across the market at once, both legs move against
   you simultaneously.

## The HIP-4 special case

HIP-4 outcome markets settle at a known `settleFraction` on a known date, and the Yes/No books are
merged — so a full YES+NO set is worth exactly 1. If YES and NO can be bought together for less than
1 (net of fees), that is a **hard convergence trade with no directional risk at all**. The same
applies across venues: YES on the cheaper venue plus NO on the dearer, in equal contract counts, for
a combined cost under 1.00.

These are the cleanest convergence opportunities in this kit. They are also small, competitive, and
constrained by the depth of the thinner leg — but the mechanism is airtight, which is rare.
