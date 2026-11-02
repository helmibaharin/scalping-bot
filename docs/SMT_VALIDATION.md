# SMT implementation and verification

Validated 2 November 2026, Asia/Kuala_Lumpur. SMT is integrated into the existing Scalping Bot; it was not deployed to the running MT5 terminal. This is engineering evidence, not profitability or production-readiness evidence.

## Audit and delivered build

Strategy 1 (4H), Strategy 2 (Triangle) and Strategy 3 (ORB) already have real implementations and earlier native receipts. The original ORB market sample had zero ORB trades; its successful synthetic tests did not establish market profitability. Existing risk, persistence, execution, time conversion and diagnostics were reused.

The delivered EA hash is:

`E7F7D99DE465A66250DC5978CE9377E78DDA7B4C724061873A57EBC758774090`

Current evidence: `artifacts/smt-v1/20261101T171913/`. Earlier SMT development matrices belong to their recorded earlier builds and remain separate. Original two-strategy and ORB release ZIPs are preserved. Current package: `artifacts/ScalpingBot-v1.0-SMT.zip`, with matching source/binary hashes in `artifacts/smt-release-manifest.json`.

All nine Strategy 1–3 rule/time modules and four original demo profiles match the pre-SMT snapshot. All 219 protected parent-project source/config/doc/test files remain unchanged. CapitalGuard and its ML files were not edited.

## Results

| Check | Result |
|---|---|
| Native MetaEditor: production EA, SMT fixture, ORB fixture | 0 errors, 0 warnings |
| Native SMT fixture, MTF profile | 107 checks, 0 failures |
| Native SMT fixture, SCALP profile | 107 checks, 0 failures |
| Native ORB regression fixture | 100 checks, 0 failures |
| Original rule/timezone/triangle adaptation | 243 assertions passed |
| Shared risk/execution adaptation including dynamic SMT | 60 assertions passed |
| Profile, source, preserved-strategy and parent-project checks | 79 checks passed |
| Metric arithmetic, ORB and SMT attribution | 4 Python tests passed |
| Current-binary market/regression scenarios | 6 completed runs, all reporting real ticks |
| Native entry isolation checks | 12 entry rows respected enabled strategy/profile |

[Verification receipt](../artifacts/smt-v1/20261101T171913/verification.json) records individual fixture hashes, counts and the delivered EA hash. Native MQL fixtures include production functions and run only in Strategy Tester. They cover confirmed trend/pivots, all six location matching categories, actual momentum/freshness/BOS supply/demand publication, consolidation classes, three trap variations in both directions, post-trap confirmation, conditional CHoCH, distinct subsequent BOS, invalidation, expiration, dynamic target selection, stale/overlapping nearer obstacles, optional RR, sub-2R fill geometry, symbol rounding, replay consumption and cross-profile duplicate blocking. The same engine is exercised under both profile timeframe mappings.

Risk/execution adaptations mock terminal/broker APIs and run the production function bodies. They exercise fixed-volume monetary risk, spread/freeze, account caps, margin, permissions, netting/hedging, duplicates, partial/uncertain sends, SMT signal-only, optional minimum RR and pre-send rejection. They do not send live fault-inducing broker orders. Native market scenarios and synthetic fixtures are distinct evidence.

## Market samples

Sample: 2026-08-03 through **exclusive** 2026-08-05, broker time. EURUSD and XAUUSD each ran SMT MTF, SMT SCALP and a Strategies 1–3 combined regression with SMT disabled. An additional three native fixture runs make nine scenarios total. Fixed UTC+3 was an explicit historical broker-mapping assumption for this August sample. Tests used 10,000 USD, 0.01 fixed volume, 100 ms execution delay and the profile's zero estimated commission. Broker-recorded costs are included where present.

| Symbol / mode | Native closed trades | Net USD | Native PF | Equity DD % |
|---|---:|---:|---:|---:|
| EURUSD / Strategies 1–3 regression | 5 | -0.84 | 0.5882 | 0.035 |
| XAUUSD / Strategies 1–3 regression | 7 | 16.65 | 1.7806 | 0.266 |
| EURUSD / SMT MTF | 0 | 0 | Unavailable | 0 |
| XAUUSD / SMT MTF | 0 | 0 | Unavailable | 0 |
| EURUSD / SMT SCALP | 0 | 0 | Unavailable | 0 |
| XAUUSD / SMT SCALP | 0 | 0 | Unavailable | 0 |

**Neither SMT profile produced a market trade in this short sample.** SMT win rate, average realized R and PF are therefore unavailable. The platform's zero PF display is not a performance estimate. Synthetic valid entry/target paths passed, but live SMT fills and market profitability were not established. Thresholds and strict trend alignment were not relaxed to manufacture trades.

Actual market logs exercised trap detection, trend/neutral rejection, location filtering, CHoCH/BOS waits, sweep invalidation, extension limits and FVG rejection. MTF strict trend filtering prevented entries; SCALP produced qualified candidates but no completed execution path. A longer chronological sample with enough actual SMT entries is required.

[Full per-run results](../artifacts/smt-v1/20261101T171913/RESULTS.md) report all strategy/profile components separately, including trade counts, win rate, average R, PF, drawdown and sample period. [Machine-readable results](../artifacts/smt-v1/20261101T171913/results.json) retain trade attribution, rejections, spreads/slippage, unmatched positions and data caveats. Native HTML/PNG, per-run CSVs and logs are retained alongside the matrix, and final raw evidence is included in the SMT package.

The EURUSD combined regression has one unmatched final ledger position because the final exit callback is absent. Native tester totals include forced end-of-test exits; component metrics include only provably closed ledger positions. Per-component realized cash DD is distinct from native account equity DD. No selected tick-warning phrases were detected; this does not prove perfect history or realistic costs.

## Limitations and manual next steps

All six market runs match the delivered EX5. No live EA was attached and no live orders were sent by these isolated simulations. Temporary local demo-account records were used only for tester synchronization; runtime account/cache files are excluded from packages and removed after evidence preservation. The running terminal was left alone.

Remaining limitations include short samples, no actual SMT fills observed, no manual chart-appearance review, no live broker fault injection, operator-verified historical timezone policy, session metadata without a historical holiday calendar, and conservative blocking when HTF/M1 history is incomplete. Zone/trap definitions are explicit research algorithms, not proof of institutional activity. Changed profile parameters require separate evidence.

Follow [manual installation and recommended scenarios](SMT_INSTALLATION.md). Load the exact MTF or SCALP profile, verify broker mapping/symbol properties, keep both signal-only gates true and real-account permission false, observe each profile independently, then test longer chronological real-tick intervals with realistic costs and restarts. No real-money readiness is implied.

See [entry/SL/TP algorithms](SMT.md), [all thresholds](SMT_INPUTS.md), and [created/modified files](SMT_CHANGES.md).
