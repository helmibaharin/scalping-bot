#property strict
#define OnInit SBSMTProductionInit
#define OnTick SBSMTProductionTick
#define OnTimer SBSMTProductionTimer
#define OnDeinit SBSMTProductionDeinit
#define OnTradeTransaction SBSMTProductionTransaction
#define OnTester SBSMTProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int smt_checks=0,smt_failures=0;
void SMTCheck(bool ok,string reason)
  {smt_checks++;if(!ok){smt_failures++;Print("SMT_ASSERT_FAIL | ",reason);}else Print("SMT_ASSERT_PASS | ",reason);}
void SMTBar(MqlRates &b,datetime time,double open,double high,double low,double close)
  {ZeroMemory(b);b.time=time;b.open=open;b.high=high;b.low=low;b.close=close;}
void SMTSequence(int direction,bool opposing,int seconds)
  {
   SBSMTTrap trap={};trap.direction=direction;trap.extreme=direction>0?90:110;trap.upper=105;trap.lower=95;
   trap.start=D'2026.08.03 14:00';trap.known=trap.start+seconds;trap.id="sequence";
   SBSMTLocation location={};location.valid=true;location.fresh=true;location.direction=direction;
   SBSMTCandidate c={};SBSMTStart(c,trap,location,direction,0,opposing?-direction:0,20);
   MqlRates bars[];ArrayResize(bars,8);
   for(int i=0;i<8;i++)SMTBar(bars[i],trap.start+i*seconds,100,104,96,100);
   SBORBBreak event={};event.direction=direction;event.pivot=trap.start-seconds;event.known=trap.start;
   SBSMTStep(c,event,bars,0,seconds,direction,0,true);
   SMTCheck(c.phase==SMT_TRAP_CONFIRMED && !c.bos_done,"trap candle cannot confirm its own entry");
   event.direction=0;SBSMTStep(c,event,bars,1,seconds,direction,0,true);
   SMTCheck(c.phase==(opposing?SMT_WAIT_CHOCH:SMT_WAIT_BOS),"correct conditional CHoCH state after trap");
   event.direction=direction;
   if(opposing)
     {
      SBSMTStep(c,event,bars,2,seconds,direction,0,true);
      SMTCheck(c.choch_done && !c.bos_done && c.phase==SMT_WAIT_BOS,"first opposing-trend break is CHoCH only");
      SBSMTStep(c,event,bars,3,seconds,direction,0,true);SMTCheck(!c.bos_done,"same pivot cannot become subsequent BOS");
      event.pivot=bars[3].time;event.known=bars[4].time;
      SBSMTStep(c,event,bars,5,seconds,direction,0,true);
     }
   else SBSMTStep(c,event,bars,2,seconds,direction,0,true);
   SMTCheck(c.phase==SMT_READY && c.bos_done,"post-trap directional BOS makes setup ready");
   SMTCheck(c.opposing==opposing,"no invented CHoCH without opposing structure");
  }
void SMTRunTests()
  {
   SMTCheck(SBValidSMTInputs(),"native profile inputs validate");
   SMTCheck(SBSignalSeconds(SB_SMT)==PeriodSeconds(InpSMTEntryTF),"profile entry timeframe drives signal age");
   SMTCheck(InpSMTProfile==0?(InpSMTTrendTF==PERIOD_D1 && InpSMTZoneTF==PERIOD_H4 && InpSMTSecondaryZoneTF==PERIOD_H1 && InpSMTTrapTF==PERIOD_M15 && InpSMTEntryTF==PERIOD_M5):
     (InpSMTTrendTF==PERIOD_M15 && InpSMTZoneTF==PERIOD_M1 && InpSMTTrapTF==PERIOD_M1 && InpSMTEntryTF==PERIOD_M1),"both profiles bind the specified timeframes");
   SBORBStructure structure={};structure.previous_high.time=1;structure.previous_low.time=1;
   structure.previous_high.price=100;structure.previous_low.price=90;structure.high.price=110;structure.low.price=95;
   SMTCheck(SBSMTClassify(structure,2,2)==SMT_BULLISH,"confirmed HH HL bullish");
   structure.high.price=95;structure.low.price=85;SMTCheck(SBSMTClassify(structure,2,2)==SMT_BEARISH,"confirmed LH LL bearish");
   structure.low.price=95;SMTCheck(SBSMTClassify(structure,2,2)==SMT_NEUTRAL,"mixed structure neutral");
   SMTCheck(SBSMTClassify(structure,1,2)==SMT_INSUFFICIENT,"single pivot pair insufficient");
   SMTCheck(!SBSMTTrendAllows(1,0,0,false) && !SBSMTTrendAllows(-1,1,0,false),"strict neutral and countertrend blocked");
   SMTCheck(SBSMTTrendAllows(1,1,0,false) && SBSMTTrendAllows(-1,-1,0,false),"strict trend aligned both ways");
   SMTCheck(SBSMTTrendAllows(-1,1,1,false) && SBSMTTrendAllows(1,SMT_INSUFFICIENT,2,false),"context-only and disabled trend research modes");
   MqlRates bars[];ArrayResize(bars,40);datetime start=D'2026.08.03 14:00';
   for(int i=0;i<40;i++)SMTBar(bars[i],start+i*60,100,101,99,100);
   bars[4].high=105;
   SMTCheck(!SBORBPivotAt(bars,4,5,1,2,2,60) && SBORBPivotAt(bars,4,6,1,2,2,60),"right-side pivot confirmation without lookahead");
   SBORBBreak event={};ZeroMemory(structure);
   for(int i=0;i<=6;i++)SBORBStructureStep(structure,bars,i,2,2,60,0,event);
   SMTCheck(structure.high.time==bars[4].time && structure.high.known==bars[6].time+60,"pivot known only at confirming close");
   bars[7].high=106;bars[7].close=104;SBORBStructureStep(structure,bars,7,2,2,60,0,event);SMTCheck(event.direction==0,"wick-only swing break not BOS");
   bars[8].high=107;bars[8].close=106;SBORBStructureStep(structure,bars,8,2,2,60,0,event);SMTCheck(event.direction==1,"completed directional BOS");
   SMTCheck(!SBSMTContiguous(bars,0,40,60),"out-of-bounds historical request rejected");
   bars[3].time+=60;SMTCheck(!SBSMTContiguous(bars,0,5,60),"history gap/duplicate rejected");bars[3].time-=60;
   SMTBar(bars[20],start+20*60,100,100.5,98,99);SMTBar(bars[21],start+21*60,99,102,98.8,101.8);SMTBar(bars[22],start+22*60,101.8,105,101.6,104.8);
   SMTCheck(SBSMTStrongDeparture(bars,20,22,1,1),"strong bullish momentum departure");
   bars[21].close=99.1;SMTCheck(!SBSMTStrongDeparture(bars,20,22,1,1),"hesitant weak departure rejected");bars[21].close=101.8;
   for(int i=20;i<=22;i++){double o=bars[i].open,h=bars[i].high,l=bars[i].low,c=bars[i].close;bars[i].open=200-o;bars[i].high=200-l;bars[i].low=200-h;bars[i].close=200-c;}
   SMTCheck(SBSMTStrongDeparture(bars,20,22,-1,1),"strong bearish momentum departure");
   for(int i=0;i<40;i++)SMTBar(bars[i],start+i*60,100,101,99,100);
   bars[16].high=105;
   SMTBar(bars[20],start+20*60,100,100.5,98,99);
   SMTBar(bars[21],start+21*60,99,103.1,98.9,103);
   SMTBar(bars[22],start+22*60,103,109.1,102.9,109);
   SBSMTLocation actual[];
   SBSMTBuildLocations(bars,PERIOD_M1,bars[21].time+60,actual);int demands=0;
   for(int i=0;i<ArraySize(actual);i++)if(actual[i].type==SMT_DEMAND)demands++;
   SMTCheck(demands==0,"actual detector cannot publish demand before departure BOS");
   ArrayResize(actual,0);SBSMTBuildLocations(bars,PERIOD_M1,bars[22].time+60,actual);demands=0;
   for(int i=0;i<ArraySize(actual);i++)if(actual[i].type==SMT_DEMAND)
     {demands++;SMTCheck(actual[i].fresh && actual[i].bos && actual[i].momentum && actual[i].known==bars[22].time+60,"actual fresh demand has all three mandatory conditions and known time");}
   SMTCheck(demands==1,"actual demand detector positive BOS path");
   ArrayResize(actual,0);SBSMTBuildLocations(bars,PERIOD_M1,bars[24].time+60,actual);
   for(int i=0;i<ArraySize(actual);i++)if(actual[i].type==SMT_DEMAND)SMTCheck(!actual[i].fresh,"actual detector tracks later retest");
   for(int i=0;i<40;i++){double o=bars[i].open,h=bars[i].high,l=bars[i].low,c=bars[i].close;bars[i].open=200-o;bars[i].high=200-l;bars[i].low=200-h;bars[i].close=200-c;}
   ArrayResize(actual,0);SBSMTBuildLocations(bars,PERIOD_M1,bars[22].time+60,actual);int supplies=0;
   for(int i=0;i<ArraySize(actual);i++)if(actual[i].type==SMT_SUPPLY && actual[i].fresh && actual[i].momentum && actual[i].bos)supplies++;
   SMTCheck(supplies==1,"actual supply detector positive momentum fresh BOS path");
   SBSMTLocation locations[];
   for(int type=1;type<=6;type++)
     {
      ArrayResize(locations,0);int direction=(type==SMT_SSL || type==SMT_DEMAND || type==SMT_ACCUMULATION)?1:-1;
      SBSMTAddLocation(locations,type,PERIOD_M1,direction,101,99,start,start+60);
      SBSMTTrap trap={};trap.direction=direction;trap.start=start+120;trap.known=trap.start+60;trap.lower=98;trap.upper=102;
      trap.extreme=direction>0?98.9:101.1;trap.pattern=1;trap.breakout=trap.start;
      SBSMTLocation chosen={};SMTCheck(SBSMTMatchLocation(trap,locations,chosen),"all six location categories qualify mechanically type="+IntegerToString(type));
      trap.direction=-direction;SMTCheck(!SBSMTMatchLocation(trap,locations,chosen),"location rejects wrong trap direction type="+IntegerToString(type));
     }
   ArrayResize(locations,0);SBSMTAddLocation(locations,SMT_DEMAND,PERIOD_M1,1,101,99,start,start+60);
   SBSMTLocation zone=locations[0];MqlRates b;
   SMTBar(b,start,100,102,98,101);SBSMTLocationUpdate(zone,b,60);SMTCheck(zone.fresh,"origin candle not counted as zone retest");
   SMTBar(b,start+60,103,104,102,103);SBSMTLocationUpdate(zone,b,60);SMTCheck(zone.fresh,"departure outside zone remains fresh");
   SMTBar(b,start+120,102,103,100,102);SBSMTLocationUpdate(zone,b,60);SMTCheck(!zone.fresh && zone.first_touch==b.time,"completed first retest marks non-fresh");
   SBSMTTrap t={};t.direction=1;t.start=start+180;t.known=t.start+60;t.lower=98;t.upper=102;t.extreme=98.9;t.pattern=1;t.breakout=t.start;
   locations[0]=zone;SBSMTLocation chosen={};SMTCheck(!SBSMTMatchLocation(t,locations,chosen),"previously tested supply/demand cannot qualify as fresh");
   t.pattern=3;t.breakout=start+60;locations[0].valid=true;
   SMTCheck(SBSMTMatchLocation(t,locations,chosen),"first touch within compound breakout/re-entry sequence owns its fresh zone");
   t.breakout=start+180;SMTCheck(!SBSMTMatchLocation(t,locations,chosen),"compound trap cannot reuse a zone tested before its breakout");t.pattern=1;
   locations[0].fresh=true;locations[0].bos=false;SMTCheck(!SBSMTMatchLocation(t,locations,chosen),"missing supply/demand BOS rejected");
   locations[0].bos=true;locations[0].momentum=false;SMTCheck(!SBSMTMatchLocation(t,locations,chosen),"missing strong departure rejected");
   SMTBar(b,start+180,99,100,97,98);SBSMTLocationUpdate(zone,b,60);SMTCheck(!zone.valid,"demand outer close invalidates zone");
   for(int i=0;i<40;i++)SMTBar(bars[i],start+i*60,100,101,99,100);
   SMTBar(bars[0],start,100,105,95,101);SMTBar(bars[1],start+60,101,104,96,100);SMTBar(bars[2],start+120,100,103,94,101);
   SBSMTTrap trap={};SMTCheck(SBSMTMotherTrap(bars,2,60,1,1,trap) && trap.direction==1 && trap.known==bars[2].time+60,"classic bullish mother baby trap");
   bars[2].low=97;bars[2].high=106;SMTCheck(SBSMTMotherTrap(bars,2,60,1,1,trap) && trap.direction==-1,"classic bearish trap");
   bars[2].low=94;SMTCheck(!SBSMTMotherTrap(bars,2,60,1,1,trap),"two-sided sweep ambiguous and rejected");
   bars[1].high=106;SMTCheck(!SBSMTMotherTrap(bars,2,60,1,1,trap),"baby outside mother rejected");bars[1].high=104;
   SMTBar(bars[2],start+120,100,103,97,101);SMTBar(bars[3],start+180,101,104,94,100);
   SMTCheck(SBSMTMotherTrap(bars,3,60,2,2,trap) && trap.babies==2 && trap.direction==1,"multiple-baby bullish trap");
   bars[3].high=106;bars[3].low=97;SMTCheck(SBSMTMotherTrap(bars,3,60,2,2,trap) && trap.direction==-1,"multiple-baby bearish trap");
   SMTBar(bars[2],start+120,101,107,100,106);SMTBar(bars[3],start+180,106,107,99,101);
   double extreme;int dir;
   SMTCheck(SBSMTRangeReentry(bars,3,2,60,105,95,extreme,dir) && dir==-1 && extreme==107,"range failed upper breakout and bearish re-entry");
   bars[3].open=100;SMTCheck(!SBSMTRangeReentry(bars,3,2,60,105,95,extreme,dir),"range re-entry must have opposite directional body");
   SMTBar(bars[2],start+120,99,100,93,94);SMTBar(bars[3],start+180,94,102,93,101);
   SMTCheck(SBSMTRangeReentry(bars,3,2,60,105,95,extreme,dir) && dir==1 && extreme==93,"range failed lower breakout and bullish re-entry");
   SMTCheck(!SBSMTRangeReentry(bars,3,3,60,105,95,extreme,dir),"same-bar breakout and range re-entry forbidden");
   for(int i=0;i<40;i++)SMTBar(bars[i],start+i*60,111,112,110,111);
   for(int i=0;i<8;i++)SMTBar(bars[i],start+i*60,100+i*2,102+i*2,99+i*2,101+i*2);
   double upper,lower;
   SMTCheck(SBSMTConsolidation(bars,15,60,2,dir,upper,lower) && dir==-1,"distribution requires preceding bullish move and bounded repeated range");
   for(int i=0;i<8;i++)SMTBar(bars[i],start+i*60,125-i*2,126-i*2,123-i*2,124-i*2);
   SMTCheck(SBSMTConsolidation(bars,15,60,2,dir,upper,lower) && dir==1,"accumulation requires preceding bearish move");
   for(int i=0;i<8;i++)SMTBar(bars[i],start+i*60,111,112,110,111);
   SMTCheck(!SBSMTConsolidation(bars,15,60,2,dir,upper,lower),"sideways range without prior move is not accumulation/distribution");
   SMTSequence(1,false,60);SMTSequence(-1,false,60);SMTSequence(1,true,60);SMTSequence(-1,true,60);SMTSequence(1,true,300);
   trap.direction=1;trap.extreme=90;trap.lower=95;trap.upper=105;trap.start=start;trap.known=start+60;
   SBSMTCandidate candidate={};SBSMTStart(candidate,trap,chosen,1,0,0,20);ZeroMemory(event);
   SMTBar(bars[1],start+60,100,101,89,100);SBSMTStep(candidate,event,bars,1,60,1,0,true);SMTCheck(candidate.phase==SMT_INVALIDATED,"wick through frozen sweep invalidates candidate");
   SBSMTStart(candidate,trap,chosen,1,0,0,20);bars[1].low=96;SBSMTStep(candidate,event,bars,1,60,-1,0,true);SMTCheck(candidate.phase==SMT_INVALIDATED,"trend becoming incompatible invalidates candidate");
   SBSMTStart(candidate,trap,chosen,1,0,0,20);SBSMTStep(candidate,event,bars,1,60,1,0,false);SMTCheck(candidate.phase==SMT_INVALIDATED,"invalidated location blocks confirmation");
   SBSMTStart(candidate,trap,chosen,1,0,0,20);SMTBar(bars[1],start+100*60,100,101,96,100);SBSMTStep(candidate,event,bars,1,60,1,0,true);SMTCheck(candidate.phase==SMT_EXPIRED,"confirmation expires");
   double tp=0,rr=0;string id;ArrayResize(locations,0);
   SBSMTAddLocation(locations,SMT_SUPPLY,PERIOD_H1,-1,110,108,start,start+60);
   SBSMTAddLocation(locations,SMT_SUPPLY,PERIOD_H4,-1,120,118,start+1,start+60);
   SMTCheck(SBSMTSelectTarget(1,100,locations,start+120,1,.01,tp,id) && tp==107,"BUY targets nearest supply before its boundary");
   SMTCheck(SBSMTRRAllows(100,95,tp,1,true,1,rr) && MathAbs(rr-1.4)<1e-9,"dynamic 1.4R is accepted without fixed 3R");
   SMTCheck(SBSMTFilledRRValid(100,95,107,1,7,5,true,1),"actual fill accepts valid sub-2R SMT target");
   SMTCheck(!SBSMTFilledRRValid(103,95,107,1,4,8,true,1),"adverse actual fill fails RR instead of moving TP farther");
   SMTCheck(!SBSMTRRAllows(100,95,103,1,true,1,rr) && SBSMTRRAllows(100,95,103,1,false,1,rr),"minimum RR optional");
   locations[0].lower=99;locations[0].upper=101;SMTCheck(!SBSMTSelectTarget(1,100,locations,start+120,1,.01,tp,id),"overlapping nearer obstacle cannot be skipped for farther supply");
   locations[0].lower=108;locations[0].upper=110;locations[0].fresh=false;
   SMTCheck(!SBSMTSelectTarget(1,100,locations,start+120,1,.01,tp,id),"nearer stale-but-unbroken supply cannot be ignored for farther fresh target");
   locations[0].valid=false;SMTCheck(SBSMTSelectTarget(1,100,locations,start+120,1,.01,tp,id) && tp==117,"invalidated obstacle may be excluded from target search");
   locations[0].valid=false;locations[1].valid=false;SMTCheck(!SBSMTSelectTarget(1,100,locations,start+120,1,.01,tp,id),"no valid opposing target means no trade");
   ArrayResize(locations,0);SBSMTAddLocation(locations,SMT_DEMAND,PERIOD_H1,1,92,90,start,start+60);
   SMTCheck(SBSMTSelectTarget(-1,100,locations,start+120,1,.01,tp,id) && tp==93,"SELL targets nearest demand before boundary");
   SMTCheck(SBSMTRRAllows(100,105,tp,-1,true,1,rr) && MathAbs(rr-1.4)<1e-9,"SELL executable dynamic RR");
   SMTCheck(SBRoundPrice(89.995,.01,-1)<90 && SBRoundPrice(110.005,.01,1)>110,"tick rounding keeps SL outside sweep in both directions");
   SBSMTAddLocation(locations,SMT_DEMAND,PERIOD_H1,1,92,90,start,start+60);SMTCheck(ArraySize(locations)==1,"overlapping same location identities deduplicate");
   SBORBFVG fvg={};fvg.present=true;fvg.direction=1;fvg.bottom=95;fvg.top=97;
   SMTCheck(!SBORBFVGInvalid(fvg,95.5) && !SBORBFVGInvalid(fvg,95) && SBORBFVGInvalid(fvg,94.99),"optional bullish FVG outer boundary, not midpoint");
   fvg.direction=-1;SMTCheck(!SBORBFVGInvalid(fvg,96.5) && SBORBFVGInvalid(fvg,97.01),"optional bearish FVG outer boundary");
   sb_instance="SB.TEST.SMT.FIXTURE.";sb_account=sb_instance+"R.";GlobalVariablesDeleteAll(sb_instance);
   trap.id="retire";trap.known=start+60;trap.direction=1;SBSMTStart(candidate,trap,chosen,1,0,0,20);candidate.phase=SMT_READY;
   SMTBar(b,start+120,100,101,99,100);SBSMTFinish(candidate,b,false);
   SMTCheck(SBConsumed(SB_SMT,"retire") && candidate.phase==SMT_EXECUTED,"restart replay retires historical confirmation without sending");
   SMTCheck(!SBConsumed(SB_4H,"retire") && !SBConsumed(SB_TRIANGLE,"retire") && !SBConsumed(SB_ORB,"retire"),"SMT consumption isolated from strategies 1-3");
   string cross=SBSMTSharedTrapKey(trap);SBPut(cross,1);candidate.phase=SMT_READY;trap.id="cross";candidate.trap=trap;SBSMTFinish(candidate,b,true);
   SMTCheck(candidate.phase==SMT_BLOCKED,"same-symbol same-confirmation cross-profile trap cannot send twice");
   SMTCheck(!SBAccountingAllows(false,true,1,2) && SBAccountingAllows(true,true,1,2),"netting collision rejected while hedging respects account cap");
   GlobalVariablesDeleteAll(sb_instance);
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   SMTRunTests();PrintFormat("SMT_TEST_RESULT | profile=%s checks=%d failures=%d",SBSMTProfileName(),smt_checks,smt_failures);
   return smt_failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
double OnTester(){PrintFormat("SMT_TEST_RESULT | profile=%s checks=%d failures=%d",SBSMTProfileName(),smt_checks,smt_failures);return smt_failures==0?smt_checks:-smt_failures;}
