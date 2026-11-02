# Volume Profile validation - 2 November 2026

## Outcome

Implemented Strategy 5 within the existing independent Scalping Bot. No CapitalGuard files or existing preset bytes were changed. No installation into the active terminal was performed. All 28 isolated tester scenarios passed their engineering evidence gates; this is not live-trading approval.

## Build and deterministic evidence

MetaEditor compiled the EA and seven native fixture binaries with **0 errors and 0 warnings**. The EA SHA-256 is `BAAEBE45C0A48E36C4AD7332CC5B5AD94718CE2A08A5FEE7C404A0FD6684D42D`. `artifacts/volume-profile-v1/final-build.json` freezes source hashes, while `compilation.json` records all eight compiler results.

| Check | Passed | Scope |
|---|---:|---|
| Profile engine native | 21 | Allocation, boundaries, ties, contiguous VA, validity, determinism |
| VP method/integration native | 88 | Both directions, confirmations, strict wick-only rule, BOS, arbitration, sessions/cache/consumption, accounting |
| VP actual broker lifecycle native | 18 | Real tester callbacks, partial close, full-close cooldown, counters, durable mapping/reload |
| Existing ORB native | 100 | Preserved production ORB functions |
| Existing SMT native | 107 + 107 | Both previous SMT profiles |
| Existing Shape native | 124 | Existing shape methods and durable setup rules |
| Existing lifecycle native | 14 | Existing actual-order/deal/position pipeline |
| C# production rules | 243 | Syntax adaptation with mocked terminal APIs |
| C# production risk/execution | 78 | Includes actual VP policy predicates and S1/S2/S5 hedge/netting acceptance cases |
| Offline Python tests | 18 | Actual-fill reporting, numeric day grouping, fee-adjusted VP PF, duplicates and partial fills |
| Preservation/profile gate | 277 | Seven existing presets, prior decision modules, all 219 protected parent files, four new complete/safe presets |

The standalone engine was first compiled and run before execution integration; its separate Phase B receipt is retained under `artifacts/volume-profile-v1/engine-tests`. The final eight native fixture scenarios contain 579 assertions in total.

## Native market samples

There are 20 market runs including one explicit repeat, plus eight native fixture scenarios. The distinct VP research windows are development Aug 3-7, validation Aug 10-14 and holdout Aug 17-21, 2026. End dates in matrix.json are exclusive. No parameters were tuned between these windows. Broker UTC+3 is an explicit historical tester assumption, not a verified setting for another broker.

| Scenario | Trades | Net USD | Native PF | Account equity DD % | Tick evidence |
|---|---:|---:|---:|---:|---|
| vp-all | 1 | -24.30 | 0.0000 | 0.356 | MIXED_REAL_AND_GENERATED |
| vp-all-warm-cache | 1 | -28.86 | 0.0000 | 0.290 | REAL_TICKS_AVAILABLE_FROM_START |
| vp-poc | 0 | 0.00 | 0.0000 | 0.000 | REAL_TICKS_AVAILABLE_FROM_START |
| vp-reversal | 1 | -28.86 | 0.0000 | 0.290 | REAL_TICKS_AVAILABLE_FROM_START |
| vp-breakout | 0 | 0.00 | 0.0000 | 0.000 | REAL_TICKS_AVAILABLE_FROM_START |
| vp-combined | 1 | -28.86 | 0.0000 | 0.290 | REAL_TICKS_AVAILABLE_FROM_START |
| vp-stress | 1 | -24.05 | 0.0000 | 0.242 | REAL_TICKS_AVAILABLE_FROM_START |
| vp-validation-all | 1 | -22.80 | 0.0000 | 0.228 | REAL_TICKS_AVAILABLE_FROM_START |
| vp-holdout-all | 1 | 34.26 | 0.0000 | 0.065 | REAL_TICKS_AVAILABLE_FROM_START |
| vp-holdout-poc | 1 | 34.26 | 0.0000 | 0.065 | REAL_TICKS_AVAILABLE_FROM_START |
| vp-holdout-reversal | 0 | 0.00 | 0.0000 | 0.000 | REAL_TICKS_AVAILABLE_FROM_START |
| vp-holdout-breakout | 0 | 0.00 | 0.0000 | 0.000 | REAL_TICKS_AVAILABLE_FROM_START |

The first cold-history `vp-all` run reported real ticks starting August 7, so its earlier portion is mixed/generated. It is retained for audit. After synchronization, the identical-input `vp-all-warm-cache` repeat reported real ticks available from August 3 and matched the reversal-only and all-five-strategy sample at -28.86 USD. Compare warm-history runs for the development-method comparison. Model 4 does not itself certify every tick; raw history warnings and start dates remain in verification.json.

Development and validation each had one completed losing Method 2 reversal. Holdout had one completed winning Method 1 multiple-bullish-candles trade: planned price target 1.5R, actual net 1.4679 requested monetary R, net +34.26 USD. Method 3 had no completed market trades in these short windows; both-direction entry and invalidation behavior is covered synthetically, but market performance is unestablished. Zero-trade methods are not failures and are not evidence of an edge.

MT5 reports native PF as 0 for these one-sided samples, including the all-winning holdout. The VP offline report leaves PF unavailable when there are no losing net trades; it uses net position results including actual commission, swap and fees. Native equity drawdown differs from reconstructed realized-cash drawdown.

The stress case changes the configured commission allowance to 7 per round-trip lot and deviation to 20 points. It affects admissibility/sizing; this is not proof that the demo server charged that commission or that latency/slippage was faithfully modeled. A smaller stress loss is not an improvement claim. Use the target broker commission and adverse execution assumptions for a longer study.

Eight preserved S1-4 market runs were rerun with exact frozen input files from the prior Shape release. EURUSD combined matches the previous 5 trades, -0.84 net, PF 0.5882 and 0.035% equity drawdown; XAUUSD combined matches 7 trades, +16.65 net, PF 1.7806 and 0.266% drawdown. The original signal/structure modules and executor are also byte-preserved. One EURUSD forced tester-end exit lacks an EA close callback (four ledger-completed plus one unmatched); native tester totals include that exit and offline R metrics exclude it.

The combined all-five-strategy run exercises the scheduler under the shared risk policy, but its single trade does not demonstrate every cross-strategy position combination in historical prices. The deterministic production-policy tests cover hedged S1 BUY + S5 BUY, S2 SELL + S5 BUY, all three S5 slot owners, S5 + S1, netting rejection and shared risk limits.

## Limits and outstanding validation

- These are short engineering samples, not statistically meaningful strategy validation. No profit or live-readiness claim is made. Trends/ranges, volatile/quiet regimes, spread stress, realistic costs and longer out-of-sample history still need research.
- Profile quality uses broker M1/D1 reconciliation and the current weekly session API. It is not an independent historical holiday calendar or exchange-volume audit. Historical session exceptions retain their quality labels and raw coverage.
- Native fixtures reload cache, journal metadata and actual broker history, and query the real S5 active position/counter. They do not simulate every full-terminal crash, power loss, disk fault or reconnect with an open position. Full process-level restart/disconnection forward trials remain outstanding.
- First broker-day attachment waits for a known equity baseline. Unobserved open-position rollover or funding adjustments lock new entries for review. Existing charts must use one identical shared risk policy. ResetToken does not fabricate a baseline.
- Same-symbol S1-5 position independence is supported in one hedging controller. Multiple alternative same-symbol controller namespaces are not a validated deployment. Netting conflicts are blocked; they are not silently merged.
- All provided new presets are signal-only, real-account blocked and broker-time unverified. Symbol contract, tick size, lot step, commission, historical UTC/DST and actual execution require target-broker verification.
- ATR uses a documented simple mean of completed true ranges; optional proximity, expiry, extension, session-exception, fallback and context thresholds are implementation assumptions listed in VOLUME_PROFILE_INPUTS.md.

## Evidence and manual use

Detailed native tables and per-method/side/confirmation/day/session-quality CSV/JSON/Markdown reports are under `artifacts/volume-profile-v1/20261102T011704/RESULTS.md` and `reports/<scenario>/`. The matrix retains exact simulated inputs, raw logs, lifecycle/profile/signals CSV, native HTML/PNG and EX5 hashes. Overlapping scenario results must not be added together.

Use the four new `profiles/volume-profile-*.set` files, starting with the balanced VP-only preset. [Rules, architecture, CSV schema locations, risk migration and manual installation](VOLUME_PROFILE.md), [all new inputs](VOLUME_PROFILE_INPUTS.md), [changed files](VOLUME_PROFILE_CHANGES.md). The release ZIP is `artifacts/ScalpingBot-v1.0-VolumeProfile.zip`; its SHA/file manifest is checked before the temporary portable terminal cache is removed. Existing releases and all durable reports remain available.
