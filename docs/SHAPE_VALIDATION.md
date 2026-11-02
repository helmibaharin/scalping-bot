# Shape Pattern validation ? 2026-11-02

Final EA SHA256: `71D00DA7E379FDB594835120A4FE7D08902CB2E2EAA1CDBCFD58789AD2DE16F1`.

MetaEditor compiled the production EA and Shape/ORB/SMT/lifecycle native fixtures with **0 errors, 0 warnings**. No installation into the active trading terminal was performed. Source/build fingerprints and all nineteen binary-matched tester receipts are preserved under `artifacts/shape-v1/20261101T183458/` and `artifacts/shape-v1/final-build.json`.

## Automated checks

| Check | Actual result |
|---|---|
| Production rule/time/legacy Triangle replay tests | 243 passing assertions; terminal APIs mocked through C# adaptation |
| Production shared risk/execution tests | 63 passing assertions; broker APIs mocked; includes fixed Triangle versus dynamic Shape target policies |
| Offline legacy metrics + lifecycle report tests | 14 passing Python tests; fees, partial fills/closes, duplicate restart records, rejected signals, netting exclusion and original requested-risk R |
| Native Shape tests | 124 passing assertions; all 11 subtypes through confirmed-pivot/OHLC detection, flag-pole rejection, continuation, both reversal directions with/without opposing structure, distinct later BOS, invalidation, age, targets, dedup, complete preset validation and durable attribution |
| Native ORB regression fixture | 100 passing assertions |
| Native SMT MTF / M1 fixtures | 107 passing assertions each |
| Native actual-broker lifecycle fixture | 14 passing assertions; tester entry, two partial closes, actual OnTradeTransaction mapping, comment-independent ownership, journal reopen/history replay idempotency |
| Project and migration gate | 2462 passing checks; all 219 protected parent files and 16 original decision/utility modules unchanged; all historical profile values preserved |
| Final tester matrix | 19/19 verified: 5 native fixtures + 14 market scenarios, exact inputs and binary hashes preserved |

Native fixtures exercise actual compiled production decision functions; the lifecycle fixture uses synthetic tester-only orders. They are not strategy market performance. Raw assertion logs are retained, including exact inputs and fixture binary hashes.

## Market observations and reports

[Complete native matrix](../artifacts/shape-v1/20261101T183458/RESULTS.md) and [EURUSD Shape pattern/method report](../artifacts/shape-v1/20261101T183458/reports/eurusd-shape-both/performance.md).

All market samples cover 2026-08-03 through the exclusive 2026-08-05 boundary on EURUSD/XAUUSD real ticks, $10,000 simulated deposit, 0.01 configured strategy lot size and 100 ms modeled execution delay. Broker UTC+3 is an explicit August engineering assumption, not live broker verification. Configured commission estimate and observed demo fees were zero; these samples therefore do not validate realistic commission drag. Spread is the actual historical quote spread, not an invented fixed value.

The preserved-profile regressions match the prior SMT release's native results: EURUSD 5 trades, net -$0.84, account equity DD 0.035%; XAUUSD 7 trades, net $16.65, account equity DD 0.266%. EURUSD has one tester-end forced exit absent from the EA callback ledger: the lifecycle report correctly lists 4 complete positions and 1 unmatched rather than fabricating the missing exit. XAUUSD has 7 complete and 0 unmatched.

New Shape-only research: EURUSD both-method and continuation-only runs each produced the **same one descending-triangle continuation position**, net -$0.25. These are separate repeated simulations, not two independent trades. Its original requested-risk realized R is approximately -0.7143, including the configured deviation allowance in the original risk denominator. Reversal-only EURUSD and all Shape-only XAUUSD modes had zero trades. Both combined-mode Shape reports preserve separate strategy identities; their native account totals also include other enabled strategies.

All four SMT-only market runs had zero trades. No market win-rate, PF or realized R is inferred for empty strategies/families/methods. Native tester zero-trade PF may display 0; the lifecycle reports correctly mark it unavailable. Every family, all eleven subtypes, both methods and family+method combinations have explicit report rows, including zero-observation rows.

Each scenario has CSV/JSON/Markdown lifecycle reports under `reports/<scenario>/`. Realized drawdown there is **closed-position reconstructed net cash**, not account floating-equity drawdown; the native matrix separately reports account equity DD. Partial fills retain the original requested monetary risk denominator once per signal, including requested-but-unfilled volume. Fees are included in actual net P&L. Reports from independent tester runs must not be combined by ticket because MT5 can reuse test ticket namespaces.

## Limits and next validation

The market sample does **not** validate natural reversal executions or all eleven subtypes. Positive reversal and less-common family paths were demonstrated in deterministic native fixtures, not claimed as observed market winners. Longer chronological real-tick tests and demo forward observation remain required. There is no profitability or production-readiness claim.

Formation detection is bounded to eight recent confirmed pivot endpoints and the configured lookback. It intentionally misses patterns outside those deterministic limits. Reversal targets are confirmed structural support/resistance, equal levels and pattern/neckline references; they do not inherit SMT's stronger zone taxonomy. A nearer low-RR obstacle blocks a farther target. Neutral optional H1 context is allowed, established countertrend blocks, and required missing context invalidates the candidate.

Temporary execution blocks retire the current confirmation under the no-chase policy. Reversal CHoCH/BOS rules are deliberately strict: after CHoCH, the BOS uses a newly formed and confirmed distinct pivot. Two-sided OHLC sweeps are rejected because their intrabar order is unknown. These restrictions can produce long zero-trade periods; they are not evidence of future safety or profitability.

Attribution requires retaining the live lifecycle journal. Pre-journal historic trades cannot be assigned invented detailed metadata. Torn journals, unknown active Shape metadata and ambiguous request-to-order recovery fail closed. Native partial closes were tested against the broker simulator; partial fills are covered by offline multi-deal fixtures because this short broker sample did not naturally generate a partial fill. Crash-at-every-instruction fault injection, non-demo execution and broad instrument/broker coverage were not performed.

Use the [rules, preset migration, manual installation and longer Strategy Tester plan](SHAPE_PATTERN.md) before demo execution. Existing six presets explicitly retain legacy Triangle behavior; `profiles/shape-m15-m5-demo.set` enables the new engine with signal-only and real-account blocking defaults.
