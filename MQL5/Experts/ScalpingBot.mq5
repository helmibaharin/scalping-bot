#property copyright "Scalping Bot contributors"
#property version "1.00"
#property strict
#property description "Independent 4H reversal, triangle, ORB and SMT EA. Research/demo first; signal-only by default."
#include "../Include/ScalpingBot/Config.mqh"
#include "../Include/ScalpingBot/StrategyInterface.mqh"
#include "../Include/ScalpingBot/SetupExitPolicy.mqh"
#include "../Include/ScalpingBot/Rules.mqh"
#include "../Include/ScalpingBot/NewYorkTime.mqh"
#include "../Include/ScalpingBot/Diagnostics.mqh"
#include "../Include/ScalpingBot/SessionRange.mqh"
#include "../Include/ScalpingBot/ORBExternal.mqh"
#include "../Include/ScalpingBot/StatePersistence.mqh"
#include "../Include/ScalpingBot/SMTContext.mqh"
#include "../Include/ScalpingBot/ShapeEngine.mqh"
#include "../Include/ScalpingBot/VolumeProfileSessions.mqh"
#include "../Include/ScalpingBot/TradeLedger.mqh"
#include "../Include/ScalpingBot/VolumeProfilePolicy.mqh"
#include "../Include/ScalpingBot/RiskManager.mqh"
#include "../Include/ScalpingBot/TradeExecutor.mqh"
#include "../Include/ScalpingBot/PositionManager.mqh"
#include "../Include/ScalpingBot/ResistanceDetector.mqh"
#include "../Include/ScalpingBot/OrderBlockDetector.mqh"
#include "../Include/ScalpingBot/FourHourBreakout.mqh"
#include "../Include/ScalpingBot/TriangleDetector.mqh"
#define SBEvaluateTriangle SBEvaluateLegacyTriangle
#include "../Include/ScalpingBot/TriangleMethod.mqh"
#undef SBEvaluateTriangle
#include "../Include/ScalpingBot/ShapeRuntime.mqh"
void SBEvaluateTriangle(bool startup){if(InpShapeLegacyTriangle)SBEvaluateLegacyTriangle(startup);else SBEvaluateShape(startup);}
#include "../Include/ScalpingBot/OpeningRangeBreakout.mqh"
#include "../Include/ScalpingBot/SmartMoneyTrap.mqh"
#include "../Include/ScalpingBot/VolumeProfileRuntime.mqh"
bool sb_started=false,sb_recovered=false;
datetime sb_last_run=0;
bool sb_fill_pending=false;
string sb_last_warning="";
string sb_clock_key="";
int sb_deals=INVALID_HANDLE;
void SBPanel()
  {
   if(!InpShowPanel){Comment("");return;}
   double open_risk=0;bool known=SBOpenRisk(open_risk);
   datetime utc=0,day=0,midnight=0,last=0;int four=-1,triangle=-1,orb=-1;
   string mapping="",four_why="",triangle_why="",orb_why="";
   if(SBServerToUTCChecked(TimeCurrent(),utc,mapping))
     {
      if(SBNYDay(utc,day,midnight))
        {four=SBTradesTodayChecked(SB_4H,midnight,TimeCurrent(),last,four_why);triangle=SBTradesTodayChecked(SB_TRIANGLE,midnight,TimeCurrent(),last,triangle_why);orb=SBTradesTodayChecked(SB_ORB,midnight,TimeCurrent(),last,orb_why);}
      else mapping="NY_TIME_UNSUPPORTED";
     }
   if(mapping!=""){four_why=mapping;triangle_why=mapping;orb_why=mapping;}
   datetime panel_ny=0;SBNYLocal(utc,panel_ny);
   string orb_range_status=sb_orb_range.state+" "+sb_orb_range.reason;
   if(sb_orb.ready && panel_ny>=day+InpORBTradingEndNYMinutes*60)orb_range_status="SESSION_EXPIRED (range recovered; trading window ended)";
   Comment("SCALPING BOT V1.0 | ",_Symbol," | ",InpSignalOnly?"SIGNAL_ONLY":"ORDER_EXECUTION",
     "\n4H: ",InpEnable4HBreakout?"ENABLED":"DISABLED"," | ",mapping!=""?"TIMEZONE_MAPPING_UNVERIFIED "+mapping:(sb_four.invalid?"SETUP_INVALIDATED OPPOSITE_BOUNDARY":(sb_four_wait!=""?sb_four_wait:(sb_four.side!=0?"WAITING_FOR_RETURN":sb_four_range.state+" "+sb_four_range.reason))),
     " | HIGH ",DoubleToString(sb_four.high,_Digits)," LOW ",DoubleToString(sb_four.low,_Digits)," | TRADES ",SBTradeCountText(four,Inp4HMaxTradesPerNYDay,four_why),
      "\nSHAPE PATTERN: ",InpEnableTriangleMethod?"ENABLED":"DISABLED"," | ",InpShapeLegacyTriangle?"LEGACY TRIANGLE":"M15/M5 SHAPE ENGINE",
     " | A/D/S=",InpEnableAscendingTriangle?"ON":"OFF","/",InpEnableDescendingTriangle?"ON":"OFF","/",InpEnableSymmetricalTriangle?"ON":"OFF",
     " | TRADES ",SBTradeCountText(triangle,InpTriangleMaxTradesPerDay,triangle_why),
     "\nORB: ",InpEnableORBStrategy?"ENABLED":"DISABLED"," | ",mapping!=""?"TIMEZONE_MAPPING_UNVERIFIED "+mapping:(sb_orb.invalid?"SETUP_INVALIDATED":(sb_orb_wait!=""?sb_orb_wait:orb_range_status)),
     " | C/F PHASE ",sb_orb.continuation.phase,"/",sb_orb.reversal.phase," | TRADES ",SBTradeCountText(orb,InpORBMaxTradesPerNYDay,orb_why),
     "\nSMT: ",InpEnableSMTStrategy?SBSMTProfileName():"DISABLED"," | TREND ",SBSMTTrendName(sb_smt.trend)," TF ",(int)InpSMTTrendTF,
     " | PHASE ",sb_smt.candidate.phase," | ",sb_smt.candidate.reason,
     "\nVOLUME PROFILE: ",InpEnableVolumeProfile?"ENABLED":"DISABLED"," | ",sb_vp_profile.valid?sb_vp_profile.id:sb_vp_profile_wait,
     " | M1/M2/M3 ",sb_vp_methods[0].phase,"/",sb_vp_methods[1].phase,"/",sb_vp_methods[2].phase,
     "\nTOTAL ACCOUNT POSITIONS ",PositionsTotal(),"/",InpMaxTotalOpenPositions," | OPEN RISK ",known?DoubleToString(open_risk,2):"UNKNOWN",
     "\n",!sb_state_ok?"STATE FAILURE":(SBGet(sb_account+"halt")!=0?"EMERGENCY LOCK":(!InpEnableDailyRiskLock?"DAILY RISK LOCK DISABLED":(SBGet(sb_account+"daily_lock")!=0?"DAILY LOCK":"Risk monitoring active"))),
     "\nCLOCK: ",SBBrokerClockText(TimeCurrent()),"\n",sb_status);
  }
void SBRun()
  {
   if(!sb_started)return;
   datetime now=TimeCurrent();
   if(InpEnableVolumeProfile)SBVPDrawProfile();
   if(now==sb_last_run && !sb_fill_pending)return;
   int mutex=SBAccountMutex();if(mutex==INVALID_HANDLE)return;
   sb_last_run=now;sb_fill_pending=false;
   MqlTick q;datetime utc;string why="";
   bool ready=SBFreshQuote(q,utc,why);
   if(ready)
     {
      datetime clock_day=0,clock_midnight=0;
      if(SBNYDay(utc,clock_day,clock_midnight))
        {
         string key=IntegerToString((long)clock_day)+"|"+IntegerToString(SBBrokerOffset(utc))+"|"+IntegerToString(SBUSDST(utc)?1:0);
         if(key!=sb_clock_key){SBEvent(SB_4H,"TIME_MAPPING_OK",SBBrokerClockText(now));sb_clock_key=key;}
        }
     }
   if(ready)
     {
      ready=SBUpdateAccount(utc);
      if(!ready)why="ACCOUNT_STATE_INVALID_OR_OTHER_INSTANCE_RISK_SETTINGS_DIFFER";
     }
   // Existing broker SL/TP remain active, even while clock/data prevents new decisions.
   if(ready)
     {
      SBManagePositions();
      if(!sb_recovered)
        {
         if(sb_signal_after==0)sb_signal_after=TimeCurrent();
         if(SBLedgerReconcile() && SBRecoverConsumedHistory())
           {
            SBEvaluate4H(utc,true);SBEvaluateTriangle(true);SBEvaluateORB(utc,true);SBEvaluateSMT(true);SBEvaluateVP(true);sb_recovered=true;
            SBEvent(SB_4H,"RECOVERY_COMPLETE","Completed bars replayed without historical entries; strategies ready independently");
           }
         else why="DEAL_HISTORY_UNAVAILABLE";
        }
      else
        {
         // Stable priority: 4H first; reconcile actual exposure before triangle checks.
         SBEvaluate4H(utc,false);SBManagePositions();SBEvaluateTriangle(false);SBManagePositions();SBEvaluateORB(utc,false);SBManagePositions();SBEvaluateSMT(false);SBManagePositions();SBEvaluateVP(false);SBManagePositions();
        }
     }
   if(why!="" && why!=sb_last_warning){SBEvent(SB_4H,"WAIT",why);sb_last_warning=why;}
   if(ready && why=="")sb_last_warning="";
   SBPanel();FileClose(mutex);
  }
int OnInit()
  {
   Print("SCALPING BOT | SETUP_EXIT_POLICY | Shape=",InpShapeSetupBasedExits?"STRUCTURAL_ANY_POSITIVE_NET_REWARD":"EXISTING_LIMITS",
    " SMT=",InpSMTSetupBasedExits?"STRUCTURAL_ANY_POSITIVE_NET_REWARD":"EXISTING_LIMITS",
    " | Enabled mode ignores minimum RR and fixed point stop caps for that strategy; money-risk, sizing, broker and confirmation checks remain active");
   Print("SCALPING BOT | DAILY_RISK_POLICY | daily_baseline_and_loss_lock=",InpEnableDailyRiskLock?"ENABLED":"DISABLED_BY_INPUT",
    " | Max drawdown, emergency, per-trade/open-risk limits and strategy entry caps remain active");
   string mapping_error="";
   if(!SBMappingConfigValid(mapping_error)){Print("SCALPING BOT | TIME_MAPPING_CONFIG_INVALID | ",mapping_error);return INIT_PARAMETERS_INCORRECT;}
   Print("SCALPING BOT | TIME_MAPPING_CONFIG | account_server=",AccountInfoString(ACCOUNT_SERVER)," rule=",EnumToString(InpBrokerDSTRule),
    " verified=",InpBrokerTimeVerified," winter_minutes=",InpBrokerWinterUTCMinutes," summer_minutes=",InpBrokerSummerUTCMinutes,
    " coverage_UTC=[",TimeToString(InpBrokerMappingFromUTC,TIME_DATE|TIME_MINUTES),",",TimeToString(InpBrokerMappingUntilUTC,TIME_DATE|TIME_MINUTES),") table_rows=",ArraySize(sb_mapping_starts),
    " | Historical offsets must be verified externally; tester/PC clocks are not timezone evidence");
   if(!SBValidInputs() || !SBValidShapeInputs() || !SBValidORBInputs() || (InpEnableSMTStrategy && !SBValidSMTInputs()))return INIT_PARAMETERS_INCORRECT;
   if(InpEnableVolumeProfile && (!SBValidVPInputs() || !SBVPBinCompatible(InpVPBinSize,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)) ||
      (InpVPRequireXAUUSD && StringFind(_Symbol,"XAUUSD")<0)))return INIT_PARAMETERS_INCORRECT;
   if(!SymbolSelect(_Symbol,true) || _Point<=0 || SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)<=0 ||
      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)<=0)return INIT_FAILED;
   if(!SBInitPersistence())
     {Print("SCALPING BOT | INIT_FAILED | Same-symbol magic controller already active or state folder unavailable");return INIT_FAILED;}
   if(!SBInitLog())return INIT_FAILED;
   if(!SBLedgerInit()){Print("Durable lifecycle ledger unavailable or malformed");return INIT_FAILED;}
   if(InpEnableVolumeProfile && !SBVPInitDiagnostics())return INIT_FAILED;
   if(InpCSVLogging)
     {
      string file="ScalpingBot\\"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+IntegerToString((long)Inp4HMagicNumber)+"_"+IntegerToString((long)InpTriangleMagicNumber)+"_"+IntegerToString((long)InpORBMagicNumber)+"_deals.csv";
      if(InpEnableSMTStrategy)StringReplace(file,"_deals.csv","_"+IntegerToString((long)InpSMTMagicNumber)+"_deals.csv");
      if(MQLInfoInteger(MQL_TESTER) && FileIsExist(file) && !FileDelete(file))return INIT_FAILED;
      sb_deals=FileOpen(file,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
      if(sb_deals==INVALID_HANDLE)return INIT_FAILED;
      if(FileSize(sb_deals)==0)FileWrite(sb_deals,"server_time","symbol","strategy","magic","position_id","order","deal","entry_type","direction","volume","price","profit","commission","swap","fee","spread_points","slippage_points","initial_risk","comment");
      FileSeek(sb_deals,0,SEEK_END);
     }
   PrintFormat("SCALPING BOT | SYMBOL | %s digits=%d point=%.8f tick=%.8f tickValue=%.8f contract=%.2f volumeMin=%.4f max=%.4f step=%.4f stops=%d freeze=%d execution=%d fill=%d",
      _Symbol,_Digits,_Point,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE),
      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),
      (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL),
      (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE),(int)SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE));
   Print("SCALPING BOT | ACCOUNT | ",AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING?"HEDGING: separate strategy positions":"NETTING: new same-symbol position blocked to prevent merging");
   if(!EventSetTimer(1))return INIT_FAILED;
   sb_started=true;SBRun();return INIT_SUCCEEDED;
  }
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {if(id==CHARTEVENT_CHART_CHANGE && sb_started && InpEnableVolumeProfile)SBVPDrawProfile(true);}
void OnTick(){SBRun();}
void OnTimer(){SBRun();}
void OnDeinit(const int reason)
  {
   EventKillTimer();if(sb_log!=INVALID_HANDLE)FileClose(sb_log);if(sb_deals!=INVALID_HANDLE)FileClose(sb_deals);
   if(sb_ledger!=INVALID_HANDLE)FileClose(sb_ledger);
   if(sb_vp_signals!=INVALID_HANDLE)FileClose(sb_vp_signals);if(sb_vp_profiles!=INVALID_HANDLE)FileClose(sb_vp_profiles);
   for(int i=0;i<4;i++)if(sb_owner_vp[i]!=INVALID_HANDLE)FileClose(sb_owner_vp[i]);
   if(sb_owner4!=INVALID_HANDLE)FileClose(sb_owner4);if(sb_owner_triangle!=INVALID_HANDLE)FileClose(sb_owner_triangle);
   if(sb_owner_orb!=INVALID_HANDLE)FileClose(sb_owner_orb);
   if(sb_owner_smt!=INVALID_HANDLE)FileClose(sb_owner_smt);
   if(StringLen(sb_object_prefix)>0)ObjectsDeleteAll(0,sb_object_prefix);Comment("");
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || !HistoryDealSelect(trans.deal))return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol)return;
   // Resolve exits by durable position identifier even if broker exit magic/comment differs.
   if(SBLedgerRelation((ulong)HistoryDealGetInteger(trans.deal,DEAL_ORDER),(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID))>=0 && !SBLedgerDeal(trans.deal))SBHalt("Cannot persist actual broker deal");
   ulong magic=(ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC);int strategy=SBStrategyFromMagic(magic);
   if(strategy==0)return;
   sb_fill_pending=true;
   long position=HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID),entry=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   ulong order=(ulong)HistoryDealGetInteger(trans.deal,DEAL_ORDER);
   int direction=HistoryDealGetInteger(trans.deal,DEAL_TYPE)==DEAL_TYPE_BUY?1:-1;
   double price=HistoryDealGetDouble(trans.deal,DEAL_PRICE),volume=HistoryDealGetDouble(trans.deal,DEAL_VOLUME),risk=0;
   string id=IntegerToString(position),comment=HistoryDealGetString(trans.deal,DEAL_COMMENT);
   double expected=SBGet(SBStrategyKey(strategy,"E"+IntegerToString((long)order))),slippage=expected>0?direction*(price-expected)/_Point:0;
   if(entry==DEAL_ENTRY_IN)
     {
      SBPut(SBStrategyKey(strategy,"F"+IntegerToString((long)order)),1);
      double sl=0;
      for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)>0 && PositionGetInteger(POSITION_IDENTIFIER)==position){sl=PositionGetDouble(POSITION_SL);break;}
      double pnl;if(sl>0 && OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,price,sl,pnl))risk=MathMax(0,-pnl)+volume*InpRoundTripCommissionPerLot;
      SBPut(SBStrategyKey(strategy,"R"+id),SBGet(SBStrategyKey(strategy,"R"+id))+risk);
     }
   else risk=SBGet(SBStrategyKey(strategy,"R"+id));
   double spread=0;MqlTick q;if(SymbolInfoTick(_Symbol,q))spread=(q.ask-q.bid)/_Point;
   if(sb_deals!=INVALID_HANDLE)
     {FileWrite(sb_deals,(long)HistoryDealGetInteger(trans.deal,DEAL_TIME),_Symbol,SBName(strategy),magic,position,order,trans.deal,entry,direction,volume,price,
        HistoryDealGetDouble(trans.deal,DEAL_PROFIT),HistoryDealGetDouble(trans.deal,DEAL_COMMISSION),HistoryDealGetDouble(trans.deal,DEAL_SWAP),HistoryDealGetDouble(trans.deal,DEAL_FEE),spread,slippage,risk,comment);FileFlush(sb_deals);}
   SBEvent(strategy,"DEAL",StringFormat("deal=%I64u position=%I64d entryType=%d volume=%.4f price=%.8f comment=%s",trans.deal,position,(int)entry,volume,price,comment));
   if(strategy==SB_SMT && entry==DEAL_ENTRY_IN)
     {
      double sl=0,tp=0;
      for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)>0 && PositionGetInteger(POSITION_IDENTIFIER)==position)
        {sl=PositionGetDouble(POSITION_SL);tp=PositionGetDouble(POSITION_TP);break;}
      double actual_rr=direction*(price-sl)>0?direction*(tp-price)/(direction*(price-sl)):0;
      SBEvent(SB_SMT,"SMT_FILLED_RR",StringFormat("PROFILE=%s actual_fill=%.8f SL=%.8f TP=%.8f actual_price_RR=%.6f",SBSMTProfileName(),price,sl,tp,actual_rr));
     }
  }
double OnTester()
  {
   PrintFormat("SCALPING BOT | TESTER | net=%.2f trades=%.0f PF=%.4f equityDD=%.3f%%",TesterStatistics(STAT_PROFIT),TesterStatistics(STAT_TRADES),TesterStatistics(STAT_PROFIT_FACTOR),TesterStatistics(STAT_EQUITY_DDREL_PERCENT));
   return TesterStatistics(STAT_PROFIT);
  }
