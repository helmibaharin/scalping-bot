# Current SMT extension

The current four-strategy build is documented in [SMT verification](SMT_VALIDATION.md). Earlier ORB and two-strategy results below belong to their recorded binary hashes; do not attribute them to the current SMT build.

# Current ORB extension

The two-strategy validation below is historical and belongs to its recorded original EX5 hash. Current Strategy 3 verification, separate ORB-mode results and deployment limitations are in [ORB validation](ORB_VALIDATION.md). Do not attribute the earlier 24 runs to the current binary.

# Validation results â€” Scalping Bot V1.0

Validated on 1 November 2026, Malaysia time. This is an engineering validation of a first implementation, not a profitability or live-readiness certification.

## Compilation and deterministic checks

| Check | Result |
|---|---|
| Native MetaEditor compilation | **0 errors, 0 warnings** |
| Production rules/timezone/structure/triangle state-machine adaptation | **243 assertions passed** |
| Production risk/execution adaptation | **45 assertions passed** |
| Complete profiles, source guards and existing-project isolation | **36 checks passed** |
| Backtest metric arithmetic unit suite | **2 tests passed** |
| Existing protected files compared by SHA256 | **219 unchanged** |

The adaptations run production function bodies with C# syntax/API-boundary adjustments. Broker sends, quotes, state APIs and account modes are mocked in those suites. Native MT5 execution is separately covered below. The source, profiles and binary hashes are in `artifacts/release-manifest.json`; the native compiler log is beside `MQL5/Experts/ScalpingBot.mq5`.

Validated EA binary SHA256:

`4E6EEF4AE9A4982938417D919DBD40887D24C6CA869AB5BFA4B8BCBA22330293`

## Native backtests

The same binary completed **24 native MT5 runs**, each reporting real-tick generation and a native HTML result:

- **12 initial runs:** 2026-08-03 through exclusive 2026-08-05.
- **12 later chronological engineering holdouts:** 2026-08-10 through exclusive 2026-08-12, same strategy parameters; no optimization or fitting.
- Each interval includes XAUUSD, EURUSD, GBPUSD and USDJPY, each in 4H-only, Triangle-only and combined modes.

Results and detailed per-strategy audit data:

- [Initial matrix](../artifacts/backtests/RESULTS.md), with `results.json`, native HTML, per-run CSVs, logs and binary hashes in that directory.
- [Later chronological matrix](../artifacts/out-of-sample/RESULTS.md), with equivalent evidence.

All three triangle types produced executed trades across these runs. Initial native 4H trades exercised breakout-extreme and resistance stops; bullish order-block selection passed deterministic structure tests but did not produce a native entry in these short samples. Disabled-strategy modes generated only their own strategy entries; combined runs exercised separate strategy positions and account limits. Native account mode was demo hedging. Netting collisions, uncertain results, partial fills and failure handling were tested with mocked APIs, not by sending fault-inducing live broker orders.

Native tester totals include all forced final exits. Two positions in the initial matrix have no final EA callback row, so strategy ledger metrics explicitly list them as unmatched instead of fabricating close records. The later matrix has zero unmatched ledger positions. Per-strategy realized cash drawdown is distinguished from native account-equity drawdown. Native PF may display zero when no losses make PF undefined; the ledger reports that case as unavailable. No selected tick-quality warning phrases were detected, but this is not proof of perfect broker history.

The broker mapping assumption for both August intervals is fixed UTC+3. Test volume was 0.01, deposit 10,000 USD, commission estimate zero, and tester execution delay 100 ms. These are engineering settings and broker data, not a realistic-cost profitability study. Positive and negative results both occurred. Two-day samples, fees/spread quality, forced exits and limited market regimes prohibit a profitability claim.

The first XAUUSD run timed out during initial history synchronization; retry after synchronization completed successfully. The portable terminal automatically updated from build 6259 to 6296 during the later matrix, interrupting some process launches. Those runs were retried, with prior attempts/logs preserved, and every matrix entry ultimately completed. The runner follows the separate portable installation through updater restarts. Original MetaEditor build 6259 produced the EA binary; per-run logs retain terminal builds. Cross-build reproducibility remains a limitation even with identical EA/parameter hashes.

## Isolation and trade safety confirmation

- Project files were created only under the existing workspace's new `scalping-bot` subfolder. No nested `trading-robot` directory was created.
- CapitalGuard source, profiles, documentation, tests and supporting ML code remained unchanged under the recorded 219-file check. Existing research data/models/journals and schedules were not targeted or written by this project; background collectors were left alone.
- No EA was installed into or attached to the existing terminal. A separate portable terminal used its own demo account context, caches and local tester agent.
- **No live/demo-market trading orders were submitted.** Orders in the evidence are Strategy Tester simulations. Normal-chart trading in the portable terminal was disabled; the separate demo terminal synchronized with zero live positions/orders.
- Distributed profiles remain signal-only, real-account permission false, both strategies independently enabled, all three triangle types enabled, and broker mapping unverified until the operator configures it.
- Runtime namespaces, ownership locks, magic pairs, diagnostic/chart objects and state are separate from CapitalGuard.

## Remaining work before deployment

Broker-specific demo forward testing, long unseen chronological studies, stressed fees/spreads/slippage, native netting and multi-chart fault/restart tests, broker-specific historical timezone verification and manual operational review remain necessary. See [known limitations](KNOWN_LIMITATIONS.md), [testing](TESTING.md) and [installation](INSTALLATION.md).


