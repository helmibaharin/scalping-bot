# SMT inputs

All thresholds are research parameters. Price distances in points use the current broker symbol _Point; ATR ratios use closed-bar true-range averages. See [rules](SMT.md) for complete algorithms. The supplied profiles use STRICT trend, all patterns/locations, fresh zones, dynamic TP and optional 1R minimum.

| Input | Source default | Meaning / unit |
|---|---|---|
| `InpEnableSMTStrategy` | false | Default false preserves Strategies 1-3 and existing profile behavior. |
| `InpSMTProfile` | 0 | 0 MTF; 1 SCALP. One engine per chart, separate profile magic. |
| `InpSMTMagicNumber` | 26103499 | Default source identity 26103499; supplied profiles use 26103400 and 26103401. |
| `InpSMTSignalOnly` | true | Additional restrictive gate: global OR this flag prevents order sending. |
| `InpSMTTrendTF` | PERIOD_D1 | Configurable timeframe; supplied profile values are listed in SMT.md. |
| `InpSMTContextTF` | PERIOD_H4 | Configurable timeframe; supplied profile values are listed in SMT.md. |
| `InpSMTZoneTF` | PERIOD_H4 | Configurable timeframe; supplied profile values are listed in SMT.md. |
| `InpSMTSecondaryZoneTF` | PERIOD_H1 | Configurable timeframe; supplied profile values are listed in SMT.md. |
| `InpSMTTrapTF` | PERIOD_M15 | Configurable timeframe; supplied profile values are listed in SMT.md. |
| `InpSMTEntryTF` | PERIOD_M5 | Configurable timeframe; supplied profile values are listed in SMT.md. |
| `InpSMTTrendMode` | 0 | 0 STRICT; 1 CONTEXT_ONLY; 2 DISABLED. |
| `InpSMTAllowNeutralTrend` | false | Research override for neutral strict trend; insufficient data is still rejected in STRICT. |
| `InpSMTRequireContextAlignment` | false | Optional additional context veto; default false. |
| `InpSMTPivotLeft` | 2 | Count/threshold; see SMT.md. |
| `InpSMTPivotRight` | 2 | Count/threshold; see SMT.md. |
| `InpSMTMinConfirmedPivots` | 2 | Minimum highs and lows each, at least two; latest two define HH/HL or LH/LL. |
| `InpSMTLookbackBars` | 300 | Completed source/entry bars or elapsed timeframe intervals, as defined in SMT.md. |
| `InpSMTATRPeriod` | 14 | Simple average of completed true ranges; no indicator handle. |
| `InpSMTSignificantSwingATR` | 0.2 | Minimum confirmed pivot candle range / ATR. |
| `InpSMTEqualLevelTolerancePoints` | 10 | Current symbol points; review for digits, tick size, spread and contract. |
| `InpSMTUseBSL` | true | Independent research enable/validation flag; see rules. |
| `InpSMTUseSSL` | true | Independent research enable/validation flag; see rules. |
| `InpSMTUseSupply` | true | Independent research enable/validation flag; see rules. |
| `InpSMTUseDemand` | true | Independent research enable/validation flag; see rules. |
| `InpSMTUseAccumulation` | true | Independent research enable/validation flag; see rules. |
| `InpSMTUseDistribution` | true | Independent research enable/validation flag; see rules. |
| `InpSMTRequireFreshZones` | true | Require fresh strong zones at sequence start; stale nearer target still blocks farther selection. |
| `InpSMTZoneUseWicks` | true | Origin bounds: full wick range true; body false. Bounds never move after publication. |
| `InpSMTDepartureBars` | 2 | Completed source/entry bars or elapsed timeframe intervals, as defined in SMT.md. |
| `InpSMTMomentumBodyATR` | 0.6 | ATR ratio/allowance; see rule definition. |
| `InpSMTDepartureDistanceATR` | 1.5 | ATR ratio/allowance; see rule definition. |
| `InpSMTDepartureCloseFraction` | 0.25 | Maximum tail between close and directional extreme / candle range. |
| `InpSMTMaxOpposingWickFraction` | 0.25 | Maximum opposing wick / departure candle range. |
| `InpSMTBOSClearancePoints` | 2 | Current symbol points; review for digits, tick size, spread and contract. |
| `InpSMTZoneMaxAgeBars` | 120 | Completed source/entry bars or elapsed timeframe intervals, as defined in SMT.md. |
| `InpSMTConsolidationBars` | 8 | Completed source/entry bars or elapsed timeframe intervals, as defined in SMT.md. |
| `InpSMTConsolidationMaxWidthATR` | 2.0 | ATR ratio/allowance; see rule definition. |
| `InpSMTConsolidationTouches` | 2 | Required upper and lower range touches separately. |
| `InpSMTPriorMoveBars` | 5 | Completed source/entry bars or elapsed timeframe intervals, as defined in SMT.md. |
| `InpSMTPriorMoveATR` | 2.0 | ATR ratio/allowance; see rule definition. |
| `InpSMTAcceptanceCloses` | 3 | Consecutive outside closes that invalidate non-zone references. |
| `InpSMTLocationProximityPoints` | 10 | Current symbol points; review for digits, tick size, spread and contract. |
| `InpSMTEnableClassic` | true | Independent research enable/validation flag; see rules. |
| `InpSMTEnableMultipleBaby` | true | Independent research enable/validation flag; see rules. |
| `InpSMTEnableRangeTrap` | true | Independent research enable/validation flag; see rules. |
| `InpSMTMinBabyCandles` | 2 | Count/threshold; see SMT.md. |
| `InpSMTMaxBabyCandles` | 5 | Count/threshold; see SMT.md. |
| `InpSMTMaxPatternAgeBars` | 12 | Completed source/entry bars or elapsed timeframe intervals, as defined in SMT.md. |
| `InpSMTReentryMaxBars` | 3 | Completed source/entry bars or elapsed timeframe intervals, as defined in SMT.md. |
| `InpSMTSweepPenetrationPoints` | 2 | Current symbol points; review for digits, tick size, spread and contract. |
| `InpSMTInsideTolerancePoints` | 0 | Current symbol points; review for digits, tick size, spread and contract. |
| `InpSMTRequireConditionalCHoCH` | true | Independent research enable/validation flag; see rules. |
| `InpSMTRequireBOS` | true | Mandatory true; false is rejected at initialization. |
| `InpSMTConfirmationBars` | 24 | Completed source/entry bars or elapsed timeframe intervals, as defined in SMT.md. |
| `InpSMTMaxEntryExtensionATR` | 2.0 | ATR ratio/allowance; see rule definition. |
| `InpSMTCooldownMinutes` | 15 | Minutes. |
| `InpSMTMaxTradesPerNYDay` | 3 | Count/threshold; see SMT.md. |
| `InpSMTMaxOpenPositions` | 1 | Count/threshold; see SMT.md. |
| `InpSMTUseFVGValidation` | true | Independent research enable/validation flag; see rules. |
| `InpSMTFVGMinGapPoints` | 2 | Current symbol points; review for digits, tick size, spread and contract. |
| `InpSMTFVGMaxAgeBars` | 12 | Completed source/entry bars or elapsed timeframe intervals, as defined in SMT.md. |
| `InpSMTFVGMaxDistanceATR` | 2.0 | ATR ratio/allowance; see rule definition. |
| `InpSMTStopBufferPoints` | 5 | Current symbol points; review for digits, tick size, spread and contract. |
| `InpSMTStopATRBuffer` | 0.05 | ATR ratio/allowance; see rule definition. |
| `InpSMTStopSpreadMultiplier` | 1.0 | Count/threshold; see SMT.md. |
| `InpSMTMaxStopPoints` | 3000 | Current symbol points; review for digits, tick size, spread and contract. |
| `InpSMTDynamicTP` | true | Mandatory true; false is rejected. No fixed-R fallback exists. |
| `InpSMTTPBufferPoints` | 5 | Current symbol points; review for digits, tick size, spread and contract. |
| `InpSMTUseMinimumRR` | true | Optional gate on price RR and conservative cost-adjusted monetary RR. |
| `InpSMTMinimumRR` | 1.0 | Minimum RR when enabled; default 1.0, never a forced target multiple. |
| `InpSMTMaxSpreadPoints` | 50 | Current symbol points; review for digits, tick size, spread and contract. |
| `InpSMTMaxTradeRiskPercent` | 0.25 | SMT monetary cap, no higher than shared per-trade cap. Fixed lots must also satisfy it. |
| `InpSMTDrawObjects` | true | SMT visualization switch, subordinate to InpDrawObjects; panel uses InpShowPanel. |

Profile 1 overrides the SMT magic to 26103400. Profile 2 uses magic 26103401, M15 trend/context and M1 primary/secondary zone, trap and entry timeframes. Both preserve all shared safety settings and disable Strategies 1-3 without modifying their original profiles.

The existing shared risk, daily baseline, broker mapping, quote freshness, symbol sessions, volume, margin, emergency, global signal-only and real-account gates remain active. Equal-level and inside/sweep tolerances are tick-grid-aware through actual symbol pricing; stops/targets are explicitly rounded to SYMBOL_TRADE_TICK_SIZE.
