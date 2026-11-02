#property strict
// Tester-only fixture compiled against the complete production EA and its functions.
#define OnInit SBProductionInit
#define OnTick SBProductionTick
#define OnTimer SBProductionTimer
#define OnDeinit SBProductionDeinit
#define OnTradeTransaction SBProductionTransaction
#define OnTester SBProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int checks=0,failures=0;
void Check(bool ok,string reason)
  {checks++;if(!ok){failures++;Print("ORB_ASSERT_FAIL | ",reason);}else Print("ORB_ASSERT_PASS | ",reason);}
void Bar(MqlRates &b,datetime time,double open,double high,double low,double close)
  {ZeroMemory(b);b.time=time;b.open=open;b.high=high;b.low=low;b.close=close;}
void CandidateScenario(int direction,int mode,bool opposing)
  {
   datetime start=D'2026.10.26 16:00';SBORBCandidate c={};SBORBStructure s={};SBORBBreak e={};
   MqlRates bars[];ArrayResize(bars,12);
   for(int i=0;i<12;i++)Bar(bars[i],start+i*300,100,103,97,100);
   double anchor=100;SBORBStart(c,mode,direction,start,anchor,direction>0?95:105,opposing?-direction:0);
   Check(c.phase!=ORB_READY,"breakout or return-inside alone never ready");
   int next=1;
   if(mode==1)
     {
      bars[1].close=100;
      SBORBCandidateStep(c,s,e,bars,1,1,2,true,true,6,20,300);
      Check(c.retest==bars[1].time,"completed valid retest detected");next=2;
     }
   // Protective pivot is confirmed after the retest; reversal uses frozen excursion instead.
   if(direction>0){s.low.time=bars[1].time;s.low.known=bars[2].time;s.low.price=97;s.low.type=-1;}
   else{s.high.time=bars[1].time;s.high.known=bars[2].time;s.high.price=103;s.high.type=1;}
   SBORBCandidateStep(c,s,e,bars,next,1,2,true,true,6,20,300);
   Check(c.phase!=ORB_READY,"missing BOS never produces an entry");
   if(opposing || mode==2)
     {
      if(mode==2 && !opposing)
        {
         e.direction=direction;e.pivot=bars[1].time;e.known=bars[2].time;
         SBORBCandidateStep(c,s,e,bars,3,1,2,true,true,6,20,300);
         Check(!c.choch_done && c.phase==ORB_WAIT_CHOCH,"reversal cannot bypass missing opposing structure");
         s.trend=-direction;
        }
      e.direction=direction;e.pivot=bars[1].time;e.known=bars[2].time;
      SBORBCandidateStep(c,s,e,bars,4,1,2,true,true,6,20,300);
      Check(c.choch_done && !c.bos_done && c.phase==ORB_WAIT_BOS,"CHoCH is a separate first structural break");
      SBORBCandidateStep(c,s,e,bars,5,1,2,true,true,6,20,300);
      Check(!c.bos_done,"same pivot cannot count as CHoCH and BOS");
      e.pivot=bars[4].time;e.known=bars[5].time;
      SBORBCandidateStep(c,s,e,bars,6,1,2,true,true,6,20,300);
     }
   else
     {
      e.direction=direction;e.pivot=bars[2].time;e.known=bars[3].time;
      SBORBCandidateStep(c,s,e,bars,4,1,2,true,true,6,20,300);
      Check(!c.choch_done,"continuation does not invent a required CHoCH without opposing structure");
     }
   Check(c.phase==ORB_READY && c.bos_done,mode==2?"confirmed false-breakout reversal ready":"confirmed continuation ready");
   if(mode==1)Check(c.protective>0,"continuation has a confirmed protective swing");
  }
void RunTests()
  {
   datetime start,finish,day=D'2026.03.06 00:00';
   Check(SBORBSessionUTC(day,start,finish) && start==D'2026.03.06 14:30' && finish==D'2026.03.06 14:45',"winter NY 09:30-09:45 UTC boundaries");
   day=D'2026.03.09 00:00';Check(SBORBSessionUTC(day,start,finish) && start==D'2026.03.09 13:30' && finish==D'2026.03.09 13:45',"US spring DST transition");
   day=D'2026.10.30 00:00';Check(SBORBSessionUTC(day,start,finish) && start==D'2026.10.30 13:30',"US/EU autumn mismatch week");
   day=D'2026.11.02 00:00';Check(SBORBSessionUTC(day,start,finish) && start==D'2026.11.02 14:30',"US autumn DST transition");
   datetime out;Check(!SBORBNYToUTC(D'2026.11.01 01:30',out),"ambiguous NY autumn hour rejected");
   Check(!SBORBNYToUTC(D'2026.03.08 02:30',out),"nonexistent NY spring hour rejected");
   datetime server;Check(SBUTCToServer(start,server) && SBServerToUTC(server,out) && out==start,"verified historical broker UTC round trip");
   datetime pdfrom,pdto,pwfrom,pwto;
   Check(SBORBPreviousPeriods(D'2026.11.02 15:00',D'2026.11.02',pdfrom,pdto,pwfrom,pwto) &&
    pdfrom==D'2026.10.30 04:00' && pdto==D'2026.10.31 04:00',"previous NY business day excludes unfinished current day and weekend");
   Check(pwfrom==D'2026.10.26 04:00' && pwto==D'2026.11.02 05:00',"completed NY week uses historical DST at both boundaries");
   MqlRates range[];ArrayResize(range,15);double high,low;
   for(int i=0;i<15;i++)Bar(range[i],10020+i*60,100,101+i,99-i,100);
   Check(SBORBExactRange(range,10020,10920,60,high,low) && high==115 && low==85,"exact lower-TF range with non-native M15 boundary");
   range[7].time+=60;Check(!SBORBExactRange(range,10020,10920,60,high,low),"missing/duplicate opening minute rejected");range[7].time-=60;
   ArrayResize(range,14);Check(!SBORBExactRange(range,10020,10920,60,high,low),"incomplete range rejected");
   Check(SBORBBreakout(99,102,100,90,1)==1,"bullish completed close breakout");
   Check(SBORBBreakout(91,88,100,90,1)==-1,"bearish completed close breakout");
   Check(SBORBBreakout(99,100,100,90,1)==0,"wick-only or insufficient closing clearance rejected");
   Check(SBORBBreakout(103,104,100,90,1)==0,"outside close is not a new duplicate breakout");
   MqlRates bars[];ArrayResize(bars,12);datetime stamp=10000;
   for(int i=0;i<12;i++)Bar(bars[i],stamp+i*300,100,101,99,100);
   bars[2].high=105;
   Check(!SBORBPivotAt(bars,2,2,1,1,1,300),"pivot unavailable before right candle closes");
   Check(SBORBPivotAt(bars,2,3,1,1,1,300),"pivot available at right confirmation close");
   SBORBStructure s={};SBORBBreak e={};
   for(int i=0;i<4;i++)SBORBStructureStep(s,bars,i,1,1,300,0,e);
   Check(s.high.time==bars[2].time && s.high.known==bars[3].time+300,"pivot timestamp and known timestamp stored separately");
   bars[4].high=106;bars[4].close=104;SBORBStructureStep(s,bars,4,1,1,300,0,e);
   Check(e.direction==0,"wick beyond confirmed swing is not BOS");
   bars[5].close=106;bars[5].high=107;SBORBStructureStep(s,bars,5,1,1,300,0,e);
   Check(e.direction==1 && e.pivot==bars[2].time,"BOS uses previously known confirmed pivot");
   SBORBStructureStep(s,bars,6,1,1,300,0,e);Check(e.direction==0,"broken swing cannot emit twice");
   SBORBStructure trend={};trend.previous_high.time=1;trend.previous_low.time=1;
   trend.previous_high.price=100;trend.previous_low.price=90;trend.high.price=110;trend.low.price=95;
   Check(SBORBTrend(trend)==1,"HTF HH and HL bullish");trend.high.price=95;trend.low.price=85;
   Check(SBORBTrend(trend)==-1,"HTF LH and LL bearish");trend.low.price=95;
   Check(SBORBTrend(trend)==0,"conflicting HTF pivots mixed");
   SBORBFVG f={};f.present=true;f.direction=1;f.bottom=100;f.top=102;
   Check(!SBORBFVGInvalid(f,100.5),"bullish FVG midpoint crossing remains valid");
   Check(!SBORBFVGInvalid(f,100),"bullish exact outer boundary is valid");
   Check(SBORBFVGInvalid(f,99.9),"bullish strict close below outer boundary invalid");
   f.direction=-1;Check(!SBORBFVGInvalid(f,101.5),"bearish midpoint crossing valid");
   Check(!SBORBFVGInvalid(f,102),"bearish exact outer boundary valid");Check(SBORBFVGInvalid(f,102.1),"bearish strict close above outer boundary invalid");
   SBORBCandidate c={};SBORBStart(c,1,1,bars[1].time,100,105,0);
   bars[0].high=100;bars[1].high=103;bars[1].low=100;bars[2].low=102;bars[2].high=104;
   SBORBUpdateFVG(c,bars,2,.5,20,10,300);Check(c.fvg.present && c.fvg.bottom==100 && c.fvg.top==102,"FVG displacement association includes breakout middle candle");
   bars[3].low=98;bars[3].close=101;SBORBUpdateFVG(c,bars,3,.5,20,10,300);
   Check(c.phase!=ORB_INVALID,"wick below associated bullish FVG does not invalidate");
   bars[4].close=99;SBORBUpdateFVG(c,bars,4,.5,20,10,300);Check(c.phase==ORB_INVALID,"associated FVG invalidation rejects candidate");
   SBORBStart(c,1,1,bars[4].time,100,105,0);SBORBUpdateFVG(c,bars,2,.5,20,10,300);
   Check(!c.fvg.present,"unrelated historical FVG excluded");
   SBORBStart(c,1,1,bars[0].time,100,105,0);c.fvg=f;c.fvg.direction=1;c.fvg.formed=bars[0].time;
   bars[11].close=101;SBORBUpdateFVG(c,bars,11,.5,20,2,300);Check(c.phase==ORB_EXPIRED,"associated FVG age bounded");
   CandidateScenario(1,1,false);CandidateScenario(-1,1,false);
   CandidateScenario(1,1,true);CandidateScenario(-1,1,true);
   CandidateScenario(-1,2,true);CandidateScenario(1,2,true);CandidateScenario(1,2,false);
   SBORBStart(c,1,1,bars[0].time,100,105,0);bars[1].close=97;
   SBORBCandidateStep(c,s,e,bars,1,1,2,true,true,3,5,300);Check(c.phase==ORB_INVALID,"failed retest structural rejection");
   SBORBStart(c,1,1,bars[0].time,100,105,0);
   SBORBCandidateStep(c,s,e,bars,11,1,2,true,true,3,5,300);Check(c.phase==ORB_EXPIRED,"pending setup expires");
   SBORBLevel levels[];ArrayResize(levels,1);ZeroMemory(levels[0]);levels[0].price=109;levels[0].side=1;levels[0].known=1;levels[0].type="PDH";
   double nearest,room;string name;
   Check(!SBORBRoom(1,100,95,2,levels,ORB_STRICT,0,0,1000,nearest,room,name),"external high before 2R blocks BUY");
   Check(SBORBRoom(1,100,95,2,levels,ORB_WARNING,0,0,1000,nearest,room,name),"warning policy allows obstruction");
   levels[0].price=91;levels[0].side=-1;
   Check(!SBORBRoom(-1,100,105,2,levels,ORB_STRICT,0,0,1000,nearest,room,name),"external low before 2R blocks SELL");
   levels[0].known=2000;Check(SBORBRoom(-1,100,105,2,levels,ORB_STRICT,0,0,1000,nearest,room,name),"future previous-period level unavailable");
   levels[0].known=1;levels[0].side=1;levels[0].price=99;levels[0].accepted=900;levels[0].acceptance_closes=2;
   Check(SBORBRoom(1,100,95,2,levels,ORB_SELECTIVE,2,.5,1000,nearest,room,name),"selective requires confirmed level acceptance");
   levels[0].acceptance_closes=1;Check(!SBORBRoom(1,100,95,2,levels,ORB_SELECTIVE,2,.5,1000,nearest,room,name),"single close cannot grant selective acceptance");
   SBORBLevel level={};level.price=100;level.side=1;level.known=1;MqlRates b;
   Bar(b,10000,99,102,98,99);SBORBSweepStep(level,b,300,.1,3);Check(level.swept && level.touched,"high-side external sweep");
   ZeroMemory(level);level.price=100;level.side=-1;level.known=1;
   Bar(b,10000,101,102,98,101);SBORBSweepStep(level,b,300,.1,3);Check(level.swept,"low-side external sweep");
   ZeroMemory(level);level.price=100;level.side=1;level.known=1;
   Bar(b,10000,101,102,100,101);SBORBSweepStep(level,b,300,.1,1);
   Bar(b,10900,100,100,98,99);SBORBSweepStep(level,b,300,.1,1);Check(!level.swept,"late return outside sweep window rejected");
   ArrayResize(sb_orb_levels,1);ZeroMemory(sb_orb_levels[0]);
   sb_orb_levels[0].side=1;sb_orb_levels[0].swept=true;sb_orb_levels[0].sweep_origin=100;
   sb_orb_levels[0].penetration=10000;
   Check(!SBORBHasSweep(-1,9000),"new penetration cannot reuse an unrelated old sweep");
   sb_orb_levels[0].sweep_origin=10000;Check(SBORBHasSweep(-1,9000),"failed-breakout sequence retains original sweep context");
   sb_orb_h1=-1;sb_orb_h4=-1;Check(SBORBTrendContext(1)==-1,"countertrend classification");
   sb_orb_h4=0;Check(SBORBTrendContext(1)==0,"mixed context does not force agreement");
   SBSignal signal={};signal.strategy=SB_ORB;signal.direction=1;signal.orb_anchor=100;signal.orb_started=1;
   ArrayResize(sb_orb_levels,0);sb_orb_context_ok=true;sb_orb_h1=-1;sb_orb_h4=-1;string why="";
   Check(SBORBExecutionGuard(signal,100,99,102,why),"default countertrend records without automatic rejection");
   Check(!SBORBExecutionGuard(signal,100+2*InpORBMaxEntryExtensionPoints*_Point,99,102,why),"executable quote extension rejected");
   sb_orb_context_ok=false;Check(!SBORBExecutionGuard(signal,100,99,102,why),"required external history fail closed");
   Check(SBMagic(SB_ORB)!=SBMagic(SB_4H) && SBMagic(SB_ORB)!=SBMagic(SB_TRIANGLE),"three independent magic numbers");
   Check(SBOrderPrefix(SB_ORB,1)!=SBOrderPrefix(SB_ORB,2),"ORB modes retained in broker order tags");
   sb_instance="SB.TEST.ORB.FIXTURE.";sb_account=sb_instance+"R.";GlobalVariablesDeleteAll(sb_instance);
   SBORBStart(c,1,1,10000,100,105,0);c.phase=ORB_READY;c.id="fixture";
   Bar(b,11000,100,102,99,101);SBORBFinishCandidate(c,b,false);
   Check(SBConsumed(SB_ORB,"fixture") && c.phase==ORB_EXECUTED,"restart replay retires historical signal without send");
   Check(!SBConsumed(SB_4H,"fixture") && !SBConsumed(SB_TRIANGLE,"fixture"),"ORB consumption does not consume other strategies");
   GlobalVariablesDeleteAll(sb_instance);
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   RunTests();PrintFormat("ORB_TEST_RESULT | checks=%d failures=%d",checks,failures);
   return failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
double OnTester(){PrintFormat("ORB_TEST_RESULT | checks=%d failures=%d",checks,failures);return failures==0?checks:-failures;}
