# SMT extension changed files

Compared with the preserved ORB release ZIP. Existing strategy/time modules and original four profiles match the 13-file SMT baseline; all 124 existing input defaults remain unchanged. CapitalGuard/parent-project integrity is separately verified against 219 protected files.

New production modules: SMTTypes, SMTLocations, SMTEngine, SMTContext and SmartMoneyTrap. Shared changes route Strategy 4 through ownership, replay, risk and execution, with an SMT-only dynamic TP and actual-fill RR path. Strategies 1-3 keep their signal rules and target methodology.

| Status | File |
|---|---|
| CHANGED | `MQL5/Experts/ScalpingBot.compile.log` |
| CHANGED | `MQL5/Experts/ScalpingBot.ex5` |
| CHANGED | `MQL5/Experts/ScalpingBot.mq5` |
| CHANGED | `MQL5/Include/ScalpingBot/Config.mqh` |
| CHANGED | `MQL5/Include/ScalpingBot/Diagnostics.mqh` |
| CHANGED | `MQL5/Include/ScalpingBot/PositionManager.mqh` |
| CHANGED | `MQL5/Include/ScalpingBot/RiskManager.mqh` |
| NEW | `MQL5/Include/ScalpingBot/SmartMoneyTrap.mqh` |
| NEW | `MQL5/Include/ScalpingBot/SMTContext.mqh` |
| NEW | `MQL5/Include/ScalpingBot/SMTEngine.mqh` |
| NEW | `MQL5/Include/ScalpingBot/SMTLocations.mqh` |
| NEW | `MQL5/Include/ScalpingBot/SMTTypes.mqh` |
| CHANGED | `MQL5/Include/ScalpingBot/StatePersistence.mqh` |
| CHANGED | `MQL5/Include/ScalpingBot/StrategyInterface.mqh` |
| CHANGED | `MQL5/Include/ScalpingBot/TradeExecutor.mqh` |
| NEW | `profiles/smt-mtf-d1-h1-m15-m5-demo.set` |
| NEW | `profiles/smt-scalp-m15-m1-demo.set` |
| CHANGED | `docs/ARCHITECTURE.md` |
| CHANGED | `docs/KNOWN_LIMITATIONS.md` |
| NEW | `docs/SMT.md` |
| NEW | `docs/SMT_INPUTS.md` |
| NEW | `docs/SMT_INSTALLATION.md` |
| NEW | `docs/SMT_VALIDATION.md` |
| CHANGED | `docs/STRATEGY.md` |
| CHANGED | `docs/TESTING.md` |
| CHANGED | `docs/VALIDATION.md` |
| CHANGED | `tests/analyze_backtests.py` |
| CHANGED | `tests/ORBTests.compile.log` |
| CHANGED | `tests/ORBTests.ex5` |
| NEW | `tests/package_smt.ps1` |
| NEW | `tests/prepare_smt_backtests.ps1` |
| CHANGED | `tests/run_backtests.ps1` |
| NEW | `tests/SMTTests.compile.log` |
| NEW | `tests/SMTTests.ex5` |
| NEW | `tests/SMTTests.mq5` |
| CHANGED | `tests/test_analyzer.py` |
| CHANGED | `tests/test_risk_execution.ps1` |
| CHANGED | `tests/test_rules.ps1` |
| CHANGED | `tests/verify_project.ps1` |
| NEW | `tests/verify_smt_evidence.ps1` |
| CHANGED | `README.md` |
| NEW | `docs/SMT_CHANGES.md` (this inventory) |

Final market/native evidence is under artifacts/smt-v1/20261101T171913. Release manifests and ZIPs are generated artifacts. Original packages and their old-binary results remain preserved.
