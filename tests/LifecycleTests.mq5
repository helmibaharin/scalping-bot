#property strict
#define OnInit SBLifeProductionInit
#define OnTick SBLifeProductionTick
#define OnTimer SBLifeProductionTimer
#define OnDeinit SBLifeProductionDeinit
#define OnTradeTransaction SBLifeProductionTransaction
#define OnTester SBLifeProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
// Tester-only broker integration: one 0.02-lot simulated position, two 0.01 closes.
// Does not run strategy decisions or bypass safeguards in the production EA.
int life_checks=0,life_failures=0,life_stage=0;ulong life_position=0,life_order=0;
void LifeCheck(bool ok,string reason){life_checks++;if(!ok){life_failures++;Print("LIFECYCLE_ASSERT_FAIL | ",reason);}else Print("LIFECYCLE_ASSERT_PASS | ",reason);}
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   sb_instance="SB.TEST.LIFECYCLE.";sb_account=sb_instance+"R.";GlobalVariablesDeleteAll(sb_instance);
   LifeCheck(SBLedgerInit(),"durable journal open");return life_failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
bool LifeClose(ulong ticket,double volume)
  {
   MqlTick q;if(!SymbolInfoTick(_Symbol,q))return false;
   MqlTradeRequest r={};MqlTradeResult result={};r.action=TRADE_ACTION_DEAL;r.symbol=_Symbol;r.position=ticket;r.magic=InpTriangleMagicNumber;r.type=ORDER_TYPE_SELL;r.volume=volume;r.price=q.bid;r.deviation=20;r.comment="unrelated broker text";
   if(!SBFilling(r.type_filling))return false;
   return OrderSend(r,result) && (result.retcode==TRADE_RETCODE_DONE || result.retcode==TRADE_RETCODE_DONE_PARTIAL);
  }
void OnTick()
  {
   if(life_failures>0 || life_stage>=4)return;
   if(life_stage==0)
     {
      MqlTick q;if(!SymbolInfoTick(_Symbol,q))return;
      double distance=MathMax(100*_Point,2*(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point);
      SBPlan p={};p.signal.strategy=SB_TRIANGLE;p.signal.direction=1;p.signal.id="native-broker-lifecycle";p.signal.pattern_id="native-pattern";p.signal.family="DOUBLE_BOTTOM";p.signal.subtype="DOUBLE_BOTTOM";p.signal.method="TRAP_REVERSAL";p.signal.candle=q.time;p.signal.rr=2;p.signal.max_stop_points=10000;
      p.magic=InpTriangleMagicNumber;p.entry=q.ask;p.sl=q.bid-distance;p.tp=q.ask+distance*100;p.volume=.02;p.spread=(q.ask-q.bid)/_Point;
      double pnl=0;if(!OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,p.volume,p.entry,p.sl,pnl)){LifeCheck(false,"planned risk calculator available");return;}p.risk=-pnl;
      int k=SBLedgerPlan(p,"REQUEST","NATIVE_TESTER_ONLY");LifeCheck(k>=0,"metadata durable before simulated send");if(k<0)return;
      MqlTradeRequest r={};MqlTradeResult result={};r.action=TRADE_ACTION_DEAL;r.symbol=_Symbol;r.magic=p.magic;r.type=ORDER_TYPE_BUY;r.volume=p.volume;r.price=p.entry;r.sl=p.sl;r.tp=p.tp;r.deviation=20;r.comment="no signal identifier";
      if(!SBFilling(r.type_filling)){LifeCheck(false,"broker filling available");return;}
      bool ok=OrderSend(r,result);LifeCheck(ok && (result.retcode==TRADE_RETCODE_DONE || result.retcode==TRADE_RETCODE_DONE_PARTIAL),"simulated order accepted");
      LifeCheck(SBLedgerResult(k,result),"accepted order relation journaled");life_order=result.order;
      LifeCheck(ArraySize(sb_ledger_seen)==0,"accepted request does not fabricate a fill callback");life_stage=1;return;
     }
   ulong ticket=0;
   for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if((ulong)PositionGetInteger(POSITION_MAGIC)==InpTriangleMagicNumber){ticket=t;life_position=(ulong)PositionGetInteger(POSITION_IDENTIFIER);break;}}
   if(life_stage==1)
     {
      if(ticket==0 || SBLedgerRelation(0,life_position)<0)return;
      LifeCheck(ArraySize(sb_ledger_seen)>=1,"actual OnTradeTransaction linked entry without comment");
      LifeCheck(LifeClose(ticket,.01),"first simulated partial close");life_stage=2;return;
     }
   if(life_stage==2)
     {
      if(ticket==0 || PositionGetDouble(POSITION_VOLUME)>.0100001)return;
      LifeCheck(LifeClose(ticket,.01),"final simulated close");life_stage=3;return;
     }
   if(life_stage==3)
     {
      if(ticket!=0 || ArraySize(sb_ledger_seen)<3)return;
      LifeCheck(SBLedgerRelation(life_order,life_position)>=0,"entry and two exits preserve one position identity");
      int before=ArraySize(sb_ledger_seen);long bytes=(long)FileSize(sb_ledger);
      LifeCheck(SBLedgerReconcile() && ArraySize(sb_ledger_seen)==before && (long)FileSize(sb_ledger)==bytes,"history replay does not duplicate deals");
      FileClose(sb_ledger);sb_ledger=INVALID_HANDLE;ArrayResize(sb_ledger_meta,0);ArrayResize(sb_ledger_seen,0);
      LifeCheck(SBLedgerInit(false),"restart reload of actual broker transactions");
      int k=SBLedgerRelation(life_order,life_position);
      LifeCheck(k>=0 && ArraySize(sb_ledger_seen)==before,"persistent order/deal/position mappings restored");
      LifeCheck(SBLedgerReconcile() && ArraySize(sb_ledger_seen)==before,"restart history reconciliation idempotent");
      if(k>=0)LifeCheck(sb_ledger_meta[k].plan.signal.subtype=="DOUBLE_BOTTOM" && sb_ledger_meta[k].plan.risk>0,"original planned risk and pattern retained");
      life_stage=4;PrintFormat("LIFECYCLE_TEST_RESULT | checks=%d failures=%d complete=%d",life_checks,life_failures,life_stage==4);
     }
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result){SBLifeProductionTransaction(trans,request,result);}
void OnDeinit(const int reason){if(sb_ledger!=INVALID_HANDLE)FileClose(sb_ledger);GlobalVariablesDeleteAll(sb_instance);}
double OnTester(){PrintFormat("LIFECYCLE_TEST_RESULT | checks=%d failures=%d complete=%d",life_checks,life_failures,life_stage==4);return life_failures==0 && life_stage==4?life_checks:-1;}
