# Entry decision timing audit — 2026-11-02

All five strategies, including the optional legacy Triangle and the three Volume Profile methods, dispatch a fresh READY signal directly to `SBExecute` in the same evaluation. There is no order queue, next-candle submission step, or intentional sleep after entry confirmation. The EA evaluates on ticks and its one-second timer; its existing account mutex and quote/risk checks still apply.

## Findings and changes

1. **Shape context snapshot:** formation detection already uses the entry candle's closing timestamp following the earlier triangle fix. The optional higher-timeframe context filter still used the entry candle's opening timestamp. At an H1/M5 boundary, that withheld the H1 candle that had just closed, potentially blocking a valid entry using an older trend. Context now uses the same closing decision timestamp. Only fully completed candles are loaded. This does not make historical or unfinished confirmations actionable.
2. **Chart redraw work:** the common run loop drew Volume Profile levels before entry evaluation and before its per-second throttle. Chart-change callbacks also forced redraws even when the objects already existed. Drawing now follows strategy evaluations and releases the account mutex first. Chart-change callbacks respect the normal throttle for intact charts; deleted level objects still receive immediate repair. A successful repair cannot recursively force another redraw, and a failed repair clears the recorded drawn profile so the callback does not repeatedly force repairs.
3. **Execution diagnostics:** the existing executor body remains synchronous behind `SBExecuteImmediate`. The public wrapper writes `ENTRY_TIMING` after execution returns, including rejection and signal-only outcomes. No telemetry call is inserted before order submission. Durable order intent, ledger, broker checks, and protections remain in their existing order.

## Strategy review

| Strategy | Entry confirmation and dispatch | Required waits retained |
|---|---|---|
| S1 4H | The completed return-inside candle calls the executor immediately. | NY range completion and the breakout/return sequence. |
| S2 Shape | Readiness calls the executor in the current evaluation; formation and optional trend context now use the close timestamp. | Confirmed pivots, fresh breakout, retest and separate continuation, or reversal structure, as configured. |
| S2 legacy Triangle | The protective retest swing and continuation candle call the executor immediately. | Pivot confirmation, breakout, later retest, separate protective confirmation. |
| S3 ORB | `SBORBAdvance` calls `SBORBFinishCandidate` on the same bar that reaches READY. | Opening range, subsequent retest, conditional CHoCH/BOS and optional FVG rules. |
| S4 SMT | The confirming BOS candle calls `SBSMTFinish` immediately. | Trap close, later structure confirmation and distinct conditional CHoCH/BOS. The trap/location snapshot before the confirmation candle prevents using that candle retroactively. |
| S5 VP | All three methods are stepped independently and ready signals are coordinated and dispatched in the same evaluation. | Each method's own confirmation, simultaneous-signal conflict handling, shared VP position slot and risk limits. |

ORB's pre-bar external-level snapshot and SMT's pre-trap location snapshot are intentional chronological safeguards. They do not postpone a signal after it is READY. Pivot right-hand candles, trading-session starts, history availability, entry cooldowns, position limits, stale-quote rejection and broker responses are also distinct from an avoidable scheduling delay. Rejected or historical signals remain consumed rather than being chased on a later quote.

## Logs

`ENTRY_TIMING` reports:

- `confirmed` and `attempted`: broker timestamps of the completed confirmation and executor invocation.
- `confirmation_age_seconds`: elapsed market-clock seconds before the executor was invoked. This includes waiting for the next quote, terminal scheduling and earlier strategy work; it is not a measurement of broker latency.
- `processing_us`: local monotonic time spent in the executor, including validation and broker response if an order was sent.
- `presend_us`: local validation/persistence time before `OrderSend`, or `-1` if no order was sent.
- `broker_us`: time spent in synchronous `OrderSend`, or `-1` if it was not called.
- `result` and `reason`: the existing immediate execution disposition.

Broker timestamps have second resolution. Microsecond fields are local monotonic intervals, not synchronized broker clocks. The log is emitted after the action and cannot be used as the order's send timestamp itself. A broker rejection, partial fill or uncertain outcome retains its existing handling.

## Validation

The final EA and seven native fixtures compiled with **0 errors and 0 warnings**. Eight final historical tester runs passed **546 native assertions**: 22 decision timing, 27 existing Shape timing, 124 Shape, 100 ORB, 107 SMT, 88 Volume Profile and 78 session/range assertions, plus the all-five signal-only run. The production risk/execution harness passed **138 assertions**, including 21 checks of immediate send/signal-only/rejection across all seven routes; the rule harness passed **243 assertions** and the Python suite passed **18 tests**. The final run matrix is `20261102T143836/matrix.json`; earlier attempted matrices are retained locally and are not counted as final passes.

Run `tests/prepare_decision_timing_tests.ps1`, then the existing isolated `tests/run_backtests.ps1` with the generated matrix, then `tests/report_decision_timing.py MATRIX`. The matrix exercises the new timing fixture, existing Shape timing/Shape/ORB/SMT/Volume Profile/session-range fixtures and one all-five signal-only historical run with Shape context enabled. Native evidence, exact inputs and binary hashes are retained locally in `artifacts/decision-timing-v1`.

The timing fixture checks the real H1/M5 history cutoff, no future candles, immediate duplicate dispositions across all seven routes, S1 return readiness, redraw throttling and no placed orders. The risk/execution harness additionally exercises immediate mock broker submission, signal-only suppression and risk rejection for every strategy/method. Mocked API checks do not measure real broker performance.

Source input defaults, all profiles, monetary risk rules, setup-exit policy, strategy confirmation engines and CapitalGuard files are covered by the preservation audit. A first regression run caught delayed deleted-object repair; this was corrected and the final matrix was rerun. Final counts and build hashes are recorded in `test-results.json`, `project-verification.json` and `final-build.json` for this change.

These tests establish engineering behavior on the recorded historical sample, not guaranteed fills, zero wall-clock latency or trading profitability. Load the rebuilt `MQL5/Experts/ScalpingBot.ex5` to use the change; no input changes are required. The user's running terminal was not replaced or restarted.
