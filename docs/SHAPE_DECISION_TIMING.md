# Shape decision timing

Shape now reads completed formation candles at the current completed entry candle's **close**. With the M15 formation/M5 entry profile, a formation candle completing at 13:15 is processed at the 13:15 decision rather than being withheld until approximately 13:20.

The two-right-candle swing confirmation setting is unchanged. A swing in the 12:30 M15 candle still needs the 12:45 and 13:00 candles to finish, so its confirmation remains 13:15. This change removes the additional entry-cycle lag; it does not make that swing available before its confirmation.

## Root cause and decision policy

`SBEvaluateShape` previously calculated `decision = b.time + entrySeconds`, but loaded formation history with `b.time`. At an M15/M5 boundary, this discarded the just-completed M15 candle. `SBShapeStep` also required pattern references to be known before the entry candle opened. Changing the loader alone would register/draw the pattern sooner while still ignoring a breakout closing at that boundary.

The fix separates the decisions:

- Formation detection receives the completed entry **close** timestamp. `SBShapeLoad` still excludes every formation candle whose close is later than that cutoff. An explicit runtime guard also rejects a future entry decision.
- A candidate records both the original pivot-confirmation time and its first available detection time. Late discovery is not backdated to the earlier pivots. These times are included in `PATTERN_DETECTED` logs.
- `SBShapeDecisionStep` accepts a fresh **closing breakout** when final pivot confirmation and availability occur at that exact close. It checks the crossing, direction, body/displacement and consecutive preceding candle. Sloping boundaries are evaluated at the actual closing decision.
- That decision starts `WAIT_RETEST`; it cannot also become a retest, reversal or entry. A later completed retest and then a separate continuation close remain mandatory.
- Intrabar wick movements before the pattern existed cannot become sweep/reversal signals. A breakout already underway on an earlier completed candle is not chased.
- Once references were available at candle open, the original `SBShapeStep` handles the existing continuation, sweep, reversal, CHoCH, BOS, invalidation and expiry logic unchanged.
- A per-candidate completed-close timestamp suppresses duplicate decisions. The existing global replay cursor, signal consumption, historical-confirmation retirement and execution guards remain active.

This is a decision-timing change, not a forming-pattern preview. No unconfirmed swings, future candles or provisional visual patterns are used for trading. Existing missing-data/session-gap handling and optional context timing are unchanged. Data availability, session/risk gates and a valid fresh setup still determine whether a trade can occur.

## Screenshot verification

The user's triangle was identified in the live journal as pattern **1357682230**, with its final 12:30 swing confirmed at **2026.11.02 13:15 broker time**. The previous implementation logged detection at approximately **13:20 broker time**.

A native, read-only MT5 replay retrieved the actual closed XAUUSD candles with a strict 13:15 cutoff. It found the same pivot sequence and pattern ID. The old cutoff's last formation candle opened at 12:45; the corrected cutoff includes the 13:00–13:15 candle. The production detector and candidate registry now record:

```text
id=1357682230 pivotKnown=2026.11.02 13:15:00 available=2026.11.02 13:15:00
```

The replay correctly remains `WAIT_BREAKOUT`: the screenshot's price move was already underway before final confirmation. The fix does not reinterpret that earlier breakout as a fresh one. Native synthetic tests separately demonstrate immediate `WAIT_RETEST` decisions for both BUY and SELL breakouts that first close beyond the boundary at the same instant the pattern becomes confirmed.

The read-only script runs exclusively in the disposable workspace terminal. It calls history/detection/decision functions, exports the exact candle inputs and writes a test receipt; it never invokes order submission. The running user terminal was neither replaced nor restarted.

## Validation

Compilation produced **0 errors and 0 warnings** for the EA, timing fixture, screenshot replay script and Shape regression fixture.

| Check | Result |
|---|---|
| Native timing fixture | 27 assertions passed, including real M15/M5 history boundaries |
| Existing native Shape suite | 124 assertions passed |
| Native screenshot replay | 8 assertions passed against actual closed market candles |
| Existing production rule adaptation | 243 assertions passed |
| Existing production risk/execution adaptation | 117 assertions passed |
| Python reporting tests | 18 tests passed |

Three successful Strategy Tester runs used XAUUSD M1 OHLC data: the timing and Shape regression fixtures cover **2026.08.03–2026.08.04 exclusive**; a production signal-only run covers **2026.08.03–2026.08.05 exclusive**. Test clock mappings are explicit synthetic inputs and do not verify the historical broker timezone.

The attempted full tester run for **2026.11.02–2026.11.03** did **not start**: MT5 rejected the future end date and logged `set mode to math calculations or adjust testing dates`. The screenshot was therefore verified with the separate native closed-history replay described above. It is not reported as a successful full-day backtest. MT5's startup configuration specifies testing boundaries as calendar dates; see [the official configuration reference](https://www.metatrader5.com/en/terminal/help/start_advanced/start).

Tests cover exact confirmation-close decisions in both directions; unchanged pivot-right confirmation; future data rejection; fresh versus earlier breakouts; first-discovery timing; wick-only pre-confirmation movements; weak/wrong-direction breakouts; missing preceding candles; sloped boundaries; duplicate-close suppression; and separate retest/continuation requirements. The original state-machine function is unchanged, and its native regression suite still passes.

The preservation audit verifies all input defaults, all presets, risk/execution code, setup-based exit policy, other strategy modules and 219 protected parent-workspace files remain unchanged. No live profitability, real-tick fill quality or guaranteed trade result is claimed.

Runtime files changed: `ShapeRuntime.mqh`, `ShapeEngine.mqh`, `ShapeTypes.mqh` and rebuilt `ScalpingBot.ex5`. The candidate's availability/evaluation fields are reconstructed from history; the durable trade-journal schema is unchanged. Supporting files add native fixtures, preparation/replay/report helpers, preservation verification and compact build/test receipts.

## Use and reproduction

Load the rebuilt `MQL5/Experts/ScalpingBot.ex5` in MT5. No input changes are required. Keep the existing formation/entry timeframes and pivot confirmation settings.

```powershell
./compile.ps1
./compile.ps1 -Source ./tests/ShapeTimingTests.mq5
./compile.ps1 -Source ./tests/ShapeTests.mq5
./compile.ps1 -Source ./tests/ShapeTimingScreenshot.mq5
./tests/prepare_shape_timing_tests.ps1
./tests/run_backtests.ps1 -MatrixFile ./artifacts/shape-timing-v1/<timestamp>/matrix.json
./tests/run_shape_screenshot.ps1 -MatrixFile ./artifacts/shape-timing-v1/<timestamp>/matrix.json
python ./tests/report_shape_timing.py ./artifacts/shape-timing-v1/<timestamp>/matrix.json ./artifacts/shape-timing-v1/<timestamp>/<screenshot-evidence-folder>
./tests/verify_project.ps1
./tests/verify_repository.ps1 -VerifyReleaseSnapshot
```

The screenshot script deliberately targets the reported 2026.11.02 candles. Preparation uses the existing isolated-runtime helper and requires the workstation's MT5 installation/demo cache or explicit replacement paths. Raw native logs and exported candles remain local; compact results include their hashes. No new files are installed into the running user terminal automatically.
