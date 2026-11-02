#property strict
#define OnInit SBShapeProductionInit
#define OnTick SBShapeProductionTick
#define OnTimer SBShapeProductionTimer
#define OnDeinit SBShapeProductionDeinit
#define OnTradeTransaction SBShapeProductionTransaction
#define OnTester SBShapeProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int shape_checks=0,shape_failures=0;
datetime fixture_start=D'2026.08.03 09:00';
void ShapeCheck(bool ok,string reason){shape_checks++;if(!ok){shape_failures++;Print("SHAPE_ASSERT_FAIL | ",reason);}else Print("SHAPE_ASSERT_PASS | ",reason);}
void ShapeBar(MqlRates &b,datetime t,double o,double h,double l,double c){ZeroMemory(b);b.time=t;b.open=o;b.high=h;b.low=l;b.close=c;}
void ShapeFixture(int type,SBShapePivot &q[])
  {
   ArrayResize(q,6);int sec=PeriodSeconds(InpShapeFormationTF);
   double hi[3]={120,120,120},lo[3]={90,100,110};
   if(type==2){hi[0]=130;hi[1]=120;hi[2]=110;lo[0]=90;lo[1]=90;lo[2]=90;}
   if(type==3){hi[0]=124;hi[1]=120;hi[2]=116;lo[0]=96;lo[1]=100;lo[2]=104;}
   if(type==4 || type==5){hi[0]=122;hi[1]=120;hi[2]=118;lo[0]=102;lo[1]=100;lo[2]=98;}
   if(type==6 || type==7){hi[0]=110;hi[1]=120;hi[2]=110;lo[0]=95;lo[1]=100;lo[2]=100;}
   if(type==8 || type==9){hi[0]=110;hi[1]=110;hi[2]=110;lo[0]=90;lo[1]=90;lo[2]=100;}
   if(type==10){hi[0]=136;hi[1]=120;hi[2]=104;lo[0]=88;lo[1]=80;lo[2]=72;}
   if(type==11){hi[0]=112;hi[1]=120;hi[2]=128;lo[0]=74;lo[1]=90;lo[2]=106;}
   bool mirror=type==5 || type==7 || type==9;
   for(int i=0;i<6;i++)
     {q[i].time=fixture_start+(i+1)*4*sec;q[i].known=q[i].time+3*sec;q[i].index=(i+1)*4;q[i].side=i%2==0?-1:1;q[i].price=i%2==0?lo[i/2]:hi[i/2];if(mirror){q[i].side=-q[i].side;q[i].price=200-q[i].price;}}
  }
SBShapePattern ShapeRectangle()
  {
   SBShapePattern p={};p.type=1;p.id="sequence";p.first=fixture_start-900;p.known=fixture_start;p.formed=fixture_start;
   p.u1=fixture_start;p.u2=fixture_start+900;p.l1=p.u1;p.l2=p.u2;p.up1=p.up2=110;p.lo1=p.lo2=90;p.atr=1;p.height=20;return p;
  }
void ShapeSequence(int direction,bool opposing)
  {
   int sec=PeriodSeconds(InpShapeEntryTF);SBShapeCandidate c={};c.pattern=ShapeRectangle();c.phase=SH_WAIT_BREAKOUT;
   MqlRates previous,b;ShapeBar(previous,fixture_start-sec,100,105,95,100);
   ShapeBar(b,fixture_start,100,direction<0?112:105,direction>0?88:95,100);
   SBORBBreak event={};event.direction=direction;event.price=direction>0?104:96;event.pivot=fixture_start-sec*4;event.known=fixture_start-sec;
   SBShapeStep(c,b,previous,event,opposing?-direction:0,sec);
   ShapeCheck(c.trap==b.time && c.phase==(opposing?SH_WAIT_CHOCH:SH_WAIT_BOS),"wick trap requires later reversal structure");
   ShapeCheck(c.continuation_cancelled && c.bos==0 && c.choch==0,"trap cannot confirm own CHoCH or BOS; continuation cancelled");
   ShapeCheck(direction*(c.protective-c.extreme)<0,"SL beyond frozen sweep extreme");
   ShapeBar(b,fixture_start+sec,100,106,94,direction>0?105:95);SBShapeStep(c,b,previous,event,0,sec);
   if(opposing)
     {
      ShapeCheck(c.choch==b.time && c.bos==0 && c.phase==SH_WAIT_BOS,"first opposing-trend break only CHoCH");
      ShapeBar(b,fixture_start+2*sec,100,106,94,direction>0?105:95);SBShapeStep(c,b,previous,event,0,sec);
      ShapeCheck(c.bos==0,"same pivot cannot provide subsequent BOS");
      event.pivot=fixture_start+2*sec;event.known=fixture_start+3*sec;
      ShapeBar(b,fixture_start+4*sec,100,107,93,direction>0?106:94);SBShapeStep(c,b,previous,event,0,sec);
     }
   ShapeCheck(c.phase==SH_REVERSAL_READY && c.bos>c.trap,"distinct post-trap directional BOS permits reversal");
   SBSignal s={};SBShapeMakeSignal(c,b,s);ShapeCheck(s.method=="TRAP_REVERSAL" && s.family=="TRIANGLE" && s.bos_status=="CONFIRMED","structured family/method/BOS attribution");
   ShapeCheck(s.trap_time==c.trap+sec && s.entry_confirmation==b.time+sec,"journal confirmation timestamps are completed-candle closes");
   SBShapeCandidate invalid=c;invalid.phase=SH_WAIT_BOS;invalid.bos=0;
   ShapeBar(b,fixture_start+5*sec,100,direction<0?113:106,direction>0?87:94,100);event.direction=0;SBShapeStep(invalid,b,previous,event,0,sec);
   ShapeCheck(invalid.phase==SH_INVALIDATED && invalid.reason=="SWEEP_EXTREME_BREACHED","sweep extreme breach invalidates");
  }
void ShapeRunTests()
  {
   ShapeCheck(SBValidShapeInputs(),"shape inputs valid");
   ShapeCheck(SBValidInputs() && SBValidORBInputs() && SBValidSMTInputs(),"complete native demo profile validates shared and all strategy inputs");
   ShapeCheck(InpShapeFormationTF==PERIOD_M15 && InpShapeEntryTF==PERIOD_M5,"M15/M5 defaults");
   SBSignal legacy={};legacy.strategy=SB_TRIANGLE;legacy.pattern_type=1;
   ShapeCheck(StringLen(legacy.method)==0 && !SBShapeDynamic(legacy),"zero-initialized legacy Triangle never enters structural target path");
   SBSignal triangle=legacy;triangle.method="BREAKOUT_CONTINUATION";
   ShapeCheck(!SBShapeDynamic(triangle),"new Triangle continuation retains configured fixed-RR policy");
   for(int type=1;type<=11;type++)
     {
      SBShapePivot q[];ShapeFixture(type,q);SBShapePattern p={};
      bool found=SBShapeGeometry(q,5,type,1,PeriodSeconds(InpShapeFormationTF),p);
      ShapeCheck(found,"confirmed geometry "+SBShapeSubtype(type));
      if(found)
        {
         ShapeCheck(p.known>=q[5].known && p.pivots!="","known timestamp and exact pivots "+SBShapeSubtype(type));ShapeCheck(p.direction==(type==4 || type==7 || type==9 || type==10?1:(type==5 || type==6 || type==8 || type==11?-1:0)),"appropriate breakout side "+SBShapeSubtype(type));
         MqlRates candles[];ArrayResize(candles,27);int fsec=PeriodSeconds(InpShapeFormationTF);
         for(int j=0;j<27;j++){datetime t=fixture_start+j*fsec;double mid=(SBShapeUpper(p,t)+SBShapeLower(p,t))/2;ShapeBar(candles[j],t,mid,mid+.01,mid-.01,mid);}
         for(int j=0;j<6;j++){int at=q[j].index;if(q[j].side>0)candles[at].high=q[j].price;else candles[at].low=q[j].price;}
         if(type==4 || type==5)
           {double before=candles[12].close-p.direction*80;for(int j=0;j<4;j++)ShapeBar(candles[j],fixture_start+j*fsec,before,before+.01,before-.01,before);}
         ShapeCheck(SBShapeValidateBars(p,candles,26),"OHLC touches/containment/pole validation "+SBShapeSubtype(type));
         SBShapePattern detected[];SBShapeDetect(candles,26,detected);bool pipeline=false;
         for(int j=0;j<ArraySize(detected);j++)if(detected[j].type==type)pipeline=true;
         ShapeCheck(pipeline,"full confirmed-pivot detection pipeline "+SBShapeSubtype(type));
         if(type==4 || type==5)
           {for(int j=0;j<12;j++){double mid=candles[12].close;ShapeBar(candles[j],fixture_start+j*fsec,mid,mid+.01,mid-.01,mid);}ShapeCheck(!SBShapeValidateBars(p,candles,26),"ordinary channel without pole rejected "+SBShapeSubtype(type));}
        }
     }
   ShapeSequence(1,true);ShapeSequence(-1,true);ShapeSequence(1,false);ShapeSequence(-1,false);
   int sec=PeriodSeconds(InpShapeEntryTF);MqlRates b,previous;ShapeBar(previous,fixture_start-sec,100,105,95,100);
   SBSweep sweep={};ShapeBar(b,fixture_start,100,112,99,111);
   ShapeCheck(SBLiquidityStep(sweep,b,110,90,fixture_start,sec,6,0)==BREAKOUT_HOLDING,"closing breakout is holding, not assumed trap");
   ShapeBar(b,fixture_start+sec,111,114,100,105);
   ShapeCheck(SBLiquidityStep(sweep,b,110,90,fixture_start,sec,6,0)==BREAKOUT_FAILED && sweep.extreme==114,"delayed failure retains full excursion extreme");
   ZeroMemory(sweep);ShapeBar(b,fixture_start,100,112,88,100);
   ShapeCheck(SBLiquidityStep(sweep,b,110,90,fixture_start,sec,6,0)==INSUFFICIENT_DATA,"two-sided sweep ambiguous without tick path");
   ShapeCheck(SBLiquidityStep(sweep,b,110,90,fixture_start+1,sec,6,0)==INSUFFICIENT_DATA,"future-known liquidity prohibited");
   SBShapeCandidate c={};c.pattern=ShapeRectangle();c.phase=SH_WAIT_BREAKOUT;SBORBBreak event={};
   ShapeBar(b,fixture_start,108,113,107,112);SBShapeStep(c,b,previous,event,0,sec);
   ShapeCheck(c.phase==SH_WAIT_RETEST && c.trap==0,"quality closing breakout awaits retest");
   previous=b;ShapeBar(b,fixture_start+sec,111,112,110,111);SBShapeStep(c,b,previous,event,0,sec);
   ShapeCheck(c.retest==b.time && c.phase==SH_WAIT_RETEST,"retest alone does not enter");
   previous=b;ShapeBar(b,fixture_start+2*sec,111,114,111,113);SBShapeStep(c,b,previous,event,0,sec);
   ShapeCheck(c.phase==SH_CONTINUATION_READY && c.protective<110,"separate right bar confirms continuation structural SL");
   c.phase=SH_WAIT_BOS;c.trap=fixture_start;c.extreme=120;c.direction=-1;c.anchor=110;
   ShapeBar(b,fixture_start+(InpShapeConfirmationBars+1)*sec,100,105,95,100);SBShapeStep(c,b,previous,event,0,sec);
   ShapeCheck(c.phase==SH_EXPIRED,"confirmation expiry");
   ArrayResize(sb_shape_levels,0);SBShapeLevelAdd(120,1,0,fixture_start,"NEAR");SBShapeLevelAdd(150,1,0,fixture_start,"FAR");
   SBSignal s={};s.strategy=SB_TRIANGLE;s.direction=1;s.method="TRAP_REVERSAL";double tp=0;string why="",source="";
   ShapeCheck(SBShapeNearestTarget(1,100,fixture_start,tp,source) && source=="NEAR" && tp<120,"nearest obstacle target buffered before structure");
   ShapeCheck(SBShapePlanGeometry(s,100,90,tp,why) && MathAbs((tp-100)/10-(20-InpShapeTPBufferPoints*_Point)/10)<.00001,"dynamic reversal RR");
   ArrayResize(sb_shape_levels,0);ShapeCheck(!SBShapePlanGeometry(s,100,90,tp,why),"no target means no trade");
   SBShapeLevelAdd(105,1,0,fixture_start,"NEAR");SBShapeLevelAdd(150,1,0,fixture_start,"FAR");
   ShapeCheck(!SBShapePlanGeometry(s,100,90,tp,why),"cannot skip nearer obstacle to manufacture RR");
   MqlRates bars[];ArrayResize(bars,8);for(int i=0;i<8;i++)ShapeBar(bars[i],fixture_start+i*sec,100,101,99,100);bars[3].high=105;
   ShapeCheck(!SBORBPivotAt(bars,3,4,1,2,2,sec) && SBORBPivotAt(bars,3,5,1,2,2,sec),"confirmed pivot right bars no lookahead");
   sb_instance="SB.TEST.SHAPE.FIXTURE.";sb_account=sb_instance+"R.";GlobalVariablesDeleteAll(sb_instance);ArrayResize(sb_shapes,0);
   SBShapePattern p=ShapeRectangle();ShapeCheck(SBShapeAdd(p) && !SBShapeAdd(p),"same anchored pattern deduplicated");
   p.id="overlap";ShapeCheck(!SBShapeAdd(p),"overlapping near-identical pattern deduplicated");
   p.id="independent";p.first-=86400;p.formed=p.first+900;p.known=p.first+1800;p.u1=p.first;p.u2=p.formed;p.l1=p.first;p.l2=p.formed;ShapeCheck(SBShapeAdd(p),"independent patterns retained");
   ShapeCheck(SBAccountingAllows(true,true,1,2) && !SBAccountingAllows(false,true,1,2) && !SBAccountingAllows(true,false,2,2),"hedging/netting and shared cap");
   ShapeCheck(SBStableName(1)=="S1_4H_BREAKOUT" && SBStableName(2)=="S2_SHAPE_PATTERN" && SBStableName(3)=="S3_ORB" && StringFind(SBStableName(4),"S4_SMT_")==0,"all strategies have stable attribution IDs");
   ShapeCheck(SBLedgerInit(),"native CSV ledger opens");
   SBPlan plan={};plan.signal=s;plan.signal.id="persist";plan.signal.candle=fixture_start;plan.signal.subtype="ASCENDING_TRIANGLE";plan.signal.family="TRIANGLE";plan.signal.pattern_id="pattern";plan.signal.pivots="exact;pivots";plan.magic=SBMagic(SB_TRIANGLE);plan.entry=100;plan.sl=90;plan.tp=120;plan.risk=10;plan.volume=.01;plan.signal.rr=2;
   int k=SBLedgerPlan(plan,"REQUEST","fixture");ShapeCheck(k>=0 && sb_ledger_meta[k].order==0,"request persisted without claiming fill");
   MqlTradeResult result={};result.order=12345;result.retcode=TRADE_RETCODE_DONE;
   ShapeCheck(SBLedgerResult(k,result),"broker order relation persisted");
   FileClose(sb_ledger);sb_ledger=INVALID_HANDLE;ArrayResize(sb_ledger_meta,0);
   ShapeCheck(SBLedgerInit(false),"native restart parses durable CSV");
   k=SBLedgerRelation(12345,0);ShapeCheck(k>=0,"order relation survives file reopen without comments");
   if(k>=0)ShapeCheck(sb_ledger_meta[k].plan.risk==10 && sb_ledger_meta[k].plan.signal.method=="TRAP_REVERSAL" && sb_ledger_meta[k].plan.signal.pivots=="exact;pivots","original risk/pattern/method survive restart");
   for(int strategy=1;strategy<=4;strategy++)
     {
      if(strategy==2)continue;
      SBPlan other={};other.signal.strategy=strategy;other.signal.id="decorate"+IntegerToString(strategy);other.signal.candle=fixture_start;other.signal.orb_mode=2;other.signal.pattern_type=2;other.signal.sl_method="STRUCTURAL_TEST";other.magic=SBMagic(strategy);
      int index=SBLedgerPlan(other,"SIGNAL_ONLY","fixture");
      ShapeCheck(index>=0 && StringLen(sb_ledger_meta[index].plan.signal.method)>0 && StringLen(sb_ledger_meta[index].plan.signal.subtype)>0 && sb_ledger_meta[index].stable==SBStableName(strategy),"other strategy pattern/method decoration "+IntegerToString(strategy));
      ShapeCheck(StringLen(other.signal.method)==0,"journal decoration cannot mutate decision signal "+IntegerToString(strategy));
     }
   FileClose(sb_ledger);sb_ledger=INVALID_HANDLE;GlobalVariablesDeleteAll(sb_instance);
  }
int OnInit(){if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;ShapeRunTests();PrintFormat("SHAPE_TEST_RESULT | checks=%d failures=%d",shape_checks,shape_failures);return shape_failures==0?INIT_SUCCEEDED:INIT_FAILED;}
void OnTick(){}
double OnTester(){PrintFormat("SHAPE_TEST_RESULT | checks=%d failures=%d",shape_checks,shape_failures);return shape_failures==0?shape_checks:-shape_failures;}
