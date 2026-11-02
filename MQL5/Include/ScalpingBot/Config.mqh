#ifndef SB_CONFIG
#define SB_CONFIG
enum SB_BROKER_DST { SB_FIXED=0, SB_EU=1, SB_US=2, SB_UTC_TABLE=3 };
input group "Strategies and ownership"
input bool InpEnable4HBreakout=true;
input bool InpEnableTriangleMethod=true;
input ulong Inp4HMagicNumber=26103120;
input ulong InpTriangleMagicNumber=26103121;
input bool InpEnableAscendingTriangle=true;
input bool InpEnableDescendingTriangle=true;
input bool InpEnableSymmetricalTriangle=true;
input group "Execution and account risk"
input bool InpTradingEnabled=true;
input bool InpSignalOnly=true;
input bool InpAllowRealAccount=false;
input bool InpUseFixedVolume=true;
input double InpFixedVolume=0.01;
input double InpRiskPercent=0.25;
input double InpMaxTradeRiskPercent=0.25;
input double InpMaxCombinedOpenRiskPercent=0.50;
input int InpMaxTotalOpenPositions=2;
input double InpDailyLossPercent=1.0;
input bool InpEnableDailyRiskLock=true;
input double InpMaxDrawdownPercent=5.0;
input double InpMinFreeMarginPercent=25.0;
input double InpMaxSpreadPoints=50;
input double InpRoundTripCommissionPerLot=0;
input int InpDeviationPoints=10;
input int InpMaxQuoteAgeSeconds=10;
input int InpMaxSignalAgeSeconds=90;
input bool InpEmergency=false;
input int InpResetToken=0;
input group "Historical broker time mapping: verify with your broker"
input bool InpBrokerTimeVerified=false;
input SB_BROKER_DST InpBrokerDSTRule=SB_FIXED;
input int InpBrokerWinterUTCMinutes=120;
input int InpBrokerSummerUTCMinutes=180;
input datetime InpBrokerMappingFromUTC=D'2007.01.01 00:00';
input datetime InpBrokerMappingUntilUTC=D'2038.01.01 00:00';
// UTC effective instants and signed minutes east of UTC. First row must equal FromUTC.
input string InpBrokerUTCTransitions="";
input group "4H false breakout reversal"
input int Inp4HMaxTradesPerNYDay=1;
input int Inp4HMaxOpenPositions=1;
input double Inp4HRewardRiskRatio=2.0;
input double Inp4HMaxStopPoints=300;
input double Inp4HStopBufferPoints=5;
input int InpStructureLookbackBars=120;
input int InpStructurePivotStrength=2;
input int InpResistanceMinTouches=2;
input double InpResistanceTolerancePoints=15;
input bool InpOrderBlockUseWicks=true;
input int InpOrderBlockDisplacementBars=3;
input double InpOrderBlockDisplacementFactor=1.5;
input group "Triangle breakout, retest, continuation"
input ENUM_TIMEFRAMES InpTriangleTimeframe=PERIOD_M5;
input int InpTrianglePivotLeft=2;
input int InpTrianglePivotRight=2;
input int InpTriangleMinTouches=2;
input int InpTriangleMinSeparationBars=3;
input int InpTriangleMinDurationBars=8;
input int InpTriangleMaxDurationBars=60;
input int InpTriangleMaxPatternAgeBars=100;
input double InpTriangleHorizontalTolerancePoints=15;
input double InpTriangleMinHeightPoints=40;
input double InpTriangleMinConvergence=0.15;
input int InpTriangleMinApexBars=2;
input int InpTriangleMaxApexBars=100;
input double InpTriangleBreakoutClearancePoints=3;
input double InpTriangleRetestTolerancePoints=10;
input double InpTriangleInvalidationPoints=15;
input bool InpTriangleRequireDirectionalBody=true;
input int InpTriangleMaxRetestBars=12;
input int InpTriangleMaxOpenPositions=1;
input int InpTriangleMaxTradesPerDay=3;
input int InpTriangleCooldownMinutes=15;
input double InpTriangleRewardRiskRatio=2.0;
input double InpTriangleMaxStopPoints=250;
input double InpTriangleStopBufferPoints=5;
input group "Diagnostics"
input bool InpShowPanel=true;
input bool InpDrawObjects=true;
input bool InpCSVLogging=true;
input int InpMaxReplayBars=2000;
input group "ORB independent strategy and modes"
input bool InpEnableORBStrategy=true;
input bool InpORBEnableContinuation=true;
input bool InpORBEnableFalseBreakout=true;
input ulong InpORBMagicNumber=26103122;
input int InpORBOpeningRangeMinutes=15;
input ENUM_TIMEFRAMES InpORBSignalTF=PERIOD_M5;
input bool InpORBRequireBOS=true;
input bool InpORBRequireConditionalCHoCH=true;
input bool InpORBUseFVGValidation=true;
input bool InpORBLogOrderBlocks=true;
input bool InpORBLogLiquiditySweeps=true;
input bool InpORBUseExternalLevels=true;
input bool InpORBUseHigherTFStructure=true;
input double InpORBMinimumRR=2.0;
input int InpORBMaxTradesPerNYDay=2;
input int InpORBMaxOpenPositions=1;
input int InpORBTradingEndNYMinutes=960;
input double InpORBBreakoutClearancePoints=3;
input double InpORBRetestTolerancePoints=10;
input double InpORBInvalidationPoints=15;
input int InpORBPivotLeft=2;
input int InpORBPivotRight=2;
input double InpORBBOSClearancePoints=3;
input int InpORBMaxRetestBars=12;
input int InpORBConfirmationTimeoutBars=36;
input double InpORBMaxEntryExtensionPoints=100;
input double InpORBStopBufferPoints=5;
input double InpORBMaxStopPoints=300;
input double InpORBFVGMinGapPoints=2;
input int InpORBFVGMaxAgeBars=24;
input double InpORBFVGMaxDistancePoints=100;
input group "ORB external context: policies 0=strict/record, 1=warning/block, 2=selective/sweep"
input int InpORBExternalPolicy=0;
input int InpORBCountertrendPolicy=0;
input double InpORBExternalProximityPoints=5;
input double InpORBSweepClearancePoints=2;
input int InpORBSweepConfirmationBars=3;
input bool InpORBExternalCalendarNY=true;
input bool InpORBUsePreviousWeek=true;
input bool InpORBUseAsianSession=true;
input bool InpORBUseLondonSession=true;
input int InpORBAsianStartUTCMinutes=0;
input int InpORBAsianEndUTCMinutes=360;
input int InpORBLondonStartUTCMinutes=420;
input int InpORBLondonEndUTCMinutes=540;
input int InpORBHTFLookbackBars=240;
input double InpORBMinimumPeriodCoverage=0.70;
input group "ORB chart annotations"
input bool InpORBDrawRange=true;
input bool InpORBDrawExternal=true;
input bool InpORBDrawStructure=true;
input bool InpORBDrawFVG=true;
input bool InpORBDrawSweeps=true;
input bool InpORBDrawSignals=true;

input group "SMT Strategy 4: disabled in existing profiles"
input bool InpEnableSMTStrategy=false;
input int InpSMTProfile=0;
input ulong InpSMTMagicNumber=26103499;
input bool InpSMTSignalOnly=true;
input ENUM_TIMEFRAMES InpSMTTrendTF=PERIOD_D1;
input ENUM_TIMEFRAMES InpSMTContextTF=PERIOD_H4;
input ENUM_TIMEFRAMES InpSMTZoneTF=PERIOD_H4;
input ENUM_TIMEFRAMES InpSMTSecondaryZoneTF=PERIOD_H1;
input ENUM_TIMEFRAMES InpSMTTrapTF=PERIOD_M15;
input ENUM_TIMEFRAMES InpSMTEntryTF=PERIOD_M5;
input int InpSMTTrendMode=0;
input bool InpSMTAllowNeutralTrend=false;
input bool InpSMTRequireContextAlignment=false;
input int InpSMTPivotLeft=2;
input int InpSMTPivotRight=2;
input int InpSMTMinConfirmedPivots=2;
input int InpSMTLookbackBars=300;
input int InpSMTATRPeriod=14;
input double InpSMTSignificantSwingATR=0.2;
input double InpSMTEqualLevelTolerancePoints=10;
input bool InpSMTUseBSL=true;
input bool InpSMTUseSSL=true;
input bool InpSMTUseSupply=true;
input bool InpSMTUseDemand=true;
input bool InpSMTUseAccumulation=true;
input bool InpSMTUseDistribution=true;
input bool InpSMTRequireFreshZones=true;
input bool InpSMTZoneUseWicks=true;
input int InpSMTDepartureBars=2;
input double InpSMTMomentumBodyATR=0.6;
input double InpSMTDepartureDistanceATR=1.5;
input double InpSMTDepartureCloseFraction=0.25;
input double InpSMTMaxOpposingWickFraction=0.25;
input double InpSMTBOSClearancePoints=2;
input int InpSMTZoneMaxAgeBars=120;
input int InpSMTConsolidationBars=8;
input double InpSMTConsolidationMaxWidthATR=2.0;
input int InpSMTConsolidationTouches=2;
input int InpSMTPriorMoveBars=5;
input double InpSMTPriorMoveATR=2.0;
input int InpSMTAcceptanceCloses=3;
input double InpSMTLocationProximityPoints=10;
input bool InpSMTEnableClassic=true;
input bool InpSMTEnableMultipleBaby=true;
input bool InpSMTEnableRangeTrap=true;
input int InpSMTMinBabyCandles=2;
input int InpSMTMaxBabyCandles=5;
input int InpSMTMaxPatternAgeBars=12;
input int InpSMTReentryMaxBars=3;
input double InpSMTSweepPenetrationPoints=2;
input double InpSMTInsideTolerancePoints=0;
input bool InpSMTRequireConditionalCHoCH=true;
input bool InpSMTRequireBOS=true;
input int InpSMTConfirmationBars=24;
input double InpSMTMaxEntryExtensionATR=2.0;
input int InpSMTCooldownMinutes=15;
input int InpSMTMaxTradesPerNYDay=3;
input int InpSMTMaxOpenPositions=1;
input bool InpSMTUseFVGValidation=true;
input double InpSMTFVGMinGapPoints=2;
input int InpSMTFVGMaxAgeBars=12;
input double InpSMTFVGMaxDistanceATR=2.0;
input double InpSMTStopBufferPoints=5;
input double InpSMTStopATRBuffer=0.05;
input double InpSMTStopSpreadMultiplier=1.0;
input double InpSMTMaxStopPoints=3000;
input bool InpSMTDynamicTP=true;
// Structural SL/zone TP, any positive net reward; sizing and account risk still apply.
input bool InpSMTSetupBasedExits=false;
input double InpSMTTPBufferPoints=5;
input bool InpSMTUseMinimumRR=true;
input double InpSMTMinimumRR=1.0;
input double InpSMTMaxSpreadPoints=50;
input double InpSMTMaxTradeRiskPercent=0.25;
input bool InpSMTDrawObjects=true;

// Legacy names above remain the Strategy 2 ownership/risk and triangle geometry namespace.
input group "Shape Pattern Strategy (S2): explicit legacy profile compatibility"
input bool InpShapeLegacyTriangle=false;
input ENUM_TIMEFRAMES InpShapeFormationTF=PERIOD_M15;
input ENUM_TIMEFRAMES InpShapeEntryTF=PERIOD_M5;
input ENUM_TIMEFRAMES InpShapeContextTF=PERIOD_H1;
input bool InpShapeUseContext=false;
input bool InpShapeContinuation=true;
input bool InpShapeReversal=true;
input bool InpShapeTriangle=true;
input bool InpShapeFlag=true;
input bool InpShapeHeadShoulders=true;
input bool InpShapeInverseHeadShoulders=true;
input bool InpShapeDoubleTop=true;
input bool InpShapeDoubleBottom=true;
input bool InpShapeFallingWedge=true;
input bool InpShapeRisingWedge=true;
input int InpShapeLookback=240;
input int InpShapeMaxCandidates=16;
input int InpShapeConfirmationBars=36;
input int InpShapeFailureBars=6;
input double InpShapeToleranceATR=0.15;
input double InpShapeShoulderTolerance=0.20;
input double InpShapeSymmetryRatio=3.0;
input double InpShapePoleATR=3.0;
input double InpShapeFlagMaxPoleFraction=0.50;
input double InpShapeBreakBodyATR=0.25;
input double InpShapeSweepPoints=2;
input double InpShapeTPBufferPoints=5;
input double InpShapeContinuationMinRR=2.0;
input bool InpShapeReversalMinRREnabled=true;
// New Shape engine only; use its structural/measured targets without a minimum R or point cap.
input bool InpShapeSetupBasedExits=false;
input double InpShapeReversalMinRR=1.0;
input bool InpShapeDraw=true;
input group "Strategy 5 Volume Profile: disabled in existing presets"
input bool InpEnableVolumeProfile=false;
input bool InpVPEnablePOCBounce=true;
input bool InpVPEnableValueReversal=true;
input bool InpVPEnableBreakout=true;
input ulong InpVPMagicPOCBounce=26103801;
input ulong InpVPMagicValueReversal=26103802;
input ulong InpVPMagicBreakout=26103803;
input bool InpVPRequireXAUUSD=true;
input ENUM_TIMEFRAMES InpVPProfileTF=PERIOD_M1;
input ENUM_TIMEFRAMES InpVPStructureTF=PERIOD_M15;
input ENUM_TIMEFRAMES InpVPEntryTF=PERIOD_M5;
input double InpVPBinSize=0.10;
input double InpVPValueFraction=0.70;
input int InpVPMaxBins=20000;
input int InpVPReferenceLookbackDays=14;
input double InpVPMinimumCoverage=0.95;
input int InpVPMinimumSessionMinutes=60;
input bool InpVPAllowD1VerifiedPartial=true;
input int InpVPProfileRetrySeconds=60;
input int InpVPATRPeriod=14;
input int InpVPPivotLeft=2;
input int InpVPPivotRight=2;
input int InpVPStructureLookback=240;
input double InpVPStopBufferATR=0.10;
input double InpVPPOCProximityATR=0.15;
input double InpVPPOCMaxPenetrationATR=0.25;
input int InpVPDirectionalCandles=2;
input double InpVPEngulfToleranceTicks=0;
input double InpVPPOCEngulfRR=2.0;
input double InpVPPOCDirectionalRR=1.5;
input double InpVPReversalRR=2.0;
input double InpVPBreakoutRR=2.0;
input bool InpVPExcursionStopFallback=true;
input double InpVPBreakoutDistanceATR=0.30;
input double InpVPBreakoutBodyATR=0.40;
input double InpVPPullbackProximityATR=0.30;
input double InpVPMinimumRetracementATR=0.10;
input double InpVPWickToleranceATR=0.15;
input double InpVPDiagnosticDeepBodyATR=0.25;
input int InpVPBOSReferenceMaxAgeBars=48;
input int InpVPSetupExpiryBars=12;
input double InpVPMaxEntryExtensionATR=1.0;
input bool InpVPRequireContextAlignment=false;
input double InpVPMaxRiskPercent=0.25;
input int InpVPMaxEntriesPerBrokerDay=5;
input int InpVPCooldownMinutes=15;
input double InpVPMaxStopPoints=5000;
input bool InpVPDrawObjects=true;
input bool InpRiskBrokerDay=false;
input int InpBrokerRiskMaximumFlatGapHours=96;
bool SBValidVPInputs()
  {
   ulong magics[7]={Inp4HMagicNumber,InpTriangleMagicNumber,InpORBMagicNumber,InpSMTMagicNumber,InpVPMagicPOCBounce,InpVPMagicValueReversal,InpVPMagicBreakout};
   for(int i=0;i<7;i++){if(magics[i]==0)return false;for(int j=0;j<i;j++)if(magics[i]==magics[j])return false;}
   return (!InpEnableVolumeProfile || InpRiskBrokerDay) && InpBrokerRiskMaximumFlatGapHours>=1 && InpBrokerRiskMaximumFlatGapHours<=168 &&
    InpVPProfileTF==PERIOD_M1 && InpVPEntryTF==PERIOD_M5 && InpVPStructureTF==PERIOD_M15 &&
    InpVPBinSize>0 && InpVPValueFraction>0 && InpVPValueFraction<=1 && InpVPMaxBins>=10 && InpVPMaxBins<=200000 &&
    InpVPReferenceLookbackDays>=2 && InpVPReferenceLookbackDays<=60 && InpVPMinimumCoverage>0 && InpVPMinimumCoverage<=1 &&
    InpVPMinimumSessionMinutes>=1 && InpVPMinimumSessionMinutes<=1440 && InpVPProfileRetrySeconds>=10 &&
    InpVPATRPeriod>=2 && InpVPATRPeriod<=100 && InpVPPivotLeft>=1 && InpVPPivotLeft<=10 && InpVPPivotRight>=1 && InpVPPivotRight<=10 &&
    InpVPStructureLookback>=60 && InpVPStructureLookback<=1000 && InpVPStopBufferATR>=0 && InpVPPOCProximityATR>=0 && InpVPPOCMaxPenetrationATR>=0 &&
    InpVPDirectionalCandles>=2 && InpVPDirectionalCandles<=5 && InpVPEngulfToleranceTicks>=0 && InpVPPOCEngulfRR>0 &&
    InpVPPOCDirectionalRR>0 && InpVPReversalRR>0 && InpVPBreakoutRR>0 && InpVPBreakoutDistanceATR>0 && InpVPBreakoutBodyATR>0 &&
    InpVPPullbackProximityATR>=0 && InpVPMinimumRetracementATR>0 && InpVPWickToleranceATR>=0 && InpVPDiagnosticDeepBodyATR>=0 &&
    InpVPBOSReferenceMaxAgeBars>=2 && InpVPBOSReferenceMaxAgeBars<=200 && InpVPSetupExpiryBars>=3 && InpVPSetupExpiryBars<=100 &&
    InpVPMaxEntryExtensionATR>0 && InpVPMaxRiskPercent>0 && InpVPMaxRiskPercent<=0.25 && InpVPMaxEntriesPerBrokerDay>=1 &&
    InpVPMaxEntriesPerBrokerDay<=5 && InpVPCooldownMinutes>=15 && InpVPMaxStopPoints>0 &&
    InpMaxCombinedOpenRiskPercent<=1 && InpDailyLossPercent<=2 && InpMaxTradeRiskPercent<=0.25;
  }
bool SBValidShapeInputs()
  {
   int f=PeriodSeconds(InpShapeFormationTF),e=PeriodSeconds(InpShapeEntryTF);
   return InpShapeLegacyTriangle || (e>=60 && f>=e && f%e==0 && PeriodSeconds(InpShapeContextTF)>=f &&
     InpShapeLookback>=80 && InpShapeLookback<=1000 && InpShapeMaxCandidates>=1 && InpShapeMaxCandidates<=32 &&
     InpShapeConfirmationBars>=3 && InpShapeConfirmationBars<=200 && InpShapeFailureBars>=1 && InpShapeFailureBars<=20 &&
     InpShapeToleranceATR>=0 && InpShapeShoulderTolerance>0 && InpShapeShoulderTolerance<1 && InpShapeSymmetryRatio>=1 &&
     InpShapePoleATR>0 && InpShapeFlagMaxPoleFraction>0 && InpShapeFlagMaxPoleFraction<1 && InpShapeBreakBodyATR>=0 &&
     InpShapeSweepPoints>=0 && InpShapeTPBufferPoints>=0 && InpShapeContinuationMinRR>0 && InpShapeReversalMinRR>0);
  }
bool SBValidSMTInputs()
  {
   int entry=PeriodSeconds(InpSMTEntryTF),trap=PeriodSeconds(InpSMTTrapTF);
   return InpSMTMagicNumber>0 && InpSMTMagicNumber!=Inp4HMagicNumber && InpSMTMagicNumber!=InpTriangleMagicNumber &&
    InpSMTMagicNumber!=InpORBMagicNumber && InpSMTProfile>=0 && InpSMTProfile<=1 && entry>=60 && trap>=entry && trap%entry==0 &&
    PeriodSeconds(InpSMTTrendTF)>=entry && PeriodSeconds(InpSMTZoneTF)>=entry && PeriodSeconds(InpSMTSecondaryZoneTF)>=entry &&
    PeriodSeconds(InpSMTContextTF)>=entry && InpSMTTrendMode>=0 && InpSMTTrendMode<=2 &&
    InpSMTPivotLeft>=1 && InpSMTPivotLeft<=10 && InpSMTPivotRight>=1 && InpSMTPivotRight<=10 &&
    InpSMTMinConfirmedPivots>=2 && InpSMTMinConfirmedPivots<=10 && InpSMTLookbackBars>=100 && InpSMTLookbackBars<=1000 &&
    InpSMTATRPeriod>=2 && InpSMTATRPeriod<=50 && InpSMTSignificantSwingATR>=0 && InpSMTEqualLevelTolerancePoints>=0 &&
    InpSMTDepartureBars>=1 && InpSMTDepartureBars<=5 && InpSMTMomentumBodyATR>0 && InpSMTDepartureDistanceATR>0 &&
    InpSMTDepartureCloseFraction>0 && InpSMTDepartureCloseFraction<=0.5 && InpSMTMaxOpposingWickFraction>=0 && InpSMTMaxOpposingWickFraction<=0.5 &&
    InpSMTBOSClearancePoints>=0 && InpSMTZoneMaxAgeBars>=5 && InpSMTZoneMaxAgeBars<=InpSMTLookbackBars &&
    InpSMTConsolidationBars>=4 && InpSMTConsolidationBars<=40 && InpSMTConsolidationMaxWidthATR>0 && InpSMTConsolidationTouches>=2 &&
    InpSMTPriorMoveBars>=2 && InpSMTPriorMoveBars<=20 && InpSMTPriorMoveATR>0 && InpSMTAcceptanceCloses>=2 &&
    InpSMTLocationProximityPoints>=0 && InpSMTMinBabyCandles>=2 && InpSMTMaxBabyCandles>=InpSMTMinBabyCandles && InpSMTMaxBabyCandles<=10 &&
    InpSMTMaxPatternAgeBars>=InpSMTMaxBabyCandles+1 && InpSMTMaxPatternAgeBars<=50 && InpSMTReentryMaxBars>=1 && InpSMTReentryMaxBars<=10 &&
    InpSMTSweepPenetrationPoints>=0 && InpSMTInsideTolerancePoints>=0 && InpSMTRequireBOS && InpSMTConfirmationBars>=2 && InpSMTConfirmationBars<=100 &&
    InpSMTMaxEntryExtensionATR>0 && InpSMTCooldownMinutes>=0 && InpSMTMaxTradesPerNYDay>0 && InpSMTMaxOpenPositions>0 &&
    InpSMTFVGMinGapPoints>=0 && InpSMTFVGMaxAgeBars>=1 && InpSMTFVGMaxDistanceATR>0 && InpSMTStopBufferPoints>=0 &&
    InpSMTStopATRBuffer>=0 && InpSMTStopSpreadMultiplier>=0 && InpSMTMaxStopPoints>0 && InpSMTDynamicTP &&
    InpSMTTPBufferPoints>=0 && InpSMTMinimumRR>0 && InpSMTMaxSpreadPoints>0 && InpSMTMaxTradeRiskPercent>0 && InpSMTMaxTradeRiskPercent<=InpMaxTradeRiskPercent;
  }

bool SBValidORBInputs()
  {
   return InpORBMagicNumber>0 && InpORBMagicNumber!=Inp4HMagicNumber && InpORBMagicNumber!=InpTriangleMagicNumber &&
    InpORBOpeningRangeMinutes>=1 && InpORBOpeningRangeMinutes<=120 && InpORBSignalTF==PERIOD_M5 &&
    InpORBMinimumRR>=2 && InpORBMaxTradesPerNYDay>0 && InpORBMaxOpenPositions>0 &&
    InpORBTradingEndNYMinutes>570+InpORBOpeningRangeMinutes && InpORBTradingEndNYMinutes<=1440 &&
    InpORBBreakoutClearancePoints>=0 && InpORBRetestTolerancePoints>=0 && InpORBInvalidationPoints>=0 &&
    InpORBPivotLeft>=1 && InpORBPivotLeft<=10 && InpORBPivotRight>=1 && InpORBPivotRight<=10 &&
    InpORBBOSClearancePoints>=0 && InpORBMaxRetestBars>=1 && InpORBConfirmationTimeoutBars>InpORBMaxRetestBars &&
    InpORBMaxEntryExtensionPoints>0 && InpORBStopBufferPoints>=0 && InpORBMaxStopPoints>0 &&
    InpORBFVGMinGapPoints>=0 && InpORBFVGMaxAgeBars>=1 && InpORBFVGMaxDistancePoints>0 &&
    InpORBExternalPolicy>=0 && InpORBExternalPolicy<=2 && InpORBCountertrendPolicy>=0 && InpORBCountertrendPolicy<=2 &&
    InpORBExternalProximityPoints>=0 && InpORBSweepClearancePoints>=0 && InpORBSweepConfirmationBars>=1 &&
    InpORBAsianStartUTCMinutes>=0 && InpORBAsianEndUTCMinutes>InpORBAsianStartUTCMinutes && InpORBAsianEndUTCMinutes<=1440 &&
    InpORBLondonStartUTCMinutes>=0 && InpORBLondonEndUTCMinutes>InpORBLondonStartUTCMinutes && InpORBLondonEndUTCMinutes<=1440 &&
    InpORBHTFLookbackBars>=30 && InpORBHTFLookbackBars<=1000 && InpORBMinimumPeriodCoverage>0 && InpORBMinimumPeriodCoverage<=1;
  }

bool SBValidInputs()
  {
   return Inp4HMagicNumber>0 && InpTriangleMagicNumber>0 && Inp4HMagicNumber!=InpTriangleMagicNumber &&
     InpFixedVolume>0 && InpRiskPercent>0 && InpRiskPercent<=InpMaxTradeRiskPercent && InpMaxTradeRiskPercent>0 &&
     InpMaxCombinedOpenRiskPercent>0 && InpMaxCombinedOpenRiskPercent<100 && InpMaxTotalOpenPositions>0 &&
     InpDailyLossPercent>0 && InpDailyLossPercent<100 && InpMaxDrawdownPercent>0 && InpMaxDrawdownPercent<100 &&
     InpMinFreeMarginPercent>=0 && InpMinFreeMarginPercent<100 && InpMaxSpreadPoints>0 &&
     InpRoundTripCommissionPerLot>=0 && InpDeviationPoints>=0 && InpMaxQuoteAgeSeconds>0 &&
     InpMaxSignalAgeSeconds>0 && InpResetToken>=0 && InpBrokerMappingUntilUTC>InpBrokerMappingFromUTC &&
     MathAbs(InpBrokerWinterUTCMinutes)<=840 && MathAbs(InpBrokerSummerUTCMinutes)<=840 &&
     Inp4HMaxTradesPerNYDay>0 && Inp4HMaxOpenPositions>0 && Inp4HRewardRiskRatio>=2 && Inp4HMaxStopPoints>0 &&
     Inp4HStopBufferPoints>=0 && InpStructureLookbackBars>=10 && InpStructureLookbackBars<=2000 &&
     InpStructurePivotStrength>=1 && InpStructurePivotStrength<=10 && InpResistanceMinTouches>=1 &&
     InpResistanceTolerancePoints>=0 && InpOrderBlockDisplacementBars>=1 && InpOrderBlockDisplacementBars<=10 &&
     InpOrderBlockDisplacementFactor>0 && PeriodSeconds(InpTriangleTimeframe)>=60 &&
     InpTrianglePivotLeft>=1 && InpTrianglePivotLeft<=10 && InpTrianglePivotRight>=1 && InpTrianglePivotRight<=10 &&
     InpTriangleMinTouches>=2 && InpTriangleMinSeparationBars>=1 && InpTriangleMinDurationBars>=4 &&
     InpTriangleMaxDurationBars>=InpTriangleMinDurationBars && InpTriangleMaxDurationBars<=500 &&
     InpTriangleMaxPatternAgeBars>=InpTriangleMaxDurationBars && InpTriangleMaxPatternAgeBars<=1000 &&
     InpTriangleHorizontalTolerancePoints>=0 && InpTriangleMinHeightPoints>0 &&
     InpTriangleMinConvergence>0 && InpTriangleMinConvergence<1 && InpTriangleMinApexBars>=1 &&
     InpTriangleMaxApexBars>InpTriangleMinApexBars && InpTriangleBreakoutClearancePoints>=0 &&
     InpTriangleRetestTolerancePoints>=0 && InpTriangleInvalidationPoints>=0 && InpTriangleMaxRetestBars>=2 &&
     InpTriangleMaxOpenPositions>0 && InpTriangleMaxTradesPerDay>0 && InpTriangleCooldownMinutes>=0 &&
     InpTriangleRewardRiskRatio>=2 && InpTriangleMaxStopPoints>0 && InpTriangleStopBufferPoints>=0 && InpMaxReplayBars>=1500;
  }
#endif
