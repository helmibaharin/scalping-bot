# ORB inputs

Research defaults, not optimized parameters. Point distances use this broker symbol _Point and must be reviewed for each instrument. Read [ORB rules](ORB.md) for exact threshold algorithms and state transitions.

| Input | Default | Units / policy |
|---|---|---|
| `InpEnableORBStrategy` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBEnableContinuation` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBEnableFalseBreakout` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBMagicNumber` | 26103122 | Unique strategy magic. Distributed profiles use separate 26103220/22/24/26 values. |
| `InpORBOpeningRangeMinutes` | 15 | Exact opening duration in minutes from 09:30 New York; 1-120. |
| `InpORBSignalTF` | PERIOD_M5 | M5 confirmation only; other values are rejected. |
| `InpORBRequireBOS` | true | Keep true for baseline. Reversals always require BOS even if disabled here. |
| `InpORBRequireConditionalCHoCH` | true | Continuation gate only when opposing structure exists; reversal CHoCH remains mandatory. |
| `InpORBUseFVGValidation` | true | Conditional Option B validation; absence of a qualifying FVG is permitted. |
| `InpORBLogOrderBlocks` | true | Diagnostic opposite-candle/displacement context only; no entry gate. |
| `InpORBLogLiquiditySweeps` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBUseExternalLevels` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBUseHigherTFStructure` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBMinimumRR` | 2.0 | Minimum price reward/risk, at least 2.0. |
| `InpORBMaxTradesPerNYDay` | 2 | Maximum filled ORB entry orders per NY day, shared by its two modes. |
| `InpORBMaxOpenPositions` | 1 | Owned ORB position cap; shared account caps still apply. |
| `InpORBTradingEndNYMinutes` | 960 | NY minute of day, 960 = 16:00. |
| `InpORBBreakoutClearancePoints` | 3 | Symbol points; see the associated algorithm in ORB.md. |
| `InpORBRetestTolerancePoints` | 10 | Symbol points; see the associated algorithm in ORB.md. |
| `InpORBInvalidationPoints` | 15 | Symbol points; see the associated algorithm in ORB.md. |
| `InpORBPivotLeft` | 2 | Strict pivot left strength, 1-10 completed bars of the relevant timeframe. |
| `InpORBPivotRight` | 2 | Strict pivot right confirmation strength, 1-10 completed bars. |
| `InpORBBOSClearancePoints` | 3 | Symbol points; see the associated algorithm in ORB.md. |
| `InpORBMaxRetestBars` | 12 | Completed M5 bars; confirmation/association/expiry window. |
| `InpORBConfirmationTimeoutBars` | 36 | Completed M5 bars; confirmation/association/expiry window. |
| `InpORBMaxEntryExtensionPoints` | 100 | Symbol points; see the associated algorithm in ORB.md. |
| `InpORBStopBufferPoints` | 5 | Symbol points; see the associated algorithm in ORB.md. |
| `InpORBMaxStopPoints` | 300 | Symbol points; see the associated algorithm in ORB.md. |
| `InpORBFVGMinGapPoints` | 2 | Symbol points; see the associated algorithm in ORB.md. |
| `InpORBFVGMaxAgeBars` | 24 | Completed M5 bars; confirmation/association/expiry window. |
| `InpORBFVGMaxDistancePoints` | 100 | Symbol points; see the associated algorithm in ORB.md. |
| `InpORBExternalPolicy` | 0 | 0 Strict; 1 Warning; 2 Selective two-close acceptance. |
| `InpORBCountertrendPolicy` | 0 | 0 Record; 1 Block; 2 Require associated sweep plus normal structure. |
| `InpORBExternalProximityPoints` | 5 | Symbol points; see the associated algorithm in ORB.md. |
| `InpORBSweepClearancePoints` | 2 | Symbol points; see the associated algorithm in ORB.md. |
| `InpORBSweepConfirmationBars` | 3 | Completed M5 bars; confirmation/association/expiry window. |
| `InpORBExternalCalendarNY` | true | true = NY previous weekday and Monday weeks; false = UTC. No holiday calendar. |
| `InpORBUsePreviousWeek` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBUseAsianSession` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBUseLondonSession` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBAsianStartUTCMinutes` | 0 | UTC minute of day; fixed UTC reference window, not automatic regional DST. |
| `InpORBAsianEndUTCMinutes` | 360 | UTC minute of day; fixed UTC reference window, not automatic regional DST. |
| `InpORBLondonStartUTCMinutes` | 420 | UTC minute of day; fixed UTC reference window, not automatic regional DST. |
| `InpORBLondonEndUTCMinutes` | 540 | UTC minute of day; fixed UTC reference window, not automatic regional DST. |
| `InpORBHTFLookbackBars` | 240 | Completed H1/H4 lookback, 30-1000 bars per timeframe. |
| `InpORBMinimumPeriodCoverage` | 0.70 | External M1 observations / expected weekday/session minutes; not proof of complete history. |
| `InpORBDrawRange` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBDrawExternal` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBDrawStructure` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBDrawFVG` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBDrawSweeps` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |
| `InpORBDrawSignals` | true | Independent enable/visibility switch; InpDrawObjects is the drawing master. |

All shared risk and broker-mapping settings still apply. Signal-only remains true and real-account permission false in all four distributed demo profiles. Reversal stop excursion is frozen only at its final decision. Stops are never moved inward to manufacture reward room.

Global strategy ownership checks require three distinct magics even when one strategy is disabled. The panel reports continuation/reversal phase codes: 0 idle, 1 retest, 2 CHoCH, 3 BOS, 4 ready, 5 executed/retired, 6 invalid, 7 expired, 8 blocked.
