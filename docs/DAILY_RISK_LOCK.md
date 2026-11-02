# Optional daily risk lock

`InpEnableDailyRiskLock` controls the shared **daily baseline / daily-loss entry gate** for all five strategies. It defaults to `true`, preserving existing presets and behavior. Setting it to `false` explicitly allows new entries while the saved daily lock is set, including on first attachment before a known midnight equity baseline exists.

This opt-out disables the daily-loss limit as well as the midnight baseline wait. `InpDailyLossPercent` remains stored and validated, but does not block entries while the switch is false. Leave its numeric value valid; use the switch rather than setting the percentage to zero. Per-strategy daily entry counts/cooldowns remain active.

The all-five XAUUSD demo execution preset now explicitly sets this switch to `false`. All eleven other presets retain their bytes and therefore inherit the default `true`. No broker mapping, signal, target, stop, magic, volume, risk percentage or execution switch was changed by this update.

## Apply to the current chart

1. Compile or copy the updated `MQL5/Experts/ScalpingBot.ex5` to the intended terminal and reload the EA.
2. Preserve the chart's existing inputs, especially the broker-time configuration. Set **`InpEnableDailyRiskLock=false`**.
3. Confirm `DAILY_RISK_POLICY ... DISABLED_BY_INPUT` at initialization and `DAILY RISK LOCK DISABLED` on the panel.

No ResetToken increase is required to disable an existing daily wait when all other shared account settings match. Do not reload an older saved input file that overrides this switch. The all-five repository preset still has unverified broker-time defaults; loading it is not a substitute for retaining the chart's separately configured mapping. This update does not deploy into or change the active terminal automatically.

## Other controls remain active

Maximum drawdown and emergency latches, unresolved order intent, per-trade monetary risk, combined open risk, broker stops/lot/margin/spread/permission constraints, real-account denial, data/time verification, startup replay retirement, strategy-specific entry caps/cooldowns, and the internal S5 position pool are unchanged. Disabling the daily gate makes the EA eligible to evaluate fresh entries; it does not force an order or remove unrelated blockers. The opt-out applies to both New York and broker risk-day modes.

## Saved account state and concurrent charts

Daily equity and lock state continue to be tracked internally for audit and possible future re-enabling. The panel and entry gate clearly distinguish disabled enforcement from this stored state.

With enforcement enabled, the original risk-policy signature is retained. Disabling it uses a distinct signature. The explicit true-to-false change migrates an otherwise identical existing policy without resetting its peak equity, emergency latch, pending intent or reset token. Disabling cannot migrate unrelated changed risk settings.

Use identical shared risk settings on concurrent Scalping Bot charts. An older/enabled chart cannot silently overwrite a disabled account policy. Re-enabling on an existing disabled policy requires an explicit increased ResetToken while the account is flat, has no pending orders and has no unresolved intent; it restores the baseline wait. Ordinary reset behavior then applies. This does not change CapitalGuard's independent risk controls.

## Verification

`tests/test_risk_execution.ps1` exercises actual production planning/execution functions through the established C# adapter. It checks the daily gate on/off for all seven internal strategy/method routes, plus retained emergency, drawdown latch, pending intent, per-trade/open-risk limits and strategy entry caps. `tests/DailyRiskTests.mq5` uses actual production persistence/update functions and isolated tester globals to check both risk-day modes, migration, re-enable conditions and preserved latches/high-water marks without sending orders.

The source/profile snapshot, compiled binary hashes, compiler logs, native tester receipt and final validation are retained under `artifacts/daily-lock-v1/`. The existing rule/report tests and protected-file verifier cover unchanged strategy modules, prior input defaults, preset settings and parent/CapitalGuard files.
