# Strategy 3: Opening Range Breakout

Research implementation inside the existing Scalping Bot EA. Strategy 1 and Strategy 2 signal rules are unchanged. All thresholds are provisional research parameters.

## Time and opening range

The reference is 09:30 America/New_York. The default range is [09:30, 09:45), and signals use completed M5 bars. US DST uses the existing historical New York conversion; every local boundary must round-trip uniquely to UTC. Broker timestamps use the operator-verified winter/summer offsets, DST rule and validity dates. Unknown or ambiguous mapping blocks processing. The broker mapping is a configured historical policy, not an inferred timezone database; use a validity interval in which that policy is accurate.

At range completion, use the single completed native M15 candle only when its start and end match the requested interval exactly. Otherwise aggregate all complete M1 candles with exact consecutive boundaries. Missing, duplicated or inconsistent candles cannot produce a range. History loading has a five-minute grace; continued failure skips that NY day. Levels freeze after finalization. An M5 gap after the opening session starts invalidates the day. Overnight/weekend gaps in the structural warmup reset structure instead of invalidating the next session.

The opening duration is configurable from 1 to 120 minutes. Confirmation remains M5; other signal timeframes are rejected at initialization. Trading ends at 16:00 NY by default. The next NY date resets pending ORB state and ORB chart objects, without closing positions.

## State machine

The range starts in `WAIT_OPENING_RANGE` and becomes `RANGE_READY`. A completed close must newly cross the range boundary plus clearance; wicks and successive already-outside closes do not create breakouts.

Continuation and reversal have separate candidate records:

| Phase | Requirement |
|---|---|
| `BREAKOUT_DETECTED` / `WAIT_RETEST` | Track excursion; wait for a later candle touching the boundary tolerance and closing on the breakout side. |
| `WAIT_CHOCH` | Required for an identifiable opposing continuation pullback, and always for a reversal. |
| `WAIT_BOS` | A distinct, later break of a previously confirmed swing in the entry direction. |
| FVG validation | Conditional guard while the candidate advances; no FVG is permitted. |
| External validation / `READY_TO_TRADE` | Evaluate current executable quote, SL, TP, extension, external room and HTF policy through the shared planner. |
| `TRADE_EXECUTED` / signal-only | Decision retired; no repeated sends. An accepted order remains subject to normal fill reconciliation. |
| `INVALID` | Failed structure, invalid associated FVG, renewed failed-side breakout or broken protective structure. |
| `EXPIRED` | Retest, confirmation, FVG age or trading-window timeout. |
| `BLOCKED` | A confirmed signal failed execution/risk/exposure/broker checks; it is consumed rather than chased. |

Returning strictly inside the range cancels pending continuation and can arm the opposite reversal. It is never entry confirmation. The failure observer remains independent if continuation mode is disabled or a continuation filter rejected its candidate. It stops after the observation timeout or a completed/blocked continuation decision, preventing opposite decisions from the same confirmed continuation. An active reversal owns that breakout sequence; a second continuation cannot be armed alongside it.

## Confirmed structure and protective stops

A pivot must exceed every neighbor on both sides (strict inequalities; equal extrema do not qualify). Left/right strengths default to two. The pivot stores its candle time, price, type, confirmation close time and broken flag. It becomes available only after all right-side candles close, with contiguous bars. Break detection runs before registering newly confirmed pivots, so a pivot cannot be confirmed and broken at the same close.

BOS uses the latest unbroken confirmed high for BUY or low for SELL, with a completed close beyond tick-aware clearance. HTF trend uses the last two confirmed highs and lows: HH+HL bullish, LH+LL bearish, otherwise mixed/insufficient. Breaking a pivot marks it broken; no repeated event is emitted from that pivot.

A mechanically opposing HH+HL or LH+LL pullback latches the continuation CHoCH requirement. Its first directional structural break is CHoCH. BOS must follow on a later candle, break a different pivot, and use a pivot that became known after CHoCH. Reversals always wait for opposing confirmed structure and this sequential transition; missing pivots cannot bypass it. Continuation BOS pivots must belong to the retest or later; reversal pivots must belong to the return-inside sequence or later. These deliberately conservative definitions can produce few signals.

Continuation SL uses the latest unbroken confirmed protective low/high at or after the retest, known before the confirmation candle, plus an outward buffer. A protective close-through invalidates the setup. Reversal SL uses the maximum failed-upper excursion for SELL or minimum failed-lower excursion for BUY, including subsequent pending reversal candles, plus buffer. A renewed completed close beyond the failed ORB boundary plus invalidation allowance rejects that reversal. Stops are never tightened to manufacture reward room or widened after entry. TP derives from the actual Ask/Bid entry and rounded final SL, at a minimum of 2R. Fill risk and minimum RR remain monitored by the existing position manager.

## FVG Option B

Use three completed consecutive M5 bars. Bullish zone: first high to third low. Bearish zone: third high to first low. Require minimum gap size and maximum anchor distance. The middle/displacement candle must be at or after this candidate's start and within the association-age window. The first qualifying directional FVG is pinned to that candidate; unrelated historical gaps cannot reject it, and an invalid gap cannot be replaced to erase its failure.

Midpoint crossing, outer-boundary equality and wick penetration remain valid. A strict completed close beyond the far outer boundary invalidates the candidate. Expired associated gaps expire their candidate. An absent FVG does not reject a structurally confirmed setup. FVG detection/validation is disabled together by its independent switch.

## External levels and higher timeframes

Defaults use NY calendar days and Monday-to-Monday NY weeks. Previous day means previous weekday, skipping Saturday/Sunday, without a holiday calendar. Previous-week levels use the fully completed prior week. Calendar convention can instead be UTC. Each boundary is converted separately, including weeks crossing DST. Current unfinished daily/weekly extremes are never substituted.

Asian and London reference windows default to 00:00–06:00 UTC and 07:00–09:00 UTC respectively, configurable as UTC minute-of-day boundaries. These are explicitly fixed UTC research windows, not automatic Tokyo/London civil-time calendars; adjust them deliberately when that is the intended convention. Only fully finished windows are used. Overnight external session windows are not supported by these inputs.

External calendar extrema use complete M1 records within exact boundaries. Coverage defaults to at least 70% of expected weekday/session minutes to permit broker closures. This is a data-quality threshold, not proof of complete history; unseen missing extrema remain a limitation. Missing required enabled context blocks entry. H1/H4 levels and structure use completed candles and the same confirmed-pivot logic. The last confirmed high and low of each timeframe are exposed, not an unbounded collection of every historical pivot.

Each reference stores type, source, known time, price, high/low side, touched/swept/close-beyond flags and side relative to proposed entry. High-side sweep requires penetration above clearance and a completed return below within the bounded confirmation window; low-side is inverse. Sweep context alone never permits entry.

Reward room uses the executable entry and final rounded stop/target. For BUY, opposing high references at/above entry are checked; SELL checks low references at/below entry. Levels within the configured proximity behind entry are treated as unresolved nearby obstructions. Room must exceed the actual target distance plus proximity buffer.

- Policy `0 Strict` rejects insufficient room.
- Policy `1 Warning` logs the obstruction and permits shared risk evaluation.
- Policy `2 Selective` can disregard a level only after two consecutive completed closes beyond clearance, recorded acceptance before the decision, with the executable entry still beyond that level. One candle or a wick is insufficient.

H1/H4 context is with-trend when both agree with the trade, countertrend when both oppose, otherwise mixed/neutral. Default countertrend policy `0 Record` imposes no veto. Policy `1 Block` rejects countertrend. Policy `2 Require sweep` requires an opposing-side external sweep from this candidate sequence in addition to normal structural confirmations. Mixed context is not forced into agreement.

## Shared execution, restart and diagnostics

ORB owns its magic, two modes, NY trade counter, position limit, owner lock and consumed signal keys. Account caps include all account positions, including foreign EAs/manual orders, while protection management only touches owned tickets/magics. Netting blocks every new same-symbol entry when a position already exists; hedging retains ticket ownership. Account mutex, pending-intent WAL, volume/margin/spread/stops/freeze checks, uncertain-send halt and no duplicate retries are shared.

Recovery replays completed bars in chronological order without placing historical orders and retires completed confirmations. Consumed identities survive restart as terminal global variables, and broker entry comments `SBOC.<id>` / `SBOF.<id>` reconstruct mode-specific consumption from deal history. Replay may rebuild valid pending state for later fresh candles; missing reconstruction history skips the day. Operator input changes are new research configurations; do not assume old pending states are compatible.

Logging is transition-driven, with broker and NY timestamps, ORB levels, mode, retest/CHoCH/BOS/FVG state, HTF context, sweep context and proposed trade geometry. Executable planner logs add actual risk/spread/volume and reject reason. Each external reference considered at a final validation is logged with availability and sweep flags. Order-block diagnostics are a simple opposite-candle/displacement annotation only, with no entry filter. No CRG, ML, indicators or external database was introduced.

ORB chart objects use the existing chart prefix plus `ORB.`. Independent range/external/structure/FVG/sweep/signal visibility switches are subordinate to `InpDrawObjects`. Entry, SL and TP marks use the shared order-plan drawing. Drawings describe signals/plans; order-result and deal logs distinguish actual execution.

## Configuration reference

All ORB inputs, defaults and units are listed in [ORB inputs](ORB_INPUTS.md). The four demo profiles contain the complete input set and unique ORB magics. Global signal-only and real-account blocks remain enabled. The default code magic 26103122 is independent of the default 4H/Triangle pair; distributed profiles use separate ORB magic numbers to avoid the existing Forex profile magics.

See [ORB validation](ORB_VALIDATION.md) for the exact tested binary, test evidence, unavailable results and demo checklist. The original V1 two-strategy validation remains historical evidence for its original binary.

API references: [MQL5 CopyRates ordering and time intervals](https://www.mql5.com/en/docs/series/copyrates) and [symbol stops, freeze, tick and volume properties](https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants). The implementation processes oldest-to-newest physical arrays and checks completion/availability explicitly.
