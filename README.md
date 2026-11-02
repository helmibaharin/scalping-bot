# ScalpingBot V1.0

A standalone MetaTrader 5 Expert Advisor with five independently configurable strategies:

| Strategy | Configuration switch | Rules |
|---|---|---|
| 1. 4H Breakout | `InpEnable4HBreakout` | [4H rules](docs/STRATEGY.md) |
| 2. Shape Pattern / legacy Triangle | `InpEnableTriangleMethod` | [Shape patterns](docs/SHAPE_PATTERN.md) |
| 3. Opening Range Breakout | `InpEnableORBStrategy` | [ORB](docs/ORB.md) |
| 4. Smart Money Trap | `InpEnableSMTStrategy` | [SMT](docs/SMT.md) |
| 5. Volume Profile | `InpEnableVolumeProfile` | [Volume Profile](docs/VOLUME_PROFILE.md) |

The EA has no CapitalGuard dependency. This repository contains the ScalpingBot project itself; it can also live as `trading-robot/scalping-bot` beside another independent EA. No profitability or live-readiness claim is made.

## Profiles and execution

The [all-five XAUUSD demo execution preset](profiles/all-five-xauusd-mtf-demo-execution.set) enables all five strategies, the new Shape engine, SMT MTF and all three Volume Profile methods. Its explicit settings include:

```ini
InpSignalOnly=false
InpSMTSignalOnly=false
InpEnableDailyRiskLock=false
InpAllowRealAccount=false
InpShapeSetupBasedExits=true
InpSMTSetupBasedExits=true
```

The daily opt-out disables both the first-midnight baseline wait and daily-loss entry limit. Emergency, maximum drawdown, per-trade/open-risk limits, broker constraints, strategy entry caps and cooldowns remain active. The source default keeps the daily lock enabled; the other eleven profiles retain observation/signal-only settings. [Daily lock behavior and migration](docs/DAILY_RISK_LOCK.md).

Shape and SMT in this preset use their setup-based SL/TP distances and accept any positive estimated net reward, with risk-based sizing and money-risk protections retained. Their fixed point stop ceilings and minimum RR thresholds are overridden only in this optional mode. S1, ORB, Volume Profile and legacy Triangle keep their existing rules. Source defaults leave both new modes off. [Inputs, exact behaviour, restart policy and validation](docs/SETUP_BASED_EXITS.md).

Every supplied profile requires externally verified broker-time settings before decisions are permitted. `InpBrokerTimeVerified=true` is an explicit acknowledgement, not automatic timezone detection. Current server-clock observations do not establish historical DST policy. Built-in fixed/EU/US rules and an explicit UTC transition table are supported. [Broker-time configuration and diagnostics](docs/BROKER_TIME.md).

On a hedging account, strategies can hold independent positions under the shared account risk budget. The three Volume Profile methods share one S5 slot per symbol. Netting conflicts are blocked to avoid merging or reversing another position. For same-symbol S1-5 operation, use one controller chart with the desired strategies enabled.

## Installation and build

Use the current [compiled EA](MQL5/Experts/ScalpingBot.ex5) in your terminal's `MQL5/Experts` directory. Reload it and select the required profile in Inputs. To compile manually, copy the matching `MQL5/Include/ScalpingBot` sources as well. Repository builds do not automatically replace a running terminal EA. [Installation](docs/INSTALLATION.md).

Run commands from this repository root (or first `cd scalping-bot` when working in the parent trading-robot workspace):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\compile.ps1 -MetaEditor 'C:\Program Files\MetaTrader 5\metaeditor64.exe'
```

Set `-MetaEditor` to your actual installation. Compilation requires a fresh EX5 and zero errors/warnings. Native fixture sources under `tests/` can be compiled with `-Source .\tests\DailyRiskTests.mq5`, then run only in an isolated Strategy Tester. Fixture EX5 files are generated locally and are not committed.

## Offline checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify_project.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\test_rules.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\test_risk_execution.ps1
python -m unittest discover -s tests -p 'test_*.py'
```

Windows PowerShell runs the C# adaptations of production rules and risk/execution with mocked terminal APIs. Python 3.12 runs the offline reporting tests without extra packages. These checks do not send orders. GitHub Actions runs the standalone project checks, rule/risk assertions and Python tests; it does not run MetaEditor or connect to a trading account.

The source-workspace preservation verifier is used when its local snapshots are present. A standalone clone automatically uses `tests/verify_repository.ps1`, which checks inputs, preset modes, magic uniqueness and include resolution without requiring the parent workspace. Add `-VerifyReleaseSnapshot` to that script to check the currently distributed EX5/source against the retained build fingerprint.

## Validation and local research

The latest Shape/SMT setup-exit change compiled with zero errors/warnings and passed five native XAUUSD runs: 48 new mode/restart/fill assertions, 124 existing Shape assertions and 107 existing SMT assertions. The 117 risk/execution assertions, 243 rule assertions and 18 Python tests also passed. [Current results and limitations](docs/SETUP_BASED_EXITS.md). Earlier [historical range-recovery results](docs/HISTORICAL_RANGE_RECOVERY.md) and [daily-lock results](artifacts/daily-lock-v1/VALIDATION.md) describe their specific builds. These are engineering checks, not proof of a trading edge.

Other validation records describe their specific historical builds: [broker mapping](docs/BROKER_TIME_VALIDATION.md), [Volume Profile](docs/VOLUME_PROFILE_VALIDATION.md), [Shape](docs/SHAPE_VALIDATION.md), and [SMT](docs/SMT_VALIDATION.md). Their market samples are short; mixed/generated tick periods and unverified assumptions are disclosed in those reports.

Native tester preparation, replay and release-packaging helpers retain the original workstation paths, account/cache parameters and local historical snapshot requirements. Configure those parameters for your installation. The historical preservation/replay/package helpers are optional local research tools; they require artifacts that are deliberately excluded from this standalone source import. [Local research workflow](docs/REPOSITORY.md).

## Repository contents

- `MQL5/`: EA source, shared modules and the current compiled EA.
- `profiles/`: twelve presets with real-account trading blocked.
- `tests/`: production-function adapters, native fixtures, offline reporting and local tester/research tools.
- `docs/`: strategy rules, inputs, installation, validation and limitations.
- `artifacts/setup-exits-v1/`: compact current validation and build-fingerprint records only.
- `artifacts/range-recovery-v1/`: compact validation records for the earlier range-recovery change.
- `artifacts/daily-lock-v1/`: compact validation records for the earlier daily-lock change.

Terminal executables, credentials, account/session files, downloaded market data, raw account/trade logs, portable terminal caches, historical release ZIPs and bulky reports are excluded from Git. Generate local runtime/research outputs under `artifacts/`.
