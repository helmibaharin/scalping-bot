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
int checks=0,failures=0;bool checked_boundary=false,checked_screenshot=false;
datetime last_closed=0;
void Check(bool ok,string reason){checks++;Print(ok?"SHAPE_TIMING_ASSERT_PASS | ":"SHAPE_TIMING_ASSERT_FAIL | ",reason);if(!ok)failures++;}
void Bar(MqlRates &b,datetime time,double o,double h,double l,double close)
  {ZeroMemory(b);b.time=time;b.open=o;b.high=h;b.low=l;b.close=close;}
void Candidate(SBShapeCandidate &c,datetime known)
  {
   ZeroMemory(c);c.phase=SH_WAIT_BREAKOUT;c.pattern.type=SH_SYMMETRICAL;c.pattern.id="timing-fixture";
   c.pattern.known=known;c.available=known;c.pattern.first=known-6*3600;c.pattern.formed=known-2700;c.pattern.atr=2;
   c.pattern.u1=known-3600;c.pattern.u2=known;c.pattern.up1=110;c.pattern.up2=110;
   c.pattern.l1=known-3600;c.pattern.l2=known;c.pattern.lo1=90;c.pattern.lo2=90;
  }
void ClosingBreakout(int dir)
  {
   datetime known=D'2026.11.02 13:15';SBShapeCandidate c,old;Candidate(c,known);old=c;SBORBBreak event={};
   MqlRates b,previous;Bar(previous,known-600,100,105,95,100);
   if(dir>0)Bar(b,known-300,108,113,107,112);else Bar(b,known-300,92,93,87,88);
   SBShapeStep(old,b,previous,event,0,300);Check(old.phase==SH_WAIT_BREAKOUT,"control: old open-time gate misses confirmation-close breakout");
   SBShapeDecisionStep(c,b,previous,event,0,300);
   Check(c.phase==SH_WAIT_RETEST && c.direction==dir && c.evaluated_close==known,"new decision accepts fresh confirmed closing breakout immediately, direction="+IntegerToString(dir));
   Check(c.retest==0 && c.trap==0 && c.classification==BREAKOUT_HOLDING,"confirmation close cannot also be a retest, reversal or entry");
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.retest==0 && c.evaluated_close==known,"same completed close is idempotent");
   previous=b;
   if(dir>0)Bar(b,known,111,112,110,111);else Bar(b,known,89,90,88,89);
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.phase==SH_WAIT_RETEST && c.retest==known,"later completed retest still required");
   previous=b;
   if(dir>0)Bar(b,known+300,111,115,111,114);else Bar(b,known+300,89,89,85,86);
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.phase==SH_CONTINUATION_READY,"entry readiness still requires a separate subsequent continuation close");
  }
void UnitSuite()
  {
   ClosingBreakout(1);ClosingBreakout(-1);
   datetime known=D'2026.11.02 13:15';SBShapeCandidate c;SBORBBreak event={};MqlRates b,previous;
   Bar(previous,known-900,100,105,95,100);Bar(b,known-600,108,113,107,112);Candidate(c,known);
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.phase==SH_WAIT_BREAKOUT && c.evaluated_close==0,"confirmation is never advanced by a future M15 candle");
   Candidate(c,known);Bar(previous,known-600,100,105,95,100);Bar(b,known-300,108,113,99,100);
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.trap==0 && c.phase==SH_WAIT_BREAKOUT,"pre-availability intrabar wick cannot become a sweep/reversal signal");
   Candidate(c,known);Bar(previous,known-600,111,113,110,112);Bar(b,known-300,112,114,111,113);
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.phase==SH_WAIT_BREAKOUT,"already completed earlier breakout is not chased");
   Candidate(c,known);c.available=known+300;Bar(previous,known-600,100,105,95,100);Bar(b,known-300,108,113,107,112);
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.phase==SH_WAIT_BREAKOUT && c.evaluated_close==0,"first discovery timestamp cannot be backdated");
   Candidate(c,known);c.pattern.known=known-900;Bar(b,known-300,108,113,107,112);
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.phase==SH_WAIT_BREAKOUT,"late recognition of an old pattern cannot reinterpret a past excursion");
   Candidate(c,known);c.pattern.direction=-1;Bar(b,known-300,108,113,107,112);
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.phase==SH_WAIT_BREAKOUT,"direction restrictions preserved at confirmation close");
   Candidate(c,known);Bar(b,known-300,111.9,112.1,111.8,112);
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.phase==SH_WAIT_BREAKOUT,"insufficient directional body still rejects closing breakout");
   Candidate(c,known);Bar(previous,known-900,100,105,95,100);Bar(b,known-300,108,113,107,112);
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.phase==SH_WAIT_BREAKOUT,"missing preceding M5 candle cannot confirm the closing crossing");
   Candidate(c,known);c.pattern.up1=106;c.pattern.up2=112;Bar(previous,known-600,100,105,95,100);Bar(b,known-300,108,112,107,111.8);
   SBShapeDecisionStep(c,b,previous,event,0,300);Check(c.phase==SH_WAIT_BREAKOUT,"sloping boundary evaluated at actual decision close, not its older price");
   MqlRates formation[];ArrayResize(formation,5);for(int i=0;i<5;i++)Bar(formation[i],known-4500+i*900,100,110,99,100);formation[2].low=90;
   SBShapePivot pivots[];SBShapePivots(formation,3,900,pivots);bool early=false;
   for(int i=0;i<ArraySize(pivots);i++)if(pivots[i].time==known-2700 && pivots[i].side==-1)early=true;
   Check(!early,"right-hand M15 confirmation remains unavailable before second right candle completes");
   SBShapePivots(formation,4,900,pivots);bool timely=false;
   for(int i=0;i<ArraySize(pivots);i++)if(pivots[i].time==known-2700 && pivots[i].side==-1 && pivots[i].known==known)timely=true;
   Check(timely,"12:30 M15 swing is confirmed exactly at 13:15");
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   sb_instance="SB.TEST.SHAPE_TIMING.";sb_account=sb_instance+"R.";sb_object_prefix=sb_instance;
   GlobalVariablesDeleteAll(sb_instance);sb_signal_after=TimeCurrent();UnitSuite();
   PrintFormat("SHAPE_TIMING_UNIT_RESULT | checks=%d failures=%d",checks,failures);
   return failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick()
  {
   datetime closed=iTime(_Symbol,InpShapeEntryTF,1),now=TimeCurrent();if(closed<=0 || closed<=last_closed)return;
   last_closed=closed;datetime decision=closed+300;
   // Exercise actual runtime recovery without authorizing historical or fixture orders.
   SBEvaluateShape(true);
   if(!checked_boundary && (long)decision%900==0 && decision<=now)
     {
      MqlRates old[],fresh[];bool a=SBShapeLoad(InpShapeFormationTF,closed,InpShapeLookback,old),b=SBShapeLoad(InpShapeFormationTF,decision,InpShapeLookback,fresh);
      if(a && b)
        {
         int n=ArraySize(fresh);Check(fresh[n-1].time+900==decision,"native M15 confirmation candle available at same M5 decision boundary");
         Check(old[ArraySize(old)-1].time<fresh[n-1].time,"native control demonstrates old cutoff withheld the just-completed M15 candle");
         bool future=false;for(int i=0;i<n;i++)if(fresh[i].time+900>decision)future=true;
         Check(!future,"native loader excludes all future or still-forming M15 candles");checked_boundary=true;
        }
     }
   MqlDateTime t;TimeToStruct(decision,t);
   if(!checked_screenshot && t.year==2026 && t.mon==11 && t.day==2 && t.hour==13 && t.min==15)
     {
      bool found=false;
      for(int i=0;i<ArraySize(sb_shapes);i++)
        if(sb_shapes[i].pattern.id=="1357682230")
          {found=true;Check(sb_shapes[i].pattern.known==D'2026.11.02 13:15' && sb_shapes[i].available==decision,"screenshot triangle registered at 13:15, not 13:20");}
      Check(found,"actual historical screenshot pattern recovered by the immediate runtime detection path");checked_screenshot=true;
     }
  }
void OnDeinit(const int reason){GlobalVariablesDeleteAll(sb_instance);ObjectsDeleteAll(0,sb_object_prefix);}
double OnTester()
  {
   Check(checked_boundary,"native confirmation-boundary data test completed");
   PrintFormat("SHAPE_TIMING_TEST_RESULT | checks=%d failures=%d boundary=%d screenshot=%d orders=%d",checks,failures,checked_boundary,checked_screenshot,OrdersTotal());
   return failures==0 && checked_boundary?checks:-1;
  }
