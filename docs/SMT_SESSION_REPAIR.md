# SMT session and history retry repair

The 2026-11-02 investigation reproduced a shared session-helper defect: MetaQuotes-Demo XAUUSD supplies a Saturday `0–0` session row, which the EA classified as 24-hour trading. SMT then rejected normal weekend gaps and erased its trend structure despite having 300 synchronized completed D1 candles. The original read-only diagnostic recorded 62 D1 resets and 10 H4 resets in the respective samples. [Original investigation](SMT_AUDIT_20261102.md).

## Changes

- Added the pure `SBSessionContains` interval predicate and routed the shared `SBSession` helper through it. It preserves the raw duration, rejects a zero-length row, accepts an actual `0–86400` full day, handles overnight spill from the preceding day, and uses inclusive start/exclusive end boundaries. Malformed intervals fail closed. All existing monetary risk logic remains unchanged.
- `SBSMTCheckTrap` now reports whether required history is ready. It commits `last_trap` only after the zone snapshot succeeds. If trap or zone history is pending, the SMT entry loop returns without advancing its entry cursor or structure, allowing the exact same snapshot to retry on a later run. Already evaluated, active and stale traps retain their existing retirement behavior. Historical or stale confirmations are not chased.
- Separated `SMT_TREND_INSUFFICIENT_DATA` from `SMT_TREND_NEUTRAL` and `SMT_TREND_MISMATCH` at initial trap rejection and during active candidate validation. This changes diagnostic wording, not trend permissions.

No input or preset changes are required. Confirmed pivots, trend direction, fresh-zone checks, trap patterns, conditional CHoCH/BOS, stop/target geometry, monetary risk, broker checks, duplicate suppression and strategy independence remain in force.

## Validation

The EA and native regression fixtures are rebuilt through the existing zero-error/zero-warning compiler gate. The new `SMTRepairTests` executes the production session predicate and actual SMT trap/runtime functions, substituting only the history-fetch boundaries for deterministic failure/recovery tests. Its 25 assertions cover zero/full/overnight sessions, actual broker weekend gaps, a real missing weekday candle, diagnostic distinctions, repeated pending-history snapshots, successful same-candle recovery, duplicate/stale retirement and no orders from the fixture.

The isolated historical matrix also reruns the earlier timing, Shape, ORB, SMT, Volume Profile and range suites plus the all-five signal-only test. Compact final receipts and source/binary fingerprints are in `artifacts/smt-repair-v1`; raw logs, exact tester inputs and reports stay local. The production risk/execution and rule harnesses additionally cover monetary safeguards and immediate order routing using mocked broker APIs.

Final validation: **nine MT5 runs passed, with 571 native assertions**; **138 risk/execution assertions**, **243 rule assertions** and **18 Python tests** passed. The final matrix is `20261102T154022/matrix.json`. The EA and all nine compiled native fixture/diagnostic programs passed the zero-error/zero-warning gate. Source/preset preservation and all 36 CapitalGuard file fingerprints passed.

The post-repair read-only current-history diagnostic (`20261102T154022/live-after.txt`) confirmed `load_ok=1` for D1, versus `0` before the repair. The D1 sample's resets fell from 62 to 3; H4 resets fell from 10 to 0. D1 classified **NEUTRAL**, with 4 confirmed highs and 9 lows, and H4 classified **BULLISH**, with 36 highs and 37 lows. The remaining D1 resets relate to gaps still rejected by historical validation. A strict D1 profile may consequently still wait because the actual reconstructed D1 trend is neutral; a trade is not promised by removing the false history blocker.

## Remaining historical-data limitation

This repair does not infer an older session calendar from today's weekly metadata. Older weekday/holiday gaps that current metadata calls tradable remain rejected. The earlier H1 sample includes such gaps around midnight. Their resolution requires historical schedule evidence or complete history; the fix does not silently waive them. The original D1/H4 weekend false-positive is corrected independently of that limitation.

The user's installed terminal is not changed or restarted by these tests. To use the repair, replace the installed EA with the rebuilt `MQL5/Experts/ScalpingBot.ex5`, or copy the complete updated source tree and compile `ScalpingBot.mq5`. Copying only the main `.mq5` file is insufficient because the repair includes updated headers and a new `SessionSchedule.mqh` dependency.
