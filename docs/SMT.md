# Strategy 4 — Smart Money Trap

SMT is integrated into the existing Scalping Bot EA. No additional EA, ML model, database, service or live-terminal deployment is required. Default source settings leave SMT disabled, so the four existing symbol profiles retain their original behavior. Their bytes and the nine Strategy 1–3 rule/time modules are checked against `artifacts/smt-v1/preserved-before.json`.

## Repository audit

Strategy 1's 4H false-breakout state machine, Strategy 2's triangle detector/retest state machine and Strategy 3's ORB continuation/reversal state machines already exist. They have native compilation and earlier engineering-test receipts. The ORB release's short market sample had zero ORB trades; those receipts do not establish ORB profitability. SMT reuses confirmed-pivot/FVG helpers, time conversion, chart primitives, shared account locks, history counters, consumption keys, execution and ownership monitoring. Their original signal modules are not rewritten.

The necessary shared change is an SMT-only dynamic-target path: the older strategies retain their existing fixed-R targets and minimum 2R. SMT is not subject to that minimum or the older TP-extension repair routine.

## Two profiles, one engine

| Setting | MTF | M1 scalping |
|---|---|---|
| File under `profiles/` | `smt-mtf-d1-h1-m15-m5-demo.set` | `smt-scalp-m15-m1-demo.set` |
| Profile mode | 0 / MTF | 1 / SCALP |
| Trend | D1 | M15 |
| Additional context | H4 | M15 |
| Primary / secondary locations | H4 / H1 | M1 / M1 (one scan) |
| Trap | M15 | M1 |
| Entry confirmation | M5 | M1 |
| SMT magic | 26103400 | 26103401 |
| Trend alignment | Strict | Strict |
| Locations / patterns | All six / all three | All six / all three |
| Stops / target | Sweep SL / nearest opposing zone TP | Same |
| Optional RR gate | Enabled, 1.0 minimum | Enabled, 1.0 minimum |
| Safety | Both signal-only switches true; real-account permission false | Same |

Both new profiles disable Strategies 1–3. They reserve distinct unused 4H/Triangle/ORB magic numbers as well as distinct SMT magics, so the existing owner-lock scheme permits both profiles on separate charts of the same symbol. The original four profiles remain unchanged and omit SMT settings; source defaults keep SMT disabled. Default source SMT magic 26103499 is separate from the supplied profile magics.

`InpSMTSignalOnly` adds an SMT-specific signal-only gate to the global one. Both must permit execution to submit an order. All instances on one account must still agree on shared risk and broker-time settings. Do not change a profile's identity, timeframes or magic to reinterpret an existing pending setup or open position; a new research configuration should use its own identity and test evidence.

## Causal data handling

Every decision is evaluated from completed candles with explicit availability times. Arrays are chronological. ATR is a simple mean of true ranges over the configured number of completed bars, not an indicator handle or Wilder smoothing. Trend and location snapshots are bounded by their requested historical decision timestamp.

A strict pivot must exceed all left/right neighbors; equal extremes do not count as pivots. Its candle time and known-at close time are separate. Newly confirmed pivots are registered after that candle's break detection, preventing a pivot being confirmed and broken at the same close. Trend needs the configured minimum number of highs and lows (at least two each). Last-two HH+HL is bullish; LH+LL is bearish; conflicting structure is neutral; missing confirmations are insufficient data. Strict mode rejects neutral/insufficient or opposing trend by default. Context-only records without veto; disabled mode ignores the trend gate. H4 context does not veto unless explicitly requested.

Trap recognition is done at the next entry candle's open using trap candles already completed at that instant. The following entry candle must finish before any structural confirmation can act. A trap candle can never confirm its own entry, including when trap TF equals entry TF. HTF candles are included only when their completion time is no later than the snapshot timestamp.

Pattern and impulse windows require consecutive valid OHLC candles. Missing entry bars invalidate pending setups and reset local structure. Unscheduled gaps reset trend structure and invalidate locations spanning the gap. Scheduled market closures use the symbol's broker session metadata; this is not a historical holiday database. Missing or inconsistent enabled histories block the affected decision. M1 data resolves HTF freshness inside an unfinished H1/H4 candle; otherwise an earlier touch in that hour could be missed. Missing M1 coverage during that refinement blocks the context.

## Six qualified locations

Each record stores category, source timeframe, upper/lower bounds, formation and confirmation times, direction, freshness/first-touch time, strength flags, validity, ID and invalidation reason. Bounds freeze when confirmed. IDs derive from category, timeframe and originating time.

1. **BSL:** a confirmed swing high whose pivot-candle range meets the significant-swing ATR threshold. Consecutive confirmed highs within equal-level tolerance form a bounded high reference. SELL needs penetration above its upper reference and rejection through the trap's range.
2. **SSL:** inverse confirmed-low reference, for BUY.
3. **Supply:** the opposing bullish candle immediately preceding a qualifying bearish departure; only confirmed strong zones are published.
4. **Demand:** inverse bearish origin before a bullish departure.
5. **Accumulation:** a completed consolidation after a measured bearish move; potential BUY spring below its low.
6. **Distribution:** inverse consolidation after a bullish move; potential SELL upthrust above its high.

Consolidation requires minimum bars, width bounded by ATR, at least the configured number of upper and lower touches, limited net drift (at most half the range width) and a preceding directional net move measured over its own lookback. A sideways range without that preceding move does not qualify. These are deterministic price-action classifications, not claims about institutional positions.

Supply/demand requires all of:

- An opposing origin candle followed by the configured number of consecutive directional departure candles. Each body meets the ATR threshold, close location and opposing-wick limits; net departure exceeds its ATR threshold.
- A completed close through a significant swing confirmed before departure began. The implemented conservative rule requires this BOS on the final departure candle.
- Freshness immediately before the trap sequence. Origin/departure candles do not count as retests. Any later overlap records first touch; an earlier retest disqualifies a fresh-zone entry. For a compound failed-breakout/re-entry trap, first contact within that same sequence belongs to that setup and is logged as `FIRST_CONTACT_IN_SEQUENCE`; a pre-sequence touch remains stale.

Zone bounds use the origin's full wick range by default, optionally its body. A completed close beyond the distal boundary invalidates supply/demand. Liquidity and consolidation references invalidate after the configured consecutive accepted outside closes; returning inside resets that count. Age is measured in source-timeframe interval equivalents, including elapsed calendar time. A newer overlapping reference does not move an older reference's bounds.

All qualified locations in the bounded lookback participate in detection. Matching prefers a strong supply/demand zone, then a liquidity reference, then accumulation/distribution, with latest-known reference breaking equal-rank ties. Overlap does not create repeated orders: one trap confirmation/direction has one setup identity, regardless of how many locations qualify.

## Three trap variations

**Classic:** one baby wholly within its mother range, followed by a one-sided sweep and completed close strictly back inside. Both-side sweeps are ambiguous and rejected. Inside tolerance and penetration are symbol-point inputs.

**Multiple baby:** configurable minimum/maximum inside candles before the same sweep/re-entry rule. The newest valid mother is selected deterministically; the default minimum is two babies, so it does not duplicate Classic.

**Range failed breakout:** a completed outside close after a mother/inside sequence, or against a qualified accumulation/distribution range, followed within the re-entry window by an opposite-body candle closing inside. Earlier intervening re-entry retires that event; a later candle cannot reuse it. Qualified ranges must already be known before the breakout, with bounded reference/pattern age. Excursion includes breakout through re-entry. Accepted-break location invalidation can expire this opportunity earlier than the maximum re-entry timeout.

All patterns require a directionally compatible qualified location. Mother/reference, baby count, sweep extreme, breakout and confirmation times, pattern category, associated location and stable ID are retained.

## Entry lifecycle

`WAIT_LOCATION / WAIT_TRAP → TRAP_CONFIRMED → WAIT_CHOCH (if applicable) → WAIT_BOS → VALIDATING_RISK → READY → EXECUTED or BLOCKED`.

`INVALIDATED` and `EXPIRED` are terminal for that candidate. Each meaningful transition records time and reason. Repeated identical wait messages are suppressed; each newly recognized rejected trap records profile, ID, direction, trend and available-location counts.

If opposing confirmed local structure exists, the first proposed-direction break is CHoCH. BOS must occur on a later candle, use a different pivot and respect its known-at time. Opposing structure that appears while waiting also activates the CHoCH requirement. If none exists, CHoCH is NOT_APPLICABLE, while directional BOS remains mandatory. Future-confirmed or already-broken pivots cannot be invented/reused.

Before readiness, any wick strictly breaching the frozen sweep extreme invalidates the trap. Invalid/expired location, incompatible trend/context, confirmation timeout, excessive entry extension and associated FVG failure also retire it. No reversal is generated from the invalidated candidate.

Optional FVG uses three completed entry-timeframe candles and the existing Option B helper. Only a directional gap whose displacement belongs to the trap/entry sequence and falls within age/distance limits is pinned to that setup. Midpoint crossing, boundary equality and wick-only penetration remain valid; a strict close beyond the outer boundary invalidates. No associated gap is allowed: FVG formation is not mandatory. An invalid gap cannot be replaced to erase its failure.

## Sweep SL and dynamic TP

BUY entry uses Ask; SELL uses Bid. SL is below/above the recorded sweep by an outward buffer: maximum of one tick and the sum of configured point, closed-trap ATR and current-spread allowances. It rounds outward to the symbol tick grid. Broker minimum distances are grounds for rejection, not justification to tighten SL inside the sweep.

Targets use confirmed valid opposing supply for BUY or demand for SELL from the configured zone timeframes. Search chooses the nearest unbroken opposing obstacle first, including overlapping or stale-but-unbroken zones. If that nearest zone fails freshness or its buffered target is not profitable, reject; do not skip it for a farther fresh zone. Invalidated zones may be excluded. TP is before the proximal boundary by at least one tick/configured buffer and rounds toward entry.

No opposing eligible zone produces `SMT_NO_VALID_TP_ZONE`. There is no fixed-R fallback and no forced 3R target. Price RR is reward distance / stop distance at the actual executable entry. Minimum RR is optional and defaults to 1.0. With it enabled, both price RR and conservative fee/slippage-adjusted monetary RR must pass. Even with the gate disabled, net estimated reward must be positive and SL/TP must have correct directions. Volume is never raised to compensate for low RR.

The shared planner still applies symbol session, permissions, quote/signal freshness, tick/volume rounding, broker stops/freeze, margin, account risk, pending-order, position and daily limits. SMT adds its own spread, risk, NY entry-order count, position and cooldown limits, bounded by the shared caps. Risk-percent sizing uses the smaller of shared requested risk and SMT's cap; fixed volume must independently satisfy actual monetary risk.

Immediately before send, SMT rechecks quote, spread, sweep, current context/location, target and broker stops/freeze. A changed executable quote or target is rejected rather than chased. The existing account mutex, consume-before-send rule, write-ahead intent and ambiguous-order halt remain in use.

After fill, actual entry RR is logged. If slippage violates target/risk/minimum RR, the owned position is halted/safely closed through existing reconciliation when execution is allowed. SMT **never** moves TP farther to restore a fixed RR and never widens SL. Strategies 1–3 retain their existing TP repair behavior.

## Ownership, recovery and chart output

Profile orders use `SBM.<id>` / `SBS.<id>` and distinct magics. Terminal global variables persist consumed identities; broker deal history reconstructs ownership/consumption. Historical readiness is retired during startup replay without sending orders. A common symbol/confirmation-time/direction key prevents the two profiles sending the same trap concurrently; account mutex serializes that decision. Uncertain sends still halt new entries until reviewed.

Hedging management is ticket/magic scoped. Netting blocks every new same-symbol entry when any position already exists. Whole-account risk/margin includes other EAs/manual trades while foreign positions are untouched. Magic numbers do not provide account-equity isolation.

SMT objects use the existing chart prefix plus `SMT`, profile and magic. Context draws at most 40 valid annotations to limit clutter; this display limit does not limit target/detection searches. Mother/reference, sweep, CHoCH, BOS and shared entry/SL/TP plan markers are separate. Panel reports trend/timeframe and candidate state. Both `InpDrawObjects` and `InpSMTDrawObjects` can suppress SMT objects; panel visibility uses `InpShowPanel`. Deletion is restricted to the owning prefix.

## Configuration and verification

See [all SMT inputs](SMT_INPUTS.md), [SMT verification](SMT_VALIDATION.md), and [changed files](SMT_CHANGES.md). `InpSMTRequireBOS` and `InpSMTDynamicTP` must remain true: turning them off is rejected at initialization rather than silently substituting weaker entry logic or a fixed target. Supplied profiles use strict alignment, all locations/patterns, fresh zones and demo-only signal observation.

Broker monetary calculations use [OrderCalcProfit](https://www.mql5.com/en/docs/trading/ordercalcprofit); timeframe durations use [MQL5 timeframe constants](https://www.mql5.com/en/docs/constants/chartconstants/enum_timeframes). No profitability claim follows from these engineering rules or short tests.
