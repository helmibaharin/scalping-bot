#property strict
#define OnInit SBTimingProductionInit
#define OnTick SBTimingProductionTick
#define OnTimer SBTimingProductionTimer
#define OnDeinit SBTimingProductionDeinit
#define OnTradeTransaction SBTimingProductionTransaction
#define OnTester SBTimingProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int timing_checks=0,timing_failures=0;bool context_checked=false;
void TimingCheck(bool ok,string reason)
  {timing_checks++;if(!ok)timing_failures++;Print(ok?"DECISION_TIMING_PASS | ":"DECISION_TIMING_FAIL | ",reason);}
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   sb_instance="SB.TEST.DECISION.TIMING.";sb_account=sb_instance+"R.";sb_object_prefix=sb_instance;
   GlobalVariablesDeleteAll(sb_instance);sb_state_ok=true;
   // Every actual executor path must return in this call without deferring to a tick.
   // Persisted duplicate signals guarantee these checks cannot send broker orders.
   for(int strategy=1;strategy<=7;strategy++)
     {
      SBSignal signal={};signal.strategy=strategy;signal.id="timing-duplicate";
      signal.candle=TimeCurrent()-SBSignalSeconds(strategy);
      TimingCheck(SBConsume(strategy,signal.id),"fixture duplicate persisted "+IntegerToString(strategy));
      SBExecute(signal);
      TimingCheck(sb_execution_result==-1 && sb_execution_reason=="DUPLICATE_SUPPRESSED" &&
        sb_execution_presend_us==-1 && sb_execution_broker_us==-1,"executor returns an immediate disposition for strategy/method "+IntegerToString(strategy));
     }
   int side=0;double extreme=0;
   TimingCheck(SB4HStep(side,extreme,109,113,108,112,90,110,.01)==1,"S1 completed breakout starts observation immediately");
   TimingCheck(SB4HStep(side,extreme,112,114,105,108,90,110,.01)==3,"S1 completed return is ready without another candle");
   sb_started=true;sb_vp_draw_check=TimeCurrent()+30;sb_vp_draw_status="TIMING_SENTINEL";
   long chart_long=0;double chart_double=0;string chart_text="";
   OnChartEvent(CHARTEVENT_CHART_CHANGE,chart_long,chart_double,chart_text);
   TimingCheck(sb_vp_draw_status=="TIMING_SENTINEL" && sb_vp_draw_check==TimeCurrent()+30,
     "chart-change callback respects redraw throttle instead of recursively forcing redraw");
   sb_started=false;
   return timing_failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick()
  {
   if(context_checked)return;
   datetime closed=iTime(_Symbol,PERIOD_M5,1),decision=closed+300;
   if(closed<=0 || decision>TimeCurrent() || (long)decision%3600!=0)return;
   MqlRates at_open[],at_close[];
   if(!SBShapeLoad(PERIOD_H1,closed,240,at_open) || !SBShapeLoad(PERIOD_H1,decision,240,at_close))return;
   TimingCheck(at_close[ArraySize(at_close)-1].time+3600==decision,"close-time context includes H1 candle that has just completed");
   TimingCheck(at_open[ArraySize(at_open)-1].time+3600==decision-3600,"old open-time context unnecessarily withholds that H1 candle");
   bool future=false;for(int i=0;i<ArraySize(at_close);i++)if(at_close[i].time+3600>decision)future=true;
   TimingCheck(!future,"context cutoff never exposes an unfinished or future candle");
   context_checked=true;
  }
void OnDeinit(const int reason){GlobalVariablesDeleteAll(sb_instance);}
double OnTester()
  {
   TimingCheck(context_checked,"historical H1/M5 boundary was exercised");
   TimingCheck(OrdersTotal()==0 && PositionsTotal()==0,"timing fixture never places trades");
   PrintFormat("DECISION_TIMING_TEST_RESULT | checks=%d failures=%d context=%d",timing_checks,timing_failures,context_checked);
   return timing_failures==0 && context_checked?timing_checks:-1;
  }
