# Historical broker time and dashboard counts

## Root causes

`SBFreshQuote` previously mapped every failed server-to-UTC conversion to `BROKER_MAPPING_UNVERIFIED_OR_AMBIGUOUS`. That concealed four different conditions: an unverified configuration, a date outside coverage, a missing server hour at a forward clock change, or two UTC candidates for a repeated server hour. Invalid configuration also lacked a specific startup explanation.

Source defaults and all 11 supplied presets deliberately have `InpBrokerTimeVerified=false`. Loading one without confirming the mapping therefore blocks decisions, including in Strategy Tester. `SB_FIXED` uses the winter offset all year; merely supplying different winter/summer numbers does not enable DST. The exact input set from the user's original warning was not available, so its particular failure cannot be attributed to a DST fold rather than the unverified flag. The new startup and runtime messages distinguish them.

The local terminal's November 2 log identifies its account server as **MetaQuotes-Demo**. MT5 uses the server associated with the account; manual server configuration is not required. This is evidence of the current account server, **not** evidence of its historical offset policy or the account selected for a particular earlier test. No broker timezone was inferred or enabled from that name.

The dashboard initialized counters to `-1` and printed that error sentinel directly. Mapping failures prevented history reconstruction, leaving `TRADES -1/1`. `SBTradesToday` also returns `-1` when history cannot be selected or a matching deal timestamp cannot be mapped uniquely. This did not represent a negative number of trades. Risk checks already rejected negative counts.

## Mapping contract and configuration

The conversion chain remains **broker candle/deal time -> UTC -> New York local time**. It uses the timestamp being evaluated, never the PC timezone, today's offset, or an offset inferred from tester clocks. The Strategy Tester intentionally makes `TimeGMT`, `TimeLocal` and server time equal; their difference cannot establish historical broker offsets. [MetaQuotes testing documentation](https://www.mql5.com/en/docs/runtime/testing), [TimeTradeServer](https://www.mql5.com/en/docs/dateandtime/timetradeserver).

| Input | Meaning |
|---|---|
| `InpBrokerTimeVerified` | Explicit operator confirmation of externally verified historical settings. Defaults false; no automatic bypass. |
| `InpBrokerDSTRule=0` / `SB_FIXED` | Fixed `InpBrokerWinterUTCMinutes` throughout coverage; summer value is ignored. |
| `InpBrokerDSTRule=1` / `SB_EU` | Last Sunday March to last Sunday October, transitions at 01:00 UTC; supported from 1996 onward. |
| `InpBrokerDSTRule=2` / `SB_US` | New York's US transition instants: 07:00 UTC in spring, 06:00 UTC in autumn. This does **not** mean every broker using US transition dates follows these exact instants. |
| `InpBrokerDSTRule=3` / `SB_UTC_TABLE` | Explicit UTC effective instants and broker offsets from `InpBrokerUTCTransitions`. Use when built-in calendars do not match the verified broker policy. |
| `InpBrokerWinterUTCMinutes`, `InpBrokerSummerUTCMinutes` | Signed minutes east of UTC, each within -840 to +840; arbitrary minute offsets are supported. |
| `InpBrokerMappingFromUTC`, `InpBrokerMappingUntilUTC` | Explicit half-open UTC coverage `[From, Until)`; outside dates fail closed. Include session midnight and all required historical warmup, not just the first displayed test candle. |
| `InpBrokerUTCTransitions` | New optional string input; defaults empty so old presets retain their behavior. Up to 512 ordered rows, separated by `;`, no trailing separator. |

### Explicit transition table

Each row is `YYYY.MM.DD HH:MM=offset_minutes`. The timestamp is an effective **UTC** instant, not server local time. Its offset applies until the next row; the final row applies until `UntilUTC`. The first row must exactly equal `FromUTC`. Changes are effective inclusively at the stated minute. Timestamps and integer offsets must be canonical; incomplete/normalized dates, duplicates, unsorted rows, extra separators, overflow/noninteger offsets and out-of-coverage rows are rejected.

Illustrative syntax only — **not a verified MetaQuotes-Demo configuration**:

```text
InpBrokerDSTRule=3
InpBrokerMappingFromUTC=2026.01.01 00:00
InpBrokerMappingUntilUTC=2027.01.01 00:00
InpBrokerUTCTransitions=2026.01.01 00:00=120;2026.03.08 00:00=180;2026.11.01 00:00=120
InpBrokerTimeVerified=false
```

The example deliberately uses broker-specific transition instants that differ from built-in US instants. Replace the entire schedule with externally verified data before acknowledging verification. Fixed-offset and seasonal-rule test settings used by the automated regressions are synthetic, retained for comparison, and are not assertions about the actual account server.

The table supports multiple offset regimes, including half-hour changes, rule changes across years and southern-hemisphere schedules. Offset resolution and effective-time resolution are one minute. A broker policy requiring sub-minute offsets/transitions is outside this contract. No external timezone database is silently downloaded.

Server-to-UTC conversion tests every distinct configured offset and accepts exactly one round-trip match. Zero matches fail closed; two or more matches fail closed. A repeated server hour cannot be safely disambiguated from an ordinary MT5 wall-clock timestamp alone. The EA does not choose the earlier/later occurrence, infer it from tick order, or interpolate through a gap.

## Historical DST and unchanged strategy timing

New York remains EST (-300 minutes) or EDT (-240 minutes), independently of the broker's DST rule. The existing 1987-2006 rule (first Sunday April / last Sunday October) and 2007 onward rule (second Sunday March / first Sunday November) are retained, including exact UTC transition boundaries. Supported New York history remains 1987-2099. [US Naval Observatory history](https://aa.usno.navy.mil/faq/daylight_time), [NIST rules](https://www.nist.gov/pml/time-and-frequency-division/popular-links/daylight-saving-time-dst).

The old broker EU implementation extrapolated today's October end date before that common rule applied. Built-in EU coverage now requires 1996 or later. Earlier verified broker schedules must use the UTC table instead. [Directive 94/21/EC](https://eur-lex.europa.eu/eli/dir/1994/21/oj) distinguishes September 1995 from October 1996/1997. Future legal changes are not predicted; configure only a coverage interval for which the policy is verified.

Strategy 1 still builds the New York 00:00-04:00 range from exactly four completed H1 intervals. On New York DST-change Sundays that wall-clock interval contains three or five elapsed hours, so the existing `RANGE_SKIP_DST_DAY` policy remains. Broker discontinuities still trigger the existing mapping skip. No range, breakout, return, SL, TP or fallback rule was changed.

Strategy 3 still opens its range at 09:30 New York and uses the configured range length. That is 14:30 UTC in winter and 13:30 UTC in summer. US/EU mismatch weeks are handled by converting New York to UTC and then applying the broker's independent historical rule. ORB's retest, CHoCH/BOS, continuation/reversal, stops, targets and daily limits are unchanged. Native tests use the production `SBORBSessionUTC` function.

## Diagnostics, counters and risk

- `TIME_MAPPING_CONFIG` prints account-server name, named rule, verification flag, offsets, UTC coverage and table-row count at startup. Malformed configuration returns `INIT_PARAMETERS_INCORRECT` with `TIME_MAPPING_CONFIG_INVALID` and the parser reason. A valid but unverified configuration can display its dashboard while decisions remain blocked.
- `BROKER_MAPPING_NOT_VERIFIED`, `BROKER_MAPPING_CONFIG_INVALID:...`, `BROKER_MAPPING_OUTSIDE_UTC_COVERAGE`, `BROKER_MAPPING_SERVER_GAP`, and `BROKER_MAPPING_SERVER_FOLD_AMBIGUOUS` distinguish runtime failures. At a coverage edge, an unmatched seasonal candidate can be described as a gap; inspect the printed coverage as well.
- `TIME_MAPPING_OK` logs server/UTC/NY timestamps and both signed offsets once per New York day or offset change. The dashboard exposes the same current clock mapping. An OK conversion proves consistency with configured data, not external correctness of that data.
- Counter display is now `UNKNOWN (reason)/limit`, never a negative count and never a fabricated zero. Known zero remains `0/limit`. History-selection failure remains `DEAL_HISTORY_UNAVAILABLE`; invalid future intervals are explicitly `TRADE_HISTORY_INTERVAL_INVALID`. Matching historical deals in an ambiguous interval also keep the count unknown.
- Counting still deduplicates actual entry orders, filters by strategy magic/symbol and New York day, and preserves existing cooldown/daily limits. The history query covers all permitted offsets before filtering UTC dates, instead of assuming a seasonal shift smaller than three hours. MT5 may return an empty selection for a future interval, so explicit interval validation is necessary.
- Unknown counts still reject entries. Execution logs now retain the specific reconstruction failure reason. Existing margin, account open-risk, drawdown, daily equity, broker constraints, pending-intent, ownership and strategy-independence checks remain active.
- The explicit UTC table is included in the shared risk-policy signature; concurrent charts must not use different historical mappings. Old fixed/EU/US signatures are unchanged. Existing account-policy mismatch and explicit-reset rules remain; no saved equity baseline or emergency lock is cleared automatically.

## Files and manual use

Changed production files: `Config.mqh`, `NewYorkTime.mqh`, `RiskManager.mqh`, `StatePersistence.mqh`, and `MQL5/Experts/ScalpingBot.mq5`. New `BrokerTimeConfig.mqh` validates/caches the transition configuration. Signal/exit modules, executor, all eleven presets and CapitalGuard are preserved byte for byte. New tests and reports live under `tests/` and `artifacts/broker-time-v1/`; [actual validation](BROKER_TIME_VALIDATION.md) records outcomes and limits.

Compile with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scalping-bot/compile.ps1`. Load the resulting `MQL5/Experts/ScalpingBot.ex5` manually into the intended Strategy Tester terminal (or copy matching source/includes and compile there). Existing loaded copies are not updated by this repository build. No active-terminal deployment was performed.

In the tester Inputs, obtain the broker's historical offset policy and exact UTC changeover instants, choose the corresponding rule/table, set coverage including warmup, and only then acknowledge `InpBrokerTimeVerified=true`. Confirm `TIME_MAPPING_CONFIG` and `TIME_MAPPING_OK` in the journal against known UTC market/session times. No supplied preset has been changed to pretend the actual broker is verified.
