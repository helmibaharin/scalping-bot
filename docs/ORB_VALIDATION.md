# ORB extension verification

Validated 2 November 2026, Malaysia time. This is engineering verification, not profitability or live-readiness evidence.

## Delivered build

EA: `MQL5/Experts/ScalpingBot.ex5`

SHA256: `4AE4A2850EB55E2C5BC85511EA4B943367FD126185AB84DDCF6923E5EC1A1A48`

The original two-strategy ZIP and its 24-run validation are preserved and belong to their earlier hash. Development matrix `20261101T154853` is also preserved separately; the final release evidence is **`artifacts/orb-v1/20261101T160555`**. Do not merge performance across these binaries.

## Verification results

| Check | Result |
|---|---|
| Native MetaEditor compile, EA and native fixture | 0 errors, 0 warnings |
| Native MQL production-function ORB fixture | 100 assertions, 0 failures |
| Original production rule/timezone/triangle adaptation | 243 assertions passed |
| Shared risk/execution adaptation, including ORB | 51 assertions passed |
| Profiles, ownership, source and protected-project checks | 40 checks passed |
| Metric arithmetic and separate ORB-mode attribution | 3 Python tests passed |
| Final current-binary market matrix | 20 completed runs, all reporting real ticks |
| Range freeze checks across ORB-enabled runs | 24 finalizations; no repeat within a NY day |
| Native entry ownership checks | 48 entry rows respected enabled strategy/mode |
| Existing protected project files | 219 unchanged by SHA256 |
| Existing 4H/Triangle detector/rules and NY time modules | 5 unchanged source files compared with original release ZIP |

Native fixture SHA256: `17396D57BF81168EFD63BF927FE6B8DA67EA6ECE20D48F092A88B73786417888`.

The native fixture includes production functions directly and runs only in Strategy Tester. Synthetic fixtures exercise valid BUY/SELL continuation, opposing-pullback CHoCH, both reversal directions, missing reversal structure, distinct CHoCH/BOS pivots, exact NY range/DST boundaries, previous-day/week calendars, non-native-boundary M1 aggregation, FVG Option B/association/age, liquidity sweep windows/attribution, reward-room policies, countertrend context and replay consumption. Mocked broker tests separately cover risk, netting, hedging, spread, freeze, partial/uncertain sends and duplicates. A passing synthetic path is not an observed market trade.

## Market scenarios and metrics

Period: **2026-08-03 00:00 through exclusive 2026-08-05 00:00 broker time**. Four symbols: EURUSD, XAUUSD, GBPUSD, USDJPY. Each ran 4H-only, Triangle-only, ORB continuation-only, ORB reversal-only and combined. This is a short engineering sample with no parameter optimization. Fixed broker UTC+3 is an explicit assumption for that August interval, not inferred historical truth. Simulation uses 10,000 USD deposit, 0.01 volume, 100 ms execution delay and the profile's zero estimated commission; broker-recorded fees are included when present.

[Full per-run and per-component results](../artifacts/orb-v1/20261101T160555/RESULTS.md) report trade counts, win rate, average realized R, profit factor, drawdown and period separately for Strategy 1, Strategy 2, ORB continuation, ORB false-breakout reversal and combined. [Detailed machine-readable results](../artifacts/orb-v1/20261101T160555/results.json) retain trade ledgers, spreads/slippage, rejections, source run IDs and limitations. Native HTML reports, CSVs, logs, [fixture receipt](../artifacts/orb-v1/20261101T160555/native-unit-results.json) and [verification receipt](../artifacts/orb-v1/20261101T160555/verification.json) are alongside them.

Native combined-account results (all three strategies enabled):

| Symbol | Native closed trades | Net USD | Native PF | Equity DD % |
|---|---:|---:|---:|---:|
| EURUSD | 5 | -0.84 | 0.5882 | 0.035 |
| XAUUSD | 7 | 16.65 | 1.7806 | 0.266 |
| GBPUSD | 6 | -1.11 | 0.4365 | 0.024 |
| USDJPY | 6 | 2.55 | 2.0039 | 0.038 |

**Both ORB modes had zero market trades throughout this sample.** Their win rates, average R and profit factors are unavailable, rather than zero performance estimates. The observed combined trades came from the original strategies. ORB range, breakout, retest, failure, FVG, structure-wait and expiration paths were observed; synthetic native fixtures establish the intended confirmation paths mechanically. Longer independent tests are required to observe and assess actual ORB entries. Thresholds were not relaxed to manufacture trades.

Two ledger positions across the matrix lack a final exit callback row, including one in EURUSD combined. Native tester counts include forced end-of-test exits; component ledger metrics include only provably closed positions and list unmatched positions explicitly. Native equity DD is distinct from per-component realized cash DD. PF is unavailable without losses in ledger metrics even when MT5 displays zero. No selected tick-warning phrases were detected, which is not proof of perfect history.

## Scope and limitations

The final EX5 was used for all 20 market scenarios. The original 4H/Triangle signal rules remain unchanged; shared integration adds ORB routing/ownership, planner limits, fill management, recovery, order tags and diagnostics. The legacy 12-run preparation explicitly disables ORB; the new 21-scenario preparation covers all three strategies. Live execution, fault injection against a broker, longer out-of-sample ORB profitability and manual visual chart review were not established. Netting and broker failures are covered by mocked API tests rather than live fault-inducing orders. No CRG, ML, external database, live deployment or CapitalGuard change was made.

The first native launch failed because the freshly recreated portable tester lacked a selected account; a restricted-network attempt could not synchronize. A temporary local encrypted demo-account record and authorized network access allowed isolated testing. No live-chart EA was enabled in that portable terminal. Runtime account records and downloaded caches are excluded from the release and removed after evidence preservation. Earlier failed launches and development results remain separate from final successful receipts.

## Demo review

Follow the [demo installation checklist](INSTALLATION.md) with `InpSignalOnly=true` and `InpAllowRealAccount=false`. Verify broker mapping and symbol point distances, observe NY 09:45 finalization, inspect sequential structure/FVG/external-level reasons, and test restart/duplicate behavior. Evaluate modes separately before enabling combined demo execution. Preserve a longer chronological sample with realistic costs and sufficient actual ORB trades before drawing performance conclusions.

See [ORB rules](ORB.md), [all ORB inputs](ORB_INPUTS.md), and [changed files](ORB_CHANGES.md). The ORB release package is `artifacts/ScalpingBot-v1.0-ORB.zip`; its current source/binary hashes are recorded in `artifacts/orb-release-manifest.json`.
