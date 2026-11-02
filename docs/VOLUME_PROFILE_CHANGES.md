# Strategy 5 changes

## Shared integration files

- `MQL5/Experts/ScalpingBot.mq5`
- `MQL5/Include/ScalpingBot/Config.mqh`
- `MQL5/Include/ScalpingBot/PositionManager.mqh`
- `MQL5/Include/ScalpingBot/RiskManager.mqh`
- `MQL5/Include/ScalpingBot/StatePersistence.mqh`
- `MQL5/Include/ScalpingBot/StrategyInterface.mqh`
- `MQL5/Include/ScalpingBot/TradeLedger.mqh`

These are routing, optional broker-day risk, method ownership/recovery, and fixed-R S5 integration changes. Existing S1-4 signal modules, TradeExecutor, timeframe conversion, structure calculations and existing preset bytes are unchanged. Shared broker-day mode is opt-in and required for S5. Old account-policy signatures are retained when it is off.

## New production modules and presets

- `MQL5/Include/ScalpingBot/VolumeProfileEngine.mqh`
- `MQL5/Include/ScalpingBot/VolumeProfileMethods.mqh`
- `MQL5/Include/ScalpingBot/VolumeProfilePolicy.mqh`
- `MQL5/Include/ScalpingBot/VolumeProfileRuntime.mqh`
- `MQL5/Include/ScalpingBot/VolumeProfileSessions.mqh`
- `profiles/volume-profile-breakout-only-demo.set`
- `profiles/volume-profile-poc-bounce-only-demo.set`
- `profiles/volume-profile-value-reversal-only-demo.set`
- `profiles/volume-profile-xauusd-m15-m5-balanced-demo.set`

## Tests, reporting and documentation

New native fixtures: VolumeProfileEngineTests, VolumeProfileTests and VolumeProfileLifecycleTests. New prepare_volume_profile_backtests.ps1, verify_volume_profile.py, report_volume_profile.py, report_volume_profile_matrix.py, test_volume_profile_reports.py and package_volume_profile.py. Shared test_risk_execution.ps1 adds production-policy execution coverage; report_lifecycle.py recognizes S5 IDs and metadata; verify_project.ps1 selects the current preservation gate. README and VOLUME_PROFILE* documentation describe the implementation, inputs, validation, installation and limitations.

The frozen before.json records the pre-task source/profile baseline; final-build.json binds the final source to the EX5. The 219 protected parent files are checked separately. Existing historical releases remain intact.
