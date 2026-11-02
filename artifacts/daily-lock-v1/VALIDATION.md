# Daily risk switch validation - 2 November 2026

The EA and DailyRiskTests compile with **0 errors and 0 warnings**.

- 36 native production account-state assertions passed: broker/NY first attachment, opt-out without reset, distinct policy signatures, saved peak/emergency/intent preservation, repeat updates, blocked stale controllers, explicit re-enable, fresh disabled state, maximum drawdown, emergency input, and rejection of unrelated risk-policy changes.
- 98 C# assertions against adapted production planning/execution passed, including all seven internal routes with the daily gate on/off and retained emergency, intent, risk budgets and entry caps. Broker APIs are mocked.
- 243 existing rule assertions and 18 Python reporting tests passed.
- Preservation passed for 263 files, including all 219 protected parent files. All 279 prior input defaults are unchanged. Existing strategy modules and executor are byte-preserved. The all-five profile changed only by adding the daily opt-out and comment; its complete schema has 280 inputs.

The native fixture sent no orders and used a unique tester-only global-variable prefix. The active EA and terminal settings were not changed. This update is not yet installed into the running chart. It makes valid fresh entries eligible without daily-baseline/daily-loss enforcement; other guards and strategy conditions still apply.

Current EA SHA-256: `585384de920d9ac3b03ea41938ee1bd5197bf79db1d2bf9ccc01d4f8165ae48d`.

Exact simulated inputs, logs, native HTML, fixture binary hash and receipt are in `20261102T023406/`. Current source hashes are in `final-build.json`. Existing historical releases remain unchanged.

[Switch behavior, applying it, migration and remaining controls](../../docs/DAILY_RISK_LOCK.md).
