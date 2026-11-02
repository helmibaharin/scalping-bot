# Setup-based exits: Shape and SMT

Two optional inputs enable structural targets without imposing a minimum reward-to-risk ratio or a fixed point-distance stop ceiling:

```ini
InpShapeSetupBasedExits=true
InpSMTSetupBasedExits=true
```

Both source defaults are **false**, preserving the existing behaviour for older profiles. Both are **true** in `profiles/all-five-xauusd-mtf-demo-execution.set`. To activate them, load the rebuilt EX5 and reload that preset, or set the two new inputs explicitly. Compiling in the project does not update the running terminal automatically.

## Behaviour

For the **new Shape engine**, continuation targets use the existing pattern measured move; reversal targets use the nearest available opposing structural level with the existing buffer. All eleven patterns, including the new engine's three triangle continuations, use this structural path when enabled. Stops stay at the existing retest/sweep invalidation level. The separate legacy Triangle strategy is unaffected.

For **SMT**, the existing sweep-based stop and nearest eligible opposing supply/demand target remain unchanged. Zone validity, freshness, momentum, BOS, trend, CHoCH, FVG, confirmation and extension checks still apply. A nearer obstruction is not skipped to manufacture a larger reward.

The EA calculates the resulting RR from the chosen prices. Positive ratios below 1R are accepted when estimated reward remains positive after the configured commission and adverse-entry allowance. This measures a setup's available target distance; it is not a trained price predictor or a guarantee that price reaches the target.

In the enabled mode, the following old thresholds do not govern new entries for that strategy:

| Strategy | Overridden thresholds |
|---|---|
| New Shape engine | `InpTriangleMaxStopPoints`, `InpShapeContinuationMinRR`, `InpShapeReversalMinRREnabled` / `InpShapeReversalMinRR`; the fixed triangle continuation RR does not determine its TP |
| SMT | `InpSMTMaxStopPoints`, `InpSMTUseMinimumRR` / `InpSMTMinimumRR` |

The original inputs and their defaults are retained for switching the mode off. They should retain valid values even when overridden. S1, ORB and Volume Profile continue to use their own existing targets, RR rules and stop ceilings.

## Risk and execution

Stops must still be positive, on the correct side and at least one tick away; targets must be valid and profitable in the intended direction. Risk-based sizing uses the actual structural distance, broker lot step and configured risk budget. A wider stop therefore normally produces a smaller lot size. If the resulting size is below the broker minimum, the setup is rejected rather than rounded up. Fixed-volume users retain their fixed-volume choice and must still pass the money-risk cap.

The all-five preset retains risk-based sizing, 0.25% per-trade risk, 1% combined open risk, the 5% drawdown limit and its existing spread, margin, position, freshness, broker and strategy daily-entry safeguards. Its previous daily-risk-lock setting and broker timezone acknowledgement were not changed by this task. Positive net reward means positive under the **configured** costs; unconfigured broker charges are not inferred.

No target is extended to force a minimum RR, and no stop is tightened artificially to fit an old point ceiling. An absent/invalid target, stale confirmation, unprotected exposure, excessive risk, insufficient margin, disallowed volume or broker rejection can still prevent an order.

## Post-fill and restart handling

An opted-in request records `max_stop_points=0` in the existing durable journal field. Previous requests use positive ceilings. Only recorded Shape/SMT profiles can interpret zero as this mode; S1, ORB, S5 and legacy Triangle cannot acquire it accidentally. No journal schema change is required.

Position reconciliation reads that recorded marker, so it preserves the policy after a restart even if the new input is subsequently turned off. A new-engine triangle continuation cannot enter the old fixed-R TP repair path. Actual money-risk checks and positive net-reward checks remain active; invalid fills can still trigger a safety close. Missing required metadata halts new activity for review. Positions without the new marker retain their original reconciliation path.

Use this updated build to manage positions opened under the new policy. Older EX5 versions do not understand the mode and may enforce their old stop/RR restrictions on those positions.

Startup logs show `SETUP_EXIT_POLICY` for each strategy. Accepted plans log `SETUP_BASED_EXIT_PLAN` with entry, structural SL/TP, calculated RR, volume, estimated money risk and the journal marker. Existing `ENTRY_REJECT` diagnostics give the exact reason when a setup fails.

## Validation

The EA and native fixtures compiled with **0 errors and 0 warnings**. Automated results:

| Check | Result |
|---|---|
| Native setup-exit fixture | 48 assertions passed |
| Existing native Shape suite, modes off | 124 assertions passed |
| Existing native SMT suite, modes off | 107 assertions passed |
| Production risk/execution adaptation | 117 assertions passed |
| Existing rule adaptation | 243 assertions passed |
| Python reporting suite | 18 tests passed |

Five isolated XAUUSD runs used M1 OHLC simulation. Native fixtures ran `2026.08.03` through `2026.08.04` exclusive; two production signal-only comparisons ran `2026.08.03` through `2026.08.05` exclusive. Verified fixed UTC+3 was used **only as a synthetic test configuration**, not as evidence of MetaQuotes-Demo's historical mapping. Raw evidence is retained under the local timestamped `artifacts/setup-exits-v1/` directory; compact results and source/binary fingerprints are retained separately there.

The native fixture exercises all eleven Shape pattern targets, both directions, reversal targets, missing/wrong targets, sub-1R SMT geometry, positive net reward, journal policy identity, real tester orders, restart reload and post-fill safety checks. The actual Shape planner accepts a constructed XAUUSD setup with a **13.14** stop distance and a **2.00** target distance while staying within its monetary budget. Native SMT orders isolate its post-fill/restart path with a constructed 40.00 stop and 2.00 target; its unchanged context/confirmation rules are covered by the existing SMT suite. The production risk adapter tests the new SMT planning/cost path with terminal/context boundaries mocked.

Both native positions retained their targets after the journal was reloaded and the new switches were disabled. A deliberately excessive money-risk stop then triggered the existing emergency protection. Adapter tests also confirm that the modes cannot loosen S1/ORB/S5/legacy Triangle stop ceilings, and that minimum lot, money risk, permissions, costs and emergency checks still reject unsuitable plans.

The two-day production sample produced **no accepted entries**. The same Shape signal that was rejected by the old stop ceiling proceeded to structural-target validation in the enabled mode, then correctly failed with `SHAPE_NO_OPPOSING_TARGET`. This sample proves neither profitability nor that every confirmed signal becomes a trade. No live forward-trading or real-tick execution result is claimed. The running user terminal was not replaced or restarted.

The preservation audit confirms all 280 previous input defaults and all 280 prior values in the user's current all-five preset are unchanged. Only the two new opt-ins were added to that preset. Other eleven presets, S1/S3/S5 modules, Shape/SMT entry runtime modules, timezone mapping, persistence, execution, ledger and 219 protected parent-project files are unchanged. The Shape entry state function is unchanged; its geometry selectors are the only changes in that engine file.

Runtime changes: `Config.mqh`, new `SetupExitPolicy.mqh`, `ShapeEngine.mqh`, `SMTContext.mqh`, `RiskManager.mqh`, `PositionManager.mqh`, `ScalpingBot.mq5` and rebuilt EX5. Supporting changes cover the all-five preset, fixture/preparation/report scripts, risk adapter, preservation/repository verifiers, build receipts and this documentation.

## Reproduction

```powershell
./compile.ps1
./compile.ps1 -Source ./tests/SetupExitTests.mq5
./compile.ps1 -Source ./tests/ShapeTests.mq5
./compile.ps1 -Source ./tests/SMTTests.mq5
./tests/test_risk_execution.ps1
./tests/test_rules.ps1
python -m unittest discover -s tests -p 'test_*.py'
./tests/prepare_setup_exit_tests.ps1
./tests/run_backtests.ps1 -MatrixFile ./artifacts/setup-exits-v1/<timestamp>/matrix.json
python ./tests/report_setup_exits.py ./artifacts/setup-exits-v1/<timestamp>/matrix.json
./tests/verify_project.ps1
./tests/verify_repository.ps1 -VerifyReleaseSnapshot
```

Native preparation uses a separate portable demo tester and requires the workstation's existing MT5 installation/cache or explicit replacement paths. Fixture EAs refuse to initialize outside Strategy Tester.
