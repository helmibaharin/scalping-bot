#property strict
#include "../MQL5/Include/ScalpingBot/Config.mqh"
bool test_shape=false,test_smt=false,test_verified=true;
int test_offset=180;
SB_BROKER_DST test_rule=SB_FIXED;
#define InpShapeSetupBasedExits test_shape
#define InpSMTSetupBasedExits test_smt
#define InpBrokerTimeVerified test_verified
#define InpBrokerDSTRule test_rule
#define InpBrokerWinterUTCMinutes test_offset
#define InpBrokerSummerUTCMinutes test_offset
#define OnInit SBSetupProductionInit
#define OnTick SBSetupProductionTick
#define OnTimer SBSetupProductionTimer
#define OnDeinit SBSetupProductionDeinit
#define OnTradeTransaction SBSetupProductionTransaction
#define OnTester SBSetupProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int checks=0,failures=0,stage=0;
double shape_tp=0,smt_tp=0;datetime recheck=0;
void Check(bool ok,string why){checks++;Print(ok?"SETUP_EXIT_ASSERT_PASS | ":"SETUP_EXIT_ASSERT_FAIL | ",why);if(!ok)failures++;}
void UnitSuite()
  {
   SBSignal s={};s.strategy=SB_TRIANGLE;s.method="BREAKOUT_CONTINUATION";s.pattern_type=1;s.direction=1;s.target=101;
   Check(!SBSetupBasedExits(SB_TRIANGLE,s.method) && !SBSetupBasedExits(SB_SMT),"defaults preserve existing exit policies");
   test_shape=true;test_smt=true;
   Check(SBSetupBasedExits(SB_TRIANGLE,s.method) && SBSetupBasedExits(SB_SMT),"only Shape and SMT opt into setup exits");
   Check(!SBSetupBasedExits(SB_4H) && !SBSetupBasedExits(SB_ORB) && !SBSetupBasedExits(SB_VP_POC) && !SBSetupBasedExits(SB_TRIANGLE),"other strategies and legacy triangle do not opt in");
   double tp=0;string why="";
   for(int type=1;type<=11;type++)
     {
      s.pattern_type=type;s.method="BREAKOUT_CONTINUATION";s.target=101;
      Check(SBShapeDynamic(s) && SBShapePlanGeometry(s,100,90,tp,why) && tp==101,"native measured target below 1R for Shape pattern "+IntegerToString(type));
     }
   s.direction=-1;s.target=99;Check(SBShapePlanGeometry(s,100,110,tp,why) && tp==99,"native SELL measured target below 1R");
   s.target=101;Check(!SBShapePlanGeometry(s,100,110,tp,why),"SELL wrong-side target rejected");
   ArrayResize(sb_shape_levels,0);SBShapeLevelAdd(101.05,1,TimeCurrent()-60,TimeCurrent()-120,"FIXTURE_NEAREST_HIGH");
   s.direction=1;s.method="TRAP_REVERSAL";
   Check(SBShapePlanGeometry(s,100,90,tp,why) && MathAbs(tp-101)<=.01,"native reversal keeps nearest structural target below 1R");
   ArrayResize(sb_shape_levels,0);Check(!SBShapePlanGeometry(s,100,90,tp,why),"missing structural target still blocks entry");
   test_shape=false;s.method="BREAKOUT_CONTINUATION";s.target=101;s.pattern_type=11;
   Check(!SBShapePlanGeometry(s,100,90,tp,why),"mode off restores original continuation minimum");test_shape=true;
   double rr=0;
   Check(SBSMTRRAllows(100,90,101,1,false,InpSMTMinimumRR,rr) && MathAbs(rr-.1)<1e-9,"native SMT geometry accepts positive 0.1R");
   Check(SBSMTFilledRRValid(100,90,101,1,1,10,false,1),"native SMT fill accepts positive sub-1R");
   Check(!SBSMTFilledRRValid(100,90,101,1,-1,10,false,1),"native SMT fill rejects negative net reward");
   Check(!SBSMTRRAllows(100,90,101,1,true,1,rr),"mode off retains original SMT minimum");
   SBSMTLocation zones[];SBSMTAddLocation(zones,SMT_SUPPLY,PERIOD_H1,-1,102,101.05,TimeCurrent()-120,TimeCurrent()-60);
   string id;
   Check(SBSMTSelectTarget(1,100,zones,TimeCurrent(),.05,.01,tp,id) && MathAbs(tp-101)<=.01,"native SMT selects nearby opposing zone without manufacturing reward");
   Check(SBRecordedSetupExits(SB_TRIANGLE,"SHAPE_M15_M5",0) && SBRecordedSetupExits(SB_SMT,"SMT_MTF",0),"durable marker identifies opted-in requests");
   Check(!SBRecordedSetupExits(SB_TRIANGLE,"LEGACY_TRIANGLE",0) && !SBRecordedSetupExits(SB_4H,"DEFAULT",0) && !SBRecordedSetupExits(SB_SMT,"SMT_MTF",3000),"old and unrelated requests retain original reconciliation");
  }
bool SendPlan(SBPlan &p)
  {
   int k=SBLedgerPlan(p,"REQUEST","TESTER_ONLY_SYNTHETIC_GEOMETRY");if(k<0)return false;
   MqlTradeRequest r={};MqlTradeResult result={};r.action=TRADE_ACTION_DEAL;r.symbol=_Symbol;r.magic=p.magic;r.volume=p.volume;
   r.type=p.signal.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;r.price=p.entry;r.sl=p.sl;r.tp=p.tp;r.deviation=50;
   if(!SBFilling(r.type_filling))return false;
   bool sent=OrderSend(r,result);if(!SBLedgerResult(k,result))return false;
   return sent && result.retcode==TRADE_RETCODE_DONE;
  }
bool NativePlanning()
  {
   MqlTick q;if(!SymbolInfoTick(_Symbol,q))return false;
   datetime closed=iTime(_Symbol,PERIOD_M5,1);if(closed<=0 || TimeCurrent()-closed-300>60)return false;
   SBSignal s={};s.strategy=SB_TRIANGLE;s.direction=1;s.method="BREAKOUT_CONTINUATION";s.family="TRIANGLE";s.pattern_type=1;s.id="native-setup-shape";s.candle=closed;
   s.structural_sl=q.ask-13.14;s.target=q.ask+2;s.max_stop_points=InpTriangleMaxStopPoints;s.rr=2;
   SBPlan p={};string why;
   test_shape=false;Check(!SBPlanTrade(s,p,why) && why=="STOP_DISTANCE_OR_RR_INVALID","actual XAUUSD planner rejects 13.14 stop under old Shape point ceiling");test_shape=true;
   bool ok=SBPlanTrade(s,p,why);
   Check(ok,"actual XAUUSD planner accepts structural stop/target: "+why);if(!ok)return false;
   Check(p.signal.rr>0 && p.signal.rr<1 && p.signal.max_stop_points==0 && p.risk<=AccountInfoDouble(ACCOUNT_EQUITY)*InpMaxTradeRiskPercent/100,"actual plan persists sub-1R policy with bounded money risk");
   shape_tp=p.tp;Check(SendPlan(p),"tester-only native Shape structural order accepted");
   // SMT geometry/context gating is covered by SMTTests and the production risk adapter.
   // This manual tester plan isolates its native post-fill/restart management with a valid nearby target.
   ZeroMemory(p);p.signal.strategy=SB_SMT;p.signal.direction=1;p.signal.id="native-setup-smt";p.signal.candle=closed;p.signal.max_stop_points=0;
   p.magic=InpSMTMagicNumber;p.entry=q.ask;p.sl=SBRoundPrice(q.ask-40,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),-1);p.tp=SBRoundPrice(q.ask+2,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),-1);
   p.signal.rr=(p.tp-p.entry)/(p.entry-p.sl);p.volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double pnl=0;if(!OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,p.volume,p.entry,p.sl,pnl)){Check(false,"native risk calculation available");return false;}p.risk=-pnl;
   // Keep actual monetary risk below the production cap, without changing its value.
   if(p.risk>AccountInfoDouble(ACCOUNT_EQUITY)*InpMaxTradeRiskPercent/100){Check(false,"fixture account equity sufficient for broker minimum lot");return false;}
   smt_tp=p.tp;Check(SendPlan(p),"tester-only native SMT wide-stop/sub-1R order accepted");
   return true;
  }
void VerifyPositions(string prefix)
  {
   SBManagePositions();Check(SBGet(sb_account+"halt")==0,"no emergency halt on valid structural positions "+prefix);
   Check(SBOwnPositions(SB_TRIANGLE)==1 && SBOwnPositions(SB_SMT)==1,"both strategy positions retained independently "+prefix);
   for(int i=0;i<PositionsTotal();i++)
     {
      if(PositionGetTicket(i)==0)continue;int strategy=0;if(!SBOwnSelected(strategy))continue;
      double tp=PositionGetDouble(POSITION_TP);Check(MathAbs(tp-(strategy==SB_SMT?smt_tp:shape_tp))<.001,"structural target remains unchanged without outward fixed-R repair "+prefix);
      int metadata=SBLedgerRelation(0,(ulong)PositionGetInteger(POSITION_IDENTIFIER));
      Check(metadata>=0 && SBRecordedSetupExits(strategy,sb_ledger_meta[metadata].profile,sb_ledger_meta[metadata].plan.signal.max_stop_points),"position policy resolved from original durable request "+prefix);
     }
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   sb_instance="SB.TEST.SETUP_EXITS.";sb_account=sb_instance+"R.";sb_object_prefix=sb_instance;
   GlobalVariablesDeleteAll(sb_instance);sb_signal_after=0;
   UnitSuite();Check(SBLedgerInit(),"native journal available");
   return failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick()
  {
   if(failures>0 || stage==2)return;
   MqlDateTime now;TimeToStruct(TimeCurrent(),now);if(now.hour<12)return;
   if(stage==0)
     {
      if(!NativePlanning())return;
      stage=1;recheck=TimeCurrent()+1;return;
     }
   if(TimeCurrent()<recheck)return;
   Check(SBLedgerReconcile(),"broker fills reconciled by order and position");VerifyPositions("before restart");
   FileClose(sb_ledger);sb_ledger=INVALID_HANDLE;ArrayResize(sb_ledger_meta,0);ArrayResize(sb_ledger_seen,0);
   Check(SBLedgerInit(false) && SBLedgerReconcile(),"journal reload and reconciliation after restart");
   test_shape=false;test_smt=false;VerifyPositions("after restart and input disable");
   // Even a recorded unrestricted-distance request cannot waive monetary risk.
   SBPut(sb_account+"halt",0);ulong shape_ticket=0;
   for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)>0 && (ulong)PositionGetInteger(POSITION_MAGIC)==InpTriangleMagicNumber){shape_ticket=PositionGetTicket(i);break;}
   if(shape_ticket>0)
     {
      MqlTradeRequest r={};MqlTradeResult result={};r.action=TRADE_ACTION_SLTP;r.position=shape_ticket;r.symbol=_Symbol;r.magic=InpTriangleMagicNumber;
      r.sl=SBRoundPrice(PositionGetDouble(POSITION_PRICE_OPEN)-100,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),-1);r.tp=shape_tp;
      Check(OrderSend(r,result) && result.retcode==TRADE_RETCODE_DONE,"tester-only excessive-risk stop installed to exercise safety check");
      SBManagePositions();Check(SBGet(sb_account+"halt")==1,"recorded setup mode still latches emergency on excessive actual-fill money risk");
     }
   stage=2;PrintFormat("SETUP_EXIT_TEST_RESULT | checks=%d failures=%d complete=%d",checks,failures,stage==2);
  }
void OnDeinit(const int reason){if(sb_ledger!=INVALID_HANDLE)FileClose(sb_ledger);ObjectsDeleteAll(0,sb_object_prefix);GlobalVariablesDeleteAll(sb_instance);}
double OnTester(){PrintFormat("SETUP_EXIT_TEST_RESULT | checks=%d failures=%d complete=%d",checks,failures,stage==2);return failures==0 && stage==2?checks:-1;}
