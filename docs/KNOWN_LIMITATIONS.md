# SMT limitations

- Strict confirmed structure and research thresholds may yield zero trades in short samples. Synthetic positive entries do not establish live frequency or profitability.
- ATR is a simple true-range mean. Supply/demand uses an immediately opposing origin, consecutive departure, and BOS on the final departure candle. Alternative bases are not approximated silently.
- Freshness is evaluated before the trap sequence, with closed-M1 refinement inside unfinished HTF candles. Missing history blocks decisions; broker session metadata is not a historical holiday database.
- The nearest unbroken opposing zone cannot be skipped. A stale/overlapping nearer obstacle may block a trade. No fixed-R fallback exists.
- Account equity/margin remains shared with other EAs. Netting blocks same-symbol merging. Supplied profiles have distinct active and unused owner-lock magics.
- Restart replay retires historical readiness. Changed profile/timeframes/magic define a new research configuration. Native smoke tests do not establish live fault behavior or manual chart quality.

See [SMT verification](SMT_VALIDATION.md) for the exact test limitations. Earlier ORB/baseline limitations follow.

# ORB limitations

- Strict sequential confirmed pivots, retests, extension limits and external room can produce few or no ORB trades in short samples. Deterministic fixtures demonstrate rule paths; they do not establish live trade performance.
- Broker historical mapping remains an operator-verified validity-bounded DST policy. Broker policy changes outside that interval require separate configurations. Unavailable/ambiguous history blocks the day or candidate.
- Confirmation is M5. Opening duration is configurable; non-native range boundaries require complete M1 data. H1/H4 context uses a bounded pivot lookback.
- Previous day skips weekends but has no holiday calendar. External M1 coverage is a configurable minimum, not proof of complete extrema. Asia/London windows are explicitly UTC inputs, not automatic local-market DST calendars.
- Reversal CHoCH and BOS require distinct events and newly known pivots. The first qualifying FVG is pinned to the setup and cannot be replaced after invalidation. Optional gate changes define different research configurations.
- Countertrend policy defaults to context recording. A sweep alone, a range return alone, or a breakout alone has no entry authority. Order-block logging is diagnostic only. CRG and ML are absent.
- Shared account equity/margin can change due to other EAs. Netting prevents merging but magic numbers cannot create account isolation. Test concurrent charts and terminal restarts on demo.
- Native backtests and release manifests are tied to EX5 hashes. Earlier two-strategy performance belongs to the earlier binary, not the current ORB build.

The original baseline limitations follow.

# Known limitations and provisional assumptions

- This is a first engineering implementation. Its price-action definitions and all thresholds are research choices, not optimized or discretionary pattern recognition. Short test profits/losses do not establish profitability.
- Supported New York rules cover 1987â€“2099. Earlier US exceptions are unsupported. NY DST transition days with three/five elapsed hours in 00â€“04 are skipped because the requested range requires exactly four completed H1 candles.
- Broker time mapping must be explicitly verified for the dates used. Only fixed, EU-transition and US-transition rules are implemented; arbitrary historical broker schedules require another verified implementation or separate fixed-offset intervals. Ambiguous/nonexistent server hours are rejected.
- There is no external holiday/news calendar. Sessions, real quotes, broker retcodes and missing-history rules provide operational guards; they cannot predict announcements, exceptional closures or market gaps.
- The first daily risk baseline remains locked until an observed NY midnight. Downtime at midnight retains that lock. Emergency token resets do not bypass it. This intentionally reduces trading frequency.
- Persistent ownership/risk coordination supports multiple chart symbols in one terminal. Multiple terminals/VPSs are not a shared risk system. Same-symbol netting trades are blocked; external manual/EA interference with an existing netting position is unsupported.
- Native testing has not covered every real broker, account mode, partial-fill/reconnect sequence or simultaneous multi-chart stress scenario. Broker APIs are mocked in deterministic execution tests; native backtests complement but cannot replace a demo forward trial.
- An order outcome without a durable broker ticket is not automatically retried or guessed after restart. An operator must reconcile history. Failed/partial safety closes require manual review; broker-side stops remain the last protection when disconnected.
- Signal-only mode never sends orders, TP modifications or safety closes. Do not rely on signal-only to repair an already unsafe position. Disabling just a strategy switch still leaves owned-position monitoring enabled.
- Volume is floored, never rounded up. A broker minimum can make 0.01 unavailable or exceed the risk cap; those trades are rejected. There is no promise that nominal stops cap realized loss during gaps or unbounded market slippage.
- Distributed point settings assume common broker quote precisions. Review points/ticks for suffix symbols, different metal digit conventions and non-USD account conversion. Commission is a user-supplied round-trip per-lot estimate; actual broker costs may differ.
- Setup IDs use a 32-bit deterministic hash of formation identity. A hash collision conservatively suppresses a distinct setup rather than intentionally allowing a duplicate. Runtime state is not a cryptographically authenticated distributed ledger.
- The triangle detector uses the most recent confirmed endpoints rather than searching all possible line combinations. It deliberately misses some visually plausible formations. Pattern boundaries use candle opening timestamps consistently. Retest continuation requires a separate right-hand candle and may be more restrictive than a discretionary approach.
- Resistance and bullish order-block fallbacks follow the documented mechanical rules only. Missing/invalidated structures cause rejection; no nearest-price or RR-improving substitute is invented.
- CSV trade callbacks can omit forced final tester exits after the final EA event. Native tester totals include those exits; ledger metrics explicitly identify unmatched positions and coverage. Ledger drawdown is realized cash, while native drawdown is account equity. Unknown averages remain unavailable.
- The native portable tester can automatically update MT5. Build changes, first-history download timeouts and account initialization errors are preserved in raw evidence. Reproduction requires controlling terminal build and historical data as well as the EA binary and parameters.

Before considering real-account permission, perform independent broker-specific demo validation, long chronological holdouts, stressed costs/slippage, ownership/restart fault injection and account-mode tests. No real-account deployment was performed for this implementation.


