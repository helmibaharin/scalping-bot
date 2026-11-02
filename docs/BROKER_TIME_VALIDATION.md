# Broker-time validation - 2 November 2026

## Result

All six final native Strategy Tester scenarios passed their evidence gates. The EA, BrokerTimeTests and ORBTests compiled with **0 errors and 0 warnings**. Current EA SHA-256: `7dbe635151884517cc9722a09d88a184734dfa9d52ba58740eb841e88b75214e`. Exact inputs, binary hashes, logs and native reports are retained under `artifacts/broker-time-v1/20261102T015120`. Source hashes are frozen in `artifacts/broker-time-v1/final-build.json`.

| Check | Result |
|---|---|
| Native broker mapping / counters | 69 passed |
| Native existing ORB | 100 passed |
| Existing C# production rule adaptations | 243 passed |
| Existing C# production risk/execution adaptations | 78 passed |
| Existing offline Python reports | 18 passed |
| Preserved source/profile/parent files | 260 files, including all 11 presets and 219 protected parent files |
| Existing input defaults | All 278 unchanged; only the new empty UTC-table input added |

## Native scenarios

| Scenario | Checks / trades | Net USD | Account equity DD % |
|---|---:|---:|---:|
| clock-unit | 69 | N/A | N/A |
| orb-unit | 100 | N/A | N/A |
| preserved-eurusd | 5.0 | -0.84 | 0.035 |
| preserved-xauusd | 7.0 | 16.65 | 0.266 |
| table-equivalent-xauusd | 7.0 | 16.65 | 0.266 |
| unverified-xauusd | 0.0 | 0.0 | 0.0 |

The preserved EURUSD and XAUUSD runs exactly reproduce their previous trade counts, net results, PF and drawdown. XAUUSD explicit-table mode reproduces the fixed-mode run exactly: seven trades, +16.65 USD, PF 1.7806, 0.266% equity drawdown. These use identical **synthetic UTC+3 settings from the frozen prior baseline**, not a newly asserted timezone for MetaQuotes-Demo. The unverified XAUUSD run has zero trades and explicitly logs BROKER_MAPPING_NOT_VERIFIED.

Native clock tests exercise the actual production parser/converters, ORB session conversion, checked history counter and panel formatting. Mutable fixture inputs are injected through preprocessor names; no duplicate timezone implementation is used. Tests cover fixed positive/negative/fractional offsets; inclusive/exclusive coverage; invalid settings; exact EU/US/NY transitions; pre-2007 NY rules; EU historical scope; three years of US/EU mismatch weeks; custom midnight-UTC transitions; multiple offset regimes; half-hour folds; ambiguous/missing hours; malformed tables; known zero and unknown counts; and invalid future history intervals.

C# adaptations run the existing strategy/risk code with mocked broker APIs. In the legacy rule adapter, the new table-parser dependency is stubbed and custom mode throws if called; table validation/conversion coverage is supplied by the separate native fixture. The risk adapter retains mocked history availability. These tests are not substitutes for native compilation or actual broker validation.

## Findings and retained attempts

The initial fresh portable terminal could not start tests without a cached demo-account record. Those failed-start logs and the initial-environment-attempt.json are retained. The disposable tester then reused the existing local demo-account cache; the active terminal and its settings were not changed.

The first native fixture passed the mapping checks but exposed a bad test assumption: MT5 can accept a future history-selection interval as an empty selection instead of returning failure. The checked counter now validates a future interval explicitly and returns unknown, rather than letting that invalid request look like a known zero. The initial failed native assertion and report are retained; only the final 69/0 run counts as passing evidence.

## Preserved behavior and remaining limits

All strategy signal/exit modules, the shared trade executor, existing preset bytes and protected parent/CapitalGuard files match the pre-task snapshot. Risk thresholds, strategy ownership/independence and unknown-history entry blocking are retained. The counter history query is conservatively widened to cover permitted offsets, and failure diagnostics are made explicit. Shared policy signatures remain identical for existing modes; UTC-table mode includes its schedule in the signature.

The current local terminal log identifies MetaQuotes-Demo, but its historical offset policy remains **unverified**. The original user test input/journal was not available, so the former generic warning alone cannot distinguish an unverified flag from a genuine fold or missing coverage. All supplied presets remain unverified. Actual broker configuration still requires historical broker evidence, including exact UTC transition instants.

The market runs are short regression tests, not profitability research. Exact synthetic table equivalence does not certify real historical timestamps, missing market data or any broker contract. Repeated server wall times remain intentionally blocked because an ordinary MT5 timestamp cannot uniquely identify the UTC occurrence. The existing 4H skip on three/five-hour NY DST Sundays is preserved.

This repository EX5 has not been installed into the active terminal. Historical release ZIPs remain unchanged and contain their respective older builds. Use the current MQL5/Experts/ScalpingBot.ex5 and matching source/includes for this update. Temporary tester account/runtime files are removed after retaining the evidence.

[Configuration, exact root causes, diagnostic meanings, historical DST references and manual installation](BROKER_TIME.md).
