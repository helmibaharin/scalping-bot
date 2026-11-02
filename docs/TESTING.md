# SMT verification workflow

Compile the EA, tests/SMTTests.mq5 and tests/ORBTests.mq5 with compile.ps1 -Source <path>. Run test_rules.ps1, test_risk_execution.ps1, verify_project.ps1 and Python unittest discover -s scalping-bot/tests -p test_analyzer.py.

tests/prepare_smt_backtests.ps1 prints a fresh nine-scenario matrix: two SMT fixtures, the ORB fixture, two original-strategy combined regressions, and MTF/SCALP market runs on EURUSD/XAUUSD. Run only that matrix through run_backtests.ps1 -MatrixFile <path>, then analyze_backtests.py --matrix <path> and verify_smt_evidence.ps1 -MatrixFile <path>. A locally selected demo account and synchronization are needed; preparation copies no passwords/account records. Runtime account files are excluded from packages.

Synthetic native fixtures exercise production positive/negative rule paths, not market performance. Results must match their EX5 hashes. See [current SMT verification](SMT_VALIDATION.md), [manual tester scenarios](SMT_INSTALLATION.md) and [rules](SMT.md).

# ORB test extension

Compile both the EA and the tester-only deterministic fixture:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scalping-bot\compile.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scalping-bot\compile.ps1 -Source .\scalping-bot\tests\ORBTests.mq5
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scalping-bot\tests\prepare_orb_backtests.ps1
```

The preparation prints a new timestamped matrix under `artifacts/orb-v1/`. Pass that exact matrix to `tests/run_backtests.ps1 -MatrixFile <path>`, then `tests/analyze_backtests.py --matrix <path>`. It contains a native production-function fixture plus four symbols in 4H-only, Triangle-only, ORB continuation-only, ORB reversal-only and combined modes. Prior matrices are preserved. The portable terminal requires the operator's existing demo account selected and a network connection for synchronization. Market caches are copied read-only; preparation does not copy account credentials. If account setup is missing, record the native launch as unavailable rather than claiming tests passed. Keep runtime account files out of release packages.

The native fixture is tester-only, calls the production functions, and reports `ORB_TEST_RESULT | checks=... failures=0`. Its code includes both direction/mode paths, DST and exact range boundaries, pivot timing, sequential CHoCH/BOS, conditional FVG Option B, level room/policies, sweeps, HTF classification and historical replay retirement. `test_risk_execution.ps1` covers shared ORB limits, hedging/netting, freeze constraints and duplicates with mocked broker APIs. This is engineering coverage; short market runs do not prove entry frequency or profitability. See [current ORB evidence](ORB_VALIDATION.md).

The earlier two-strategy testing procedure follows for historical reproduction; disable ORB explicitly when reproducing those modes using current input defaults.

# Testing and backtesting

## Deterministic tests

Run `tests/test_rules.ps1`, `tests/test_risk_execution.ps1` and `tests/verify_project.ps1` with PowerShell execution policy bypass for that process. The first two read production MQL functions and adapt syntax to C#, with mocked quote/account/order APIs. They verify decisions and state transitions, not terminal execution or profitability. Source/profile/isolation checks verify all four profiles and the recorded pre-existing project files. `python -m unittest discover -s scalping-bot/tests -p test_analyzer.py` tests result arithmetic without external packages.

Coverage includes body versus wick crossings; 150-bar/large-extension 4H waiting; correct reversal direction; return candle excursion; conflict invalidation; final-stop 2R; NY/broker DST transitions and ambiguity; pre-2007 rules; all three triangle classifications, both breakout directions, confirmed pivots, stable IDs, retest and separate continuation, structural stops, timeout, failure and deduplication; resistance/order-block validity; risk sizing/rounding, independent limits, hedging/netting, real-account default, stale quotes/history, margin, stop/filling rules, pre-send persistence, partial fills, uncertain results and two accepted strategy signals under refreshed exposure.

Unverified by deterministic adaptation: network/broker execution, native multi-terminal coordination, broker-specific slippage/fees, live reconnect reliability, manual netting interference, every historical timezone rule and long-horizon statistical performance. These limitations remain even when all assertions pass.

## Isolated native Strategy Tester

`prepare_backtests.ps1` creates a separate portable terminal under this project and copies market/symbol caches read only. Locked cache files are recorded, with archived read-only cache fallback where available; it never stops the existing terminal. The portable terminal needs its own demo account context and may synchronize broker historical data. Do not copy existing account credentials. Disable normal-chart trading in its `[Experts]` section. All execution profiles belong only to the tester.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scalping-bot\tests\prepare_backtests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scalping-bot\tests\run_backtests.ps1
```

The runner uses local agents only, port 32311, no cloud/remote agents, a bounded per-test timeout, and a hidden separate terminal. A timeout stops only that exact portable terminal process. Existing reports are not replaced. It stores per-run input/config references, binary hash, fresh log slices, EA audit CSVs and native HTML report where available. Generated binary/cache/account files under `artifacts/test-terminal` are local runtime data and must not be published or committed.

If an uninitialized portable terminal cannot establish a tester account, its automatic demo-account setup may need completion; a run with no `SCALPING BOT | TESTER` result is not a passed test. Startup and tester errors are preserved. Inspect `cache-status.json` and real-tick generation messages instead of assuming Model=4 guarantees perfect history. Retry an initial history-download timeout only after the failure cause is understood.

The engineering matrix has XAUUSD, EURUSD, GBPUSD and USDJPY, each with 4H-only, Triangle-only and combined modes. Initial dates are 2026-08-03 through exclusive 2026-08-05. Broker UTC+3 is a declared assumption for those dates, not an automatically inferred fact. Run real ticks where supplied and inspect fallback/data warnings. Fixed 0.01 volume, actual symbol properties, modeled spread and requested 100 ms execution delay are used; commission is zero unless configured. These short tests are not a realistic-cost profitability study.

## Later chronological out-of-sample engineering validation

Freeze strategy parameters before viewing the later interval. The supplied OOS preparer uses 2026-08-10 through exclusive 2026-08-12 and reuses the same `.set` files and binary. No fitting or optimization occurs. Run the same 12 combinations; keep them separate from the earlier smoke tests:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scalping-bot\tests\prepare_oos.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scalping-bot\tests\run_backtests.ps1 -Matrix .\scalping-bot\artifacts\out-of-sample\matrix.json
```

A two-day later sample is only an engineering holdout. A serious study needs multiple unseen months, spread/commission/slippage stress, different volatility regimes and independent broker data. Do not tune on these results and continue calling them untouched OOS. Repeat chronological walk-forward validation with frozen parameters and appropriate gaps after any strategy changes.

## Metrics and audit

Run `tests/analyze_backtests.py --matrix <matrix.json>`. It writes `RESULTS.md` and detailed `results.json` beside that matrix. The native tester reports account trade count, profit, PF and maximum equity drawdown. The audit ledger adds per-strategy trade count, win rate, monetary risk, realized R, spread/slippage, rejection counts, triangle type and 4H SL-method breakdowns.

Per-strategy ledger drawdown is **realized cash P&L drawdown**, not mark-to-market account equity drawdown. Forced tester end-of-period closures may occur after the last EA trade callback; those positions can remain unmatched in the EA CSV even though native tester totals include them. Such records are explicitly listed and excluded from closed-trade ledger metrics, never filled in with invented exits. Unknown initial risk, fees or slippage must remain unavailable. Use native deal reports for complete forced-close totals and a longer interval so forced-close effects are not dominant.

Review switch independence in the three native modes, trade ownership, concurrent hedging positions, SL/TP persistence, missing-data decisions, session/holiday behaviour and structural stop events. Netting and multi-chart/multi-symbol stress tests require further dedicated native account-mode tests before production use.


