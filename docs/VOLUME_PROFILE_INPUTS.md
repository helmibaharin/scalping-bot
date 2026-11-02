# Volume Profile inputs

All seven existing presets are preserved. Source defaults leave Strategy 5 off. The four new presets enable it with signal-only and real-account blocking.

| Input | Source default | Meaning |
|---|---|---|
| `InpEnableVolumeProfile` | `false` | Master Strategy 5 switch; requires broker-day account risk. |
| `InpVPEnablePOCBounce` | `true` | Enable Method 1; its existing owned position remains recognized when disabled. |
| `InpVPEnableValueReversal` | `true` | Enable Method 2; its existing owned position remains recognized when disabled. |
| `InpVPEnableBreakout` | `true` | Enable Method 3; its existing owned position remains recognized when disabled. |
| `InpVPMagicPOCBounce` | `26103801` | Reserved broker magic for Method 1 attribution. |
| `InpVPMagicValueReversal` | `26103802` | Reserved broker magic for Method 2 attribution. |
| `InpVPMagicBreakout` | `26103803` | Reserved broker magic for Method 3 attribution. |
| `InpVPRequireXAUUSD` | `true` | Require XAUUSD token in broker symbol by default. |
| `InpVPProfileTF` | `PERIOD_M1` | Enforced M1 profile source. |
| `InpVPStructureTF` | `PERIOD_M15` | Enforced completed M15 context. |
| `InpVPEntryTF` | `PERIOD_M5` | Enforced completed M5 decisions. |
| `InpVPBinSize` | `0.10` | Profile price-bin width in symbol price units, integer trading-tick multiple. |
| `InpVPValueFraction` | `0.70` | Contiguous volume fraction included in VA, greater than zero and at most one. |
| `InpVPMaxBins` | `20000` | Histogram allocation bound; excessive ranges fail closed. |
| `InpVPReferenceLookbackDays` | `14` | Maximum calendar age of the prior positive-volume D1 session. |
| `InpVPMinimumCoverage` | `0.95` | Minimum fraction of current weekly session mask for normal coverage. |
| `InpVPMinimumSessionMinutes` | `60` | Minimum M1 bars even for D1-verified session exceptions. |
| `InpVPAllowD1VerifiedPartial` | `true` | Accept documented historical session exceptions only after M1/D1 OHLC and tick-volume agreement. |
| `InpVPProfileRetrySeconds` | `60` | Delay between attempts when reference history is unavailable. |
| `InpVPATRPeriod` | `14` | Completed M5 simple-mean true-range period for strategy thresholds. |
| `InpVPPivotLeft` | `2` | Completed bars required on the left of a confirmed M5/M15 pivot. |
| `InpVPPivotRight` | `2` | Completed bars required on the right; prevents future-pivot confirmation. |
| `InpVPStructureLookback` | `240` | Bounded completed structure/context history. |
| `InpVPStopBufferATR` | `0.10` | ATR fraction beyond the POC or method structural extreme for the initial SL. |
| `InpVPPOCProximityATR` | `0.15` | POC interaction zone; a fresh approach begins beyond this distance. |
| `InpVPPOCMaxPenetrationATR` | `0.25` | Maximum Method 1 wick penetration beyond POC before invalidation. |
| `InpVPDirectionalCandles` | `2` | Consecutive directional candles after POC rejection, at least two. |
| `InpVPEngulfToleranceTicks` | `0` | Real-body engulf equality tolerance in trading ticks; zero by default. |
| `InpVPPOCEngulfRR` | `2.0` | POC engulf target in initial risk units, default 2R. |
| `InpVPPOCDirectionalRR` | `1.5` | POC directional-candle target in initial risk units, default 1.5R. |
| `InpVPReversalRR` | `2.0` | Value Area reentry target in initial risk units, default 2R. |
| `InpVPBreakoutRR` | `2.0` | Breakout/pullback/BOS target in initial risk units, default 2R. |
| `InpVPExcursionStopFallback` | `true` | Allow completed excursion extreme if no associated known pivot. |
| `InpVPBreakoutDistanceATR` | `0.30` | Minimum breakout close displacement beyond VAH/VAL. |
| `InpVPBreakoutBodyATR` | `0.40` | Minimum directional real body of the significant breakout candle. |
| `InpVPPullbackProximityATR` | `0.30` | Maximum closest-point distance from broken boundary for a valid pullback. |
| `InpVPMinimumRetracementATR` | `0.10` | Minimum retracement from the post-breakout directional extreme. |
| `InpVPWickToleranceATR` | `0.15` | Maximum wick-only pullback penetration into value; body entry is always invalid. |
| `InpVPDiagnosticDeepBodyATR` | `0.25` | Logging threshold only. ANY pullback body penetration is rejected. |
| `InpVPBOSReferenceMaxAgeBars` | `48` | Maximum M5 age of the known BOS reference. |
| `InpVPSetupExpiryBars` | `12` | Maximum completed M5 bars before a pending method setup expires. |
| `InpVPMaxEntryExtensionATR` | `1.0` | Reject live entry excessively extended from method boundary/POC. |
| `InpVPRequireContextAlignment` | `false` | Optional completed M15 context filter; off by default. |
| `InpVPMaxRiskPercent` | `0.25` | S5 risk ceiling, at most 0.25%; shared caps also apply. |
| `InpVPMaxEntriesPerBrokerDay` | `5` | Actual filled entry orders per method per broker day, at most five. |
| `InpVPCooldownMinutes` | `15` | Minutes after fully completed position, at least 15; partial exit does not start it. |
| `InpVPMaxStopPoints` | `5000` | Maximum allowed S5 structural SL distance in symbol points. |
| `InpVPDrawObjects` | `true` | Draw frozen POC/VAH/VAL when method diagnostics are active. |
| `InpRiskBrokerDay` | `false` | Use shared broker-day equity baseline; false retains prior New York behavior. |
| `InpBrokerRiskMaximumFlatGapHours` | `96` | Maximum provably flat, no-deal closure gap for carrying known equity. |

Balanced and isolated presets use risk sizing (`InpUseFixedVolume=false`), 0.25% requested/maximum trade risk, 1% combined open risk, 2% daily loss and five total account position slots. The slot count remains an account cap; it does not replace the one-slot S5 pool.

All three S5 method switches default true in source; the master defaults false. Isolation files turn off the other two methods. No old preset is rewritten. RR defaults: POC engulf 2, POC directional 1.5, value reversal 2, breakout/BOS 2.

New magics: 26103801/26103802/26103803. Shared risk-policy migration and first-day baseline behavior are described in VOLUME_PROFILE.md.
