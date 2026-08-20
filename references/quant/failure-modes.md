---
section: quant
title: Failure modes — what actually goes wrong
triggers: >-
  why did my strategy fail, what goes wrong, common mistakes, why am I losing money,
  getting picked off, adverse selection, my backtest was wrong, bot lost money,
  what not to do, pitfalls
---

# Failure modes — what actually goes wrong

Most systematic strategies fail, and they fail in a small number of repeated ways. This card is the
catalogue. Each entry states **what you do**, **what happens**, and where possible **the number that
decides it**.

Read this before building, not after losing money. Almost every entry here is detectable in advance.

## 1. Economics that make a strategy impossible before you write a line

These are arithmetic gates. If you fail one, no amount of signal quality rescues the strategy.

### Spread capture below the fee floor

**If you do this:** run a classic two-sided market maker on liquid perps at a standard fee tier,
expecting to earn the spread.

**What happens:** you lose money on every round trip, regardless of how good your quoting is.

**The number:** measured top-of-book spreads on the most liquid crypto perps run around
**0.13–0.16 basis points**. Realised gross capture per round trip is smaller still — of order
**0.07–0.12bp** once you account for which fills you actually get. A standard maker fee of
**1.5bp** (0.015%) is therefore roughly **ten times the entire spread**, and you pay it twice.

**What this means concretely:** pure spread market-making on liquid majors is viable **only** at a
zero-maker-fee tier or better, and realistically only with **rebates**. Below that it is not a
tuning problem, it is a sign problem. Check `maker_fee × 2` against the median spread *before*
building anything.

The corollary is that thin, neglected markets — where spreads are wide — are where a small
participant can actually make markets, and that the "obvious" liquid market is the one you cannot
compete in. See [strategies/market-making.md](strategies/market-making.md).

### Turnover above the fee budget

**If you do this:** trade a short-interval signal with leverage.

**What happens:** fees consume the edge before the signal is evaluated. A strategy acting on every
15-minute candle at 10× with 10% of equity per trade pays about **8.6% of bankroll per day** in
taker fees alone. Per-minute, roughly 130%/day. See
[../perpetuals/fees.md](../perpetuals/fees.md#fee-drag-the-arithmetic-that-kills-most-strategies).

### Zero-fee tiers that charge in latency

**If you do this:** pick a venue because its headline fee is 0%.

**What happens:** the cost reappears as adverse selection. A tier that delays your taker by ~300ms
while makers quote and cancel at ~200ms hands makers a free option on your order flow. It never
appears on a fee schedule and never appears in a fee-based backtest.

## 2. Research failures that fabricate edge

Every one of these produces a *positive* backtest. That is why they survive.

### Asynchronous sampling manufactures mean reversion

**If you do this:** compute a spread between two venues from feeds polled at different times.

**What happens:** part of the "spread" is sampling offset. It "reverts" when the laggard updates.
At ~20-second snapshot intervals this is **the single largest source of fake alpha in cross-venue
work.**

**What to do instead:** anchor signals on a common reference (an oracle or index price) rather than
two independently-sampled mids; require a deviation to persist for **N consecutive ticks** before it
counts; and make backtest fills execute at the **next** tick's prices, never the decision tick's.

### Stale quotes look like the best alpha you have ever seen

**If you do this:** screen a universe for large dislocations without a staleness filter.

**What happens:** a feed that stopped updating shows an enormous, perfectly persistent deviation
that you cannot trade. **A venue with chronic staleness produces the best-looking and least real
opportunities in the entire universe.**

**What to do instead:** monitor venue-timestamp versus local-timestamp divergence per venue as a
first-class metric, and apply identical staleness rules in live and backtest — ideally the same code
path.

### Bid-ask bounce is not reversion you can collect

**If you do this:** fit a mean-reversion model to a spread series without checking its magnitude
against the legs' spreads.

**What happens:** the oscillation you measured is the two legs bouncing between bid and ask. You
would pay it, not collect it.

**The test:** require `σ_spread ≥ k × Σ(half-spreads of the legs)` with **k ≥ 2**, where the
half-spreads are *measured from depth snapshots*, not assumed.

### Your most extreme signals are adversely selected

**If you do this:** treat the largest dislocations as the best opportunities.

**What happens:** a huge deviation on a thin venue usually means something is broken — an oracle
depeg, a halted engine, a delisting, or an exploit in progress. A backtest scores these as large
winners, because the price "reverted" or because the trade was never actually available. Live, they
are the losses.

**What to do instead:** make the extreme zone a **no-trade zone for entry as well as exit** — if
`|z| > stop_z`, something is wrong, so do not enter. Require the deviation to be confirmed on two
independent price fields. And hand-inspect the top ten trades of every backtest: **any result that
looks great is a data bug until proven otherwise.**

### The simulator rewarded a position the live system cannot hold

**If you do this:** validate a passive strategy in a simulator that grants queue position, while the
live implementation cancels and replaces on every small move.

**What happens:** the simulator credits you with passive fills at the front of the queue. The live
bot is permanently at the *back* of the queue, so the only fills it receives are the adverse ones.
The backtest and the live system are not testing the same strategy.

This one is worth stating sharply: **a profitable dry-run result is invalidated entirely if the live
order lifecycle cannot reproduce the queue behaviour the simulator assumed.** Check what your
simulator is rewarding before you trust its number.

### Bar data cannot see sub-bar edge

**If you do this:** backtest a market-making or very-short-horizon strategy on candles.

**What happens:** the result is roughly breakeven-to-negative even when the strategy is real,
because spread capture and sub-bar mean reversion happen below the resolution of the data. A
reconstruction can match a live strategy's *footprint* on every measurable dimension — signal
correlation, inventory behaviour, maker ratio — and still lose money on 1-hour and 1-minute bars.

**What to do instead:** if the edge lives below your bar size, you need L2 and trade ticks plus
latency modelling, or you cannot evaluate it at all. Know which regime you are in before choosing a
data source.

### A short window can invert your conclusion

**If you do this:** classify a strategy from a few weeks of observation.

**What happens:** you characterise it wrongly. One live book read as a delta-neutral
market-making strategy over an 18-day sample; reconstructed over its full history it was a
**net-long directional position with a trading overlay and a carry underlay** — a different strategy
with different risk. The market-making leg was a net *loser*; the returns came from directional beta
and carry.

**What to do instead:** decompose returns against simple benchmarks before accepting any narrative
about what a strategy is — including your own.

### In-sample thresholds

Tuning entry thresholds, reversion coefficients, or the universe on the same window you report
results from. **Only walk-forward numbers are real numbers.** See
[validation/backtesting.md](validation/backtesting.md).

## 3. Live execution failures — the ones that lose money in week one

### The frozen book: being the last stale quote standing

**If you do this:** subscribe to book snapshots but not to incremental price-change events.

**What happens:** venues typically send full snapshots only on subscribe and after trades;
placements and cancellations arrive as incremental updates. **Between trades your book is frozen.**
When the market moves and every other maker pulls their quotes, yours is the only one left — so you
are filled, every time, on exactly the wrong side. This is the single most reliable way to be picked
off, and it is a parsing bug rather than a strategy flaw.

Two subtleties that corrupt a book if handled naively: an incremental size field is usually the
**absolute total at that level, not a delta** (zero means remove the level), and it is often
**absent entirely**, in which case only the top-of-book fields are usable and depth must be left
untouched.

### Churning your own queue position

**If you do this:** cancel and replace quotes on every small mid change.

**What happens:** you go to the back of the queue every time, so you never earn a passive fill in
calm conditions — the only fills that reach you are the ones that sweep the book. You have built an
adverse-selection machine.

**What to do instead:** price hysteresis (do not reprice unless the move exceeds ~2 ticks) plus a
**minimum rest time** (~1.5–2s) before a quote may be replaced — with an override that repriced
immediately when the resting quote is about to be crossed. Watch for the classic dead-code version
of this bug: a hysteresis constant set *below the tick size*, so the check never fires at all.

### Quoting off the wrong reference price

**If you do this:** compute fair value from a convenient external feed rather than the price the
market actually settles against.

**What happens:** near a boundary, a few dollars of reference error flips your fair value hard, and
you quote confidently on the wrong side of a contract that settles the other way.

**What to do instead:** identify the official resolution source, use it, keep the convenient feed as
a fallback, and **alert on divergence between them**.

### Tick size changes at the extremes

**If you do this:** hard-code a tick size from config.

**What happens:** venues can shrink the tick when price moves into the extremes (e.g. above 0.96 or
below 0.04 on outcome markets). If you clamp quotes to a coarse grid you **cannot exit a
near-certain winning position** — you are unable to quote above the old boundary — and your orders
may be rejected for grid mismatch. This leaks real money precisely at the endgame, on positions you
already won.

**What to do instead:** subscribe to tick-size-change events and carry a live per-market tick size.

### Fill accounting at the wrong lifecycle stage

Recording a fill at final confirmation rather than at match means your inventory is wrong for the
window in between — and that window is exactly when you are deciding whether to requote. Apply fills
at the earliest reliable stage.

### Crash between legs

**If you do this:** send leg one, then leg two, with no persisted intent.

**What happens:** the process dies in between and you wake up naked on one leg with no record.

**What to do instead:** persist the order intent **before** sending; use idempotent client order ids;
and make the startup sequence reconcile venue open orders, fills and positions against your own book
*before* anything else runs. Test by killing the process at every stage.

### Funding sign and accrual bugs — the quiet PnL leak

Venues differ on accrual timing, proration and sign convention. A sign error in a carry strategy
silently pays the carry instead of collecting it, at double exposure.

**What to do instead:** verify per venue with a real small position held across an accrual, and
require your internal accounting to match the venue's reported payment **to the cent, in both
directions**, before trusting any carry math.

### Rounding breaks hedges asymmetrically

Beta-adjusted or partial-fill hedge sizes can round to zero or below minimum notional on one venue,
so the hedge is rejected and you are naked. Check min-notional and size-rounding feasibility for
**all** legs, at partial-fill granularity, in the signal layer — before any order is sent.

### Rate limits bite exactly when you need them

When the market moves, every signal fires at once and cancel-replace loops burst — so you get
throttled at the precise moment execution matters. Budget rate limits **globally rather than
per-task**, give execution priority over polling, and keep steady-state usage under roughly half the
budget so the emergency path always has headroom.

### The exit venue is the one that goes down

"Flatten" is not available when the venue you must flatten on is unavailable. Have a written
fallback — hedge the exposure on the deepest venue quoting the same underlying and carry the
cross-venue pair until the outage clears — rather than improvising during the outage.

### Close semantics differ per venue

A "close" that flips sign or is rejected because reduce-only and position-mode semantics differ.
Cover close-larger-than-position and one-way versus hedged mode in adapter tests.

### Paper trading flatters

Dry runs that fill at mid overstate PnL by roughly **half-spread × turnover**. Expect live week-one
PnL to come in below paper, and budget a small amount of real money for bug discovery. That spend is
tuition, planned for — not a failure.

## 4. Controls that exist only on paper

A control that does not execute is worse than no control, because you stop watching.

- **Config knobs that are declared but never read.** A threshold in your config file that no code
  path consumes looks like a safety limit and is not one.
- **Risk actions that log instead of act.** A profit-taking or rebalance routine that emits a
  warning and places no order is a comment with extra steps.
- **Constants below the resolution they operate on** — hysteresis smaller than a tick, a buffer
  smaller than a lot size. The branch never fires.

**What to do instead:** every limit needs a test that asserts the *failure* case — that the order is
actually blocked, that the position is actually flattened. Assert the control fires, not that the
code compiles.

## 5. Attribution failures

### The strategy is not what it is called

A book presented as market making earned its money from directional beta and carry while the
market-making leg lost money. If you had copied the description, you would have copied the losing
part.

**What to do instead:** decompose PnL by sleeve and by instrument before believing any label —
someone else's or your own. Compute the beta to a simple benchmark and report alpha net of it.

### Smoothed marks manufacture a Sharpe

Products that mark at period boundaries can report an annualised Sharpe near **19** while
fill-level reconstruction shows intra-period drawdowns far larger than that volatility could
produce. The smoothness is a marking artifact, not risk-adjusted skill.

**What to do instead:** treat any reported Sharpe above roughly 3 as a question, not a result, and
ask at what frequency the series was marked. See
[validation/evaluating-performance.md](validation/evaluating-performance.md).

### Capacity is not a footnote

One reconstruction of a live book found realised alpha dollars scaling as roughly **AUM^0.52**
(R² ≈ 0.45) — the square-root capacity law showing up in practice. Doubling capital produced about
**1.44×** the alpha dollars, so return on capital decayed as **AUM^−0.48**.

**What this means:** an edge can be entirely real and still not scale. A strategy returning several
percent per period at small size can be under one percent at 50× the size, with the difference going
to market impact. **Size the book to the capacity curve, and measure the curve rather than assuming
it.** See [indicators/microstructure.md](indicators/microstructure.md#price-impact-and-kyles-lambda).

## 6. Process failures

- **Building ahead of evidence.** Ten venue adapters before one profitable trade. Order the work so
  that each phase can kill the project cheaply: record data → prove one edge live at minimum size →
  research → add breadth.
- **Tests weakened until they pass.** Review acceptance tests against the specification's criteria,
  not against the implementation. Look-ahead tests and cost-gate tests are the most tempting to
  neuter and the most expensive to lose.
- **Interface drift.** Core types changed mid-build to unblock one component, invalidating every
  downstream assumption.
- **Key management.** Any process running unattended should hold a scoped, trade-only credential
  with limited funds — never a primary key. Keep secrets in the environment, never in config files
  in version control, and audit history before the first push.

## The pattern behind all of these

Nearly every entry has the same shape: **something that looks like a signal is an artifact of how
you measured, and something that looks like a control does not fire.**

The discipline that catches both is the same. Ask what would have to be true for this number to be
fake, and then go check that specific thing — before the money is at risk, not after.
