# Historical NY range recovery and Volume Profile chart levels

S1 and S3 recover their exact New York sessions from completed M1 history, even when attached after the session. S1 remains NY 00:00–04:00; ORB remains NY 09:30–09:45 by default, with its existing opening-range duration input retained. Trading rules, strategy magics, account risk and execution controls are unchanged.

## Findings

- ORB already had a historical loader, but tried a broker M15 candle first. Any failure occurring more than five minutes after the range end permanently set `sb_orb.invalid`. Late attachment plus asynchronous history availability could therefore retire an otherwise valid day.
- S1 already attempted historical recovery. It required four exact broker H1 opens and continuous server-hour intervals. Those assumptions prevented recovery for mappings whose NY boundary did not align to broker H1 opens. It also provided no partial reconstruction while the range formed.
- Both M5 replay paths could turn missing history into a permanent invalid-day state. The top-level `sb_recovered` flag did not mean that every strategy had finished loading its range. Subsequent attempts needed their own history and timestamp guards.
- Unverified timezone configuration is a separate prerequisite failure. It is never evidence of an invalid trading date or a reason to guess an offset.
- Strategy 5 already calculated and froze POC, VAH and VAL. Its drawing path ran only when logging a newly available profile, silently depended on both draw switches, used different colours, provided no separate price labels and had no object repair/chart-change path. These are confirmed implementation limitations. Without the affected terminal's input snapshot and chart viewport, the exact reason its particular chart was blank cannot be established from the supplied description alone.

## Implementation

`SessionRange.mqh` is shared by S1 and ORB. It resolves each NY wall-clock boundary independently using the existing date-based NY DST conversion, and validates each mapped broker minute with a unique UTC round-trip. A broker fold, discontinuity, unsupported coverage or unverified mapping blocks recovery with its specific reason. It never reads the PC timezone or estimates a broker offset from tester clocks.

The loader requests only M1 candles in `[start, completed_cutoff)`, using `CopyRates` with an inclusive stop of `cutoff - 1`. It validates exact minute timestamps, all OHLC fields, chronological order, candle completion, count and nondegenerate final extrema. No H4/H1/M15 substitution remains in the range loaders. Native API interval and asynchronous history behaviour are described in [MetaQuotes' CopyRates documentation](https://www.mql5.com/en/docs/series/copyrates).

Before the session it reports `WAITING_FOR_SESSION`. During formation it reconstructs all completed minutes and reports `RANGE_FORMING`. A complete session becomes `RANGE_READY`; missing data becomes `RANGE_HISTORY_INCOMPLETE`, with a controlled 30-second retry. Forming ranges refresh at completed minute boundaries. Weekend dates report `DAY_INVALID / NY_WEEKEND`, throttled to an hourly check. The state resets on the next NY date, independently of the daily risk lock. Genuine S1 opposite-boundary invalidation still retires the setup for that NY day and is labelled `SETUP_INVALIDATED` on the panel. ORB's existing trading-end restriction is shown as `SESSION_EXPIRED` even when its range recovered successfully.

Coverage is deliberately strict: 240 M1 bars for an ordinary weekday S1 window and 15 for the default ORB window. The existing platform supplies weekly session declarations, not an authoritative historical holiday calendar. A weekday gap is therefore **not** silently called a holiday, interpolated or accepted as a valid range; it stays unavailable with an explicit reason. No new holiday data source or calendar exemption was invented.

M5 batches undergo coverage validation before setup replay. Missing data retries without permanently retiring the day. Replay retains S1 excursion/return/opposite-boundary behaviour and ORB structure, FVG Option B, continuation, reversal, liquidity and expiry rules. Historical confirmations cannot submit orders. Only the newest completed candle, closing after the existing startup recovery cutoff, can become actionable. Stable M5 timestamps prevent repeated processing. The existing signal-age, consumption and execution checks still apply.

Restart protection reuses `SBTradesTodayChecked`, which reconstructs entry **orders** from deal history by symbol, magic and NY-day boundary and deduplicates partial fills. The planner still applies S1's one-trade cap, ORB's existing cap, current independent positions, pending-order exposure and shared risk limits. Broker positions and pending orders are not recreated or cancelled. No persistence, ledger, risk or execution code was changed.

`VolumeProfileDrawing.mqh` draws only a validated frozen profile for the active broker day. It uses six stable `S5.VP.` objects under the existing chart-instance prefix: yellow solid POC, green dashed VAH/VAL, and three readable price labels. All periods are enabled. Objects update in place on profile rollover; stale objects are removed when the active reference becomes unavailable. A chart-change callback restores objects, and a 30-second presence check repairs deleted objects. Initial/restart profile recovery forces a redraw. The helper logs validation status, reference date, levels and object results; disabled global or VP drawing is explicit. The chart's price scale is not forced. A level outside the visible price viewport requires normal chart navigation.

MT5 reinitializes an EA when the chart symbol/period changes; profile recovery and redraw therefore run again on initialization. See [MetaQuotes' chart-period documentation](https://www.mql5.com/en/docs/chart_operations/chartsetsymbolperiod). `InpDrawObjects=true` and `InpVPDrawObjects=true` are both required. Existing user presets were not changed.

## Files

Runtime additions: `SessionRange.mqh`, `VolumeProfileDrawing.mqh`.

Runtime changes: `FourHourBreakout.mqh`, `OpeningRangeBreakout.mqh`, `ORBExternal.mqh`, `VolumeProfileRuntime.mqh`, `MQL5/Experts/ScalpingBot.mq5` and its rebuilt EX5. `ORBExternal.mqh` reuses the common NY inverse and strict M1 range validator; its liquidity and execution rules are unchanged. Strategy 2, Strategy 4 and Strategy 5 calculation/method/policy engines are unchanged.

Validation additions: `SessionRangeTests.mq5`, `prepare_range_recovery_tests.ps1`, `report_range_recovery.py`, `verify_range_recovery.py`. The repository and project verifiers select the new preservation/build record; `.gitignore` retains only compact new validation receipts.

## Validation

The native tester fixture includes the complete production EA. It runs synthetic fault/DST cases and calls the actual S1/ORB evaluation functions at simulated XAUUSD startup times. It also submits tester-only orders to verify restart counts and pending-order discovery. The fixture refuses to initialize outside Strategy Tester.

The final test receipt is `artifacts/range-recovery-v1/test-results.json`; raw tester logs, exact inputs, HTML reports and binary hashes stay in the local timestamped evidence directory. No running user-terminal executable or installed EA was replaced.

| Check | Result |
|---|---|
| EA and native fixtures | MetaEditor: 0 errors, 0 warnings |
| Native range/restart/chart fixture | 78 assertions; six timed startup scenarios; S1 and ORB both checked at NY 10:00 |
| Existing native timezone regression | 69 assertions |
| Existing native ORB regression | 100 assertions |
| Existing offline rules | 243 assertions |
| Existing offline risk/execution | 98 assertions |
| Python report tests | 18 tests |
| Preservation audit | 98 existing project files and 219 protected parent files unchanged |

Seven nonvisual native XAUUSD runs use M1 OHLC simulation:

- `2026.08.03` through `2026.08.04` exclusive: native fixtures, continuous production recovery and an unverified-mapping block test. Synthetic fixed UTC+3 is used for controlled tests. At NY 10:00, S1 recovers **240/240**, high **4072.07**, low **4051.92**; ORB recovers **15/15**, high **4035.54**, low **4019.00**.
- `2026.03.06` through `2026.03.11` exclusive: actual historical M1 recovery across the NY spring DST weekend with a synthetic EU broker rule. ORB's broker start changes from **16:30** on March 6 to **15:30** on March 9 while that broker rule is still in winter. Both strategies recover all expected candles. The first tester tick also recovers the previous completed NY date, March 5.
- `2026.10.23` through `2026.10.28` exclusive: actual historical M1 recovery across the synthetic EU broker autumn transition while NY remains in summer. ORB's broker start changes from **16:30** on October 23 to **15:30** on October 26. Both strategies recover all expected candles. The first tester tick also recovers the previous NY date, October 22.

Independent deterministic cases also cover the 2026 NY autumn change, the EU spring change, US/EU mismatch weeks, unverified mapping, custom broker jumps/folds, missing/duplicate/outside/future/invalid M1 bars, partial ranges, history retry, weekend restriction, setup expiry, historical confirmation retirement, repeated-candle idempotency, independent restart counts and pending orders.

Chart validation checks native object existence, styles, colours, prices, labels, all-period visibility, duplicate suppression, replacement, removal and recreation through the actual chart-change handler. Manual UI switching between M1/M5/M15 and a visual tester screenshot were not performed. The tests demonstrate object behaviour, not a visual screenshot review.

## Remaining configuration and scope

MetaQuotes-Demo's historical offset/DST policy remains externally unverified. Synthetic verified inputs are isolated test fixtures, not broker evidence. Published presets retain `InpBrokerTimeVerified=false`; configure fixed, EU, US or an explicit UTC transition table only after obtaining evidence covering the requested dates. Range recovery does not bypass that requirement.

No profitability, real-tick execution or live/demo forward-trading result is claimed. These changes do not guarantee a trade: existing fresh-confirmation, session, daily cap, risk, spread and execution rules still decide eligibility. The daily risk-lock setting is independent of recovery and was not changed.

To reproduce locally:

```powershell
./compile.ps1
./compile.ps1 -Source ./tests/SessionRangeTests.mq5
./compile.ps1 -Source ./tests/BrokerTimeTests.mq5
./compile.ps1 -Source ./tests/ORBTests.mq5
./tests/prepare_range_recovery_tests.ps1
# Use the matrix path printed by preparation:
./tests/run_backtests.ps1 -MatrixFile ./artifacts/range-recovery-v1/<timestamp>/matrix.json
python ./tests/report_range_recovery.py ./artifacts/range-recovery-v1/<timestamp>/matrix.json
./tests/verify_project.ps1
./tests/verify_repository.ps1 -VerifyReleaseSnapshot
```

Preparation requires an installed MT5 terminal and access to an existing demo-account cache. It runs a separate portable tester, blocks live trading there and preserves exact test evidence. Source, build and offline checks remain usable without the workstation cache.
