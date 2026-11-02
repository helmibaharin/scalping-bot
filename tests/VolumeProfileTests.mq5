#property strict
#define OnInit SBVPProductionInit
#define OnTick SBVPProductionTick
#define OnTimer SBVPProductionTimer
#define OnDeinit SBVPProductionDeinit
#define OnTradeTransaction SBVPProductionTransaction
#define OnTester SBVPProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int vp_checks=0,vp_failures=0;datetime vp_start=D'2026.08.04 10:00';
void VPCheck(bool ok,string reason){vp_checks++;if(!ok){vp_failures++;Print("VP_ASSERT_FAIL | ",reason);}else Print("VP_ASSERT_PASS | ",reason);}
void VPBar(MqlRates &b,int index,double o,double h,double l,double c){ZeroMemory(b);b.time=vp_start+index*300;b.open=o;b.high=h;b.low=l;b.close=c;}
SBVPProfile VPProfile(double close)
  {SBVPProfile p={};p.valid=true;p.poc=100;p.vah=110;p.val=90;p.close=close;p.id="native-reference";p.day=SBVPBrokerDay(vp_start)-86400;p.start=p.day;p.end=p.day+86400;p.last=p.end-60;p.bin=.1;p.fraction=.7;p.count=100;p.expected=100;p.volume=10000;p.coverage=1;p.quality="SYNTHETIC_COMPLETE";return p;}
void VPMirror(MqlRates &b){double h=b.high;b.high=200-b.low;b.low=200-h;b.open=200-b.open;b.close=200-b.close;}
void VPPocTests(int dir)
  {
   SBVPProfile p=VPProfile(dir>0?115:85);SBVPCandidate c={};MqlRates previous,b;
   VPBar(previous,-1,103,104,100.8,102);VPBar(b,0,101.9,103.2,100.1,103);
   if(dir<0){VPMirror(previous);VPMirror(b);}
   SBVPPOCStep(c,p,previous,b,10,.01,300);
   VPCheck(c.phase==VP_READY && c.engulf && c.confirmation==(dir>0?"BULLISH_ENGULFING":"BEARISH_ENGULFING"),"POC coherent approach engulfing both directions");
   SBSignal s={};SBVPMakeSignal(c,p,b,0,s);
   VPCheck(s.rr==2 && s.direction==dir && dir*(s.structural_sl-100)<0,"engulfing 2R and SL beyond POC");
   VPCheck(s.method=="S5_M1_POC_BOUNCE" && s.vp_profile==p.id && s.entry_confirmation==b.time+300,"method/profile/confirmation attribution");
   ZeroMemory(c);VPBar(previous,-1,103,104,101.1,102.2);VPBar(b,0,100.2,101.2,100.1,101);
   if(dir<0){VPMirror(previous);VPMirror(b);}SBVPPOCStep(c,p,previous,b,10,.01,300);
   VPCheck(c.phase==VP_WAIT_CONFIRMATION && !c.engulf,"POC touch/rejection alone no entry");
   previous=b;VPBar(b,1,101,102.2,100.8,102);if(dir<0)VPMirror(b);SBVPPOCStep(c,p,previous,b,10,.01,300);
   VPCheck(c.phase!=VP_READY && c.consecutive==1,"first post-rejection directional candle insufficient");
   previous=b;VPBar(b,2,102,103.2,101.8,103);if(dir<0)VPMirror(b);SBVPPOCStep(c,p,previous,b,10,.01,300);
   SBVPMakeSignal(c,p,b,0,s);VPCheck(c.phase==VP_READY && c.directional && !c.engulf && s.rr==1.5,"two post-rejection directional candles yield 1.5R");
   c.phase=VP_WAIT_CONFIRMATION;c.consecutive=1;c.rejection=vp_start-300;
   VPBar(previous,2,103,103.2,101,102);VPBar(b,3,101.9,104,101.8,103.1);
   if(dir<0){VPMirror(previous);VPMirror(b);}SBVPPOCStep(c,p,previous,b,10,.01,300);
   // An engulfing body necessarily follows an opposite body; preload a coherent
   // raw directional count to verify deterministic precedence if both raw flags apply.
   c.directional=true;SBVPMakeSignal(c,p,b,0,s);VPCheck(c.engulf && s.rr==2,"engulfing takes precedence over directional raw condition");
   ZeroMemory(c);p.close=100;SBVPPOCStep(c,p,previous,b,10,.01,300);VPCheck(c.phase==VP_IDLE,"inside-value disables POC method");
   p.close=dir>0?115:85;ZeroMemory(c);VPBar(previous,-1,99,99.5,98,99);VPBar(b,0,99,101,98.9,100.5);if(dir<0){VPMirror(previous);VPMirror(b);}
   SBVPPOCStep(c,p,previous,b,10,.01,300);VPCheck(c.phase!=VP_READY && c.phase==VP_IDLE,"wrong-side POC approach denied");
  }
void VPReversalTests(int dir)
  {
   SBVPProfile p=VPProfile(100);SBVPCandidate c={};SBORBStructure st={};MqlRates previous,b;
   VPBar(previous,-1,95,96,94,95);VPBar(b,0,94,95,87,89);if(dir<0){VPMirror(previous);VPMirror(b);}
   SBVPReversalStep(c,p,previous,b,st,10,300);VPCheck(c.phase==VP_WAIT_REENTRY,"outside excursion arms independent reversal");
   previous=b;VPBar(b,1,89,93,88,90);if(dir<0)VPMirror(b);SBVPReversalStep(c,p,previous,b,st,10,300);
   VPCheck(c.phase==VP_WAIT_REENTRY,"exact boundary close is not strict re-entry");
   previous=b;VPBar(b,2,89,94,88,89.5);if(dir<0)VPMirror(b);SBVPReversalStep(c,p,previous,b,st,10,300);
   VPCheck(c.phase==VP_WAIT_REENTRY,"wick inside without inside close insufficient");
   previous=b;VPBar(b,3,89.5,96,89,95);if(dir<0)VPMirror(b);SBVPReversalStep(c,p,previous,b,st,10,300);
   VPCheck(c.phase==VP_READY && c.direction==dir,"strict completed re-entry confirms reversal both directions");
   SBSignal s={};SBVPMakeSignal(c,p,b,0,s);VPCheck(s.rr==2 && MathAbs(s.structural_sl-(dir>0?86:114))<1e-8,"completed excursion fallback stop plus ATR buffer and 2R");
   c.phase=VP_CONSUMED;c.last=b.time;SBVPReversalStep(c,p,previous,b,st,10,300);VPCheck(c.phase==VP_CONSUMED,"same excursion candle cannot rearm");
   previous=b;VPBar(b,4,95,96,88,95);if(dir<0)VPMirror(b);SBVPReversalStep(c,p,previous,b,st,10,300);
   VPCheck(c.phase==VP_READY && c.start==b.time,"new outside excursion allows independent opportunity");
   ZeroMemory(c);p.close=115;SBVPReversalStep(c,p,previous,b,st,10,300);VPCheck(c.phase==VP_IDLE,"outside-value previous close disables reversal method");
  }
void VPBreakoutTests(int dir)
  {
   SBVPProfile p=VPProfile(100);SBVPCandidate c={};SBORBStructure st={};MqlRates previous,b;
   VPBar(previous,-1,108,110,107,109);VPBar(b,0,109,115,109,114);if(dir<0){VPMirror(previous);VPMirror(b);}
   SBVPBreakoutStep(c,p,previous,b,st,10,.01,300);
   VPCheck(c.phase==VP_WAIT_PULLBACK && c.direction==dir,"significant directional breakout waits pullback");
   SBVPCandidate saved=c;
   previous=b;VPBar(b,1,112,112.5,109,111);if(dir<0)VPMirror(b);SBVPBreakoutStep(c,p,previous,b,st,10,.01,300);
   VPCheck(c.phase==VP_WAIT_BOS && MathAbs(c.wick-.1)<1e-8,"small wick-only pullback accepted");
   SBVPCandidate pullback=c;
   previous=b;VPBar(b,2,111,112,110,111.5);if(dir<0)VPMirror(b);SBVPBreakoutStep(c,p,previous,b,st,10,.01,300);
   VPCheck(c.phase==VP_WAIT_BOS,"no confirmed structure or BOS means no trade");
   SBORBPivot protect={},bos={};protect.time=vp_start+300;protect.known=vp_start+900;protect.price=dir>0?109:91;bos.time=vp_start;bos.known=vp_start+900;bos.price=dir>0?115:85;
   if(dir>0){st.low=protect;st.high=bos;}else{st.high=protect;st.low=bos;}
   VPBar(previous,2,111,112,110,112);VPBar(b,3,113,117,112,116);if(dir<0){VPMirror(previous);VPMirror(b);}
   SBVPBreakoutStep(c,p,previous,b,st,10,.01,300);
   VPCheck(c.phase==VP_READY,"subsequent close breaks known directional swing after confirmed pullback");
   SBSignal s={};SBVPMakeSignal(c,p,b,0,s);VPCheck(s.rr==2 && MathAbs(s.structural_sl-(dir>0?108:92))<1e-8,"BOS-associated protective swing stop and 2R");
   VPCheck(s.boundary==(dir>0?p.vah:p.val),"continuation logs the broken value-area boundary");
   for(int test=0;test<5;test++)
     {
      c=saved;ZeroMemory(st);VPBar(previous,0,109,115,109,114);
      if(test==0)VPBar(b,1,109.99,112,109,111); // Small open inside, close outside.
      if(test==1)VPBar(b,1,105,112,104,111); // Large body inside, close outside.
      if(test==2)VPBar(b,1,112,113,109,109.99); // Any completed inside close.
      if(test==3)VPBar(b,1,112,113,108.49,111); // Wick > 0.15 ATR.
      if(test==4)VPBar(b,1,110,112,108.5,111); // Exact allowed wick and body edge.
      if(dir<0){VPMirror(previous);VPMirror(b);}SBVPBreakoutStep(c,p,previous,b,st,10,.01,300);
      VPCheck(test==4?c.phase==VP_WAIT_BOS:c.phase==VP_INVALIDATED,"wick-only rule: small/large body/close/excess wick/exact edge "+IntegerToString(test));
     }
   c=pullback;VPBar(previous,1,112,113,109,111);VPBar(b,2,111,112,108.9,111);if(dir<0){VPMirror(previous);VPMirror(b);}
   SBVPBreakoutStep(c,p,previous,b,st,10,.01,300);VPCheck(c.phase==VP_INVALIDATED && c.reason=="PULLBACK_STRUCTURE_BROKEN_BEFORE_BOS","broken pullback structure invalidates");
   c=saved;VPBar(b,InpVPSetupExpiryBars+1,111,112,110,111);if(dir<0)VPMirror(b);SBVPBreakoutStep(c,p,previous,b,st,10,.01,300);VPCheck(c.phase==VP_INVALIDATED,"breakout candidate expires without BOS");
   ZeroMemory(c);VPBar(previous,-1,108,110,107,109);VPBar(b,0,109,113,109,112.9);if(dir<0){VPMirror(previous);VPMirror(b);}SBVPBreakoutStep(c,p,previous,b,st,10,.01,300);VPCheck(c.phase==VP_IDLE,"breakout below 0.30 ATR denied");
   ZeroMemory(c);VPBar(b,0,111,115,110,114);if(dir<0)VPMirror(b);SBVPBreakoutStep(c,p,previous,b,st,10,.01,300);VPCheck(c.phase==VP_IDLE,"breakout body below 0.40 ATR denied");
   ZeroMemory(c);p.close=dir>0?120:80;VPBar(b,0,109,115,109,114);if(dir<0)VPMirror(b);SBVPBreakoutStep(c,p,previous,b,st,10,.01,300);VPCheck(c.phase==VP_WAIT_PULLBACK,"method 3 also eligible with previous close outside value");
  }
void VPRunTests()
  {
   VPCheck(SBValidVPInputs(),"native VP configuration validates");VPPocTests(1);VPPocTests(-1);VPReversalTests(1);VPReversalTests(-1);VPBreakoutTests(1);VPBreakoutTests(-1);
   SBSignal signals[];ArrayResize(signals,2);signals[0].strategy=SB_VP_BREAKOUT;signals[0].direction=1;signals[0].entry_confirmation=100;
   signals[1].strategy=SB_VP_POC;signals[1].direction=1;signals[1].entry_confirmation=100;
   VPCheck(SBVPCoordinate(signals)==1,"same-direction equal-time methods choose lowest method number");
   signals[1].direction=-1;VPCheck(SBVPCoordinate(signals)==-2,"simultaneous opposing methods skip both");
   signals[1].entry_confirmation=200;VPCheck(SBVPCoordinate(signals)==0,"earlier confirmation wins over later opposite signal");
   string why="";VPCheck(SBVPAccountingAllows(true,true,0,1,5,why),"other strategy hedged position does not consume S5 slot");
   for(int i=1;i<=3;i++)VPCheck(!SBVPAccountingAllows(true,true,1,1,5,why),"method "+IntegerToString(i)+" active blocks other S5 methods");
   VPCheck(!SBVPAccountingAllows(false,true,0,1,5,why) && why=="ACCOUNT_MODE_INCOMPATIBLE","netting cannot merge or reverse foreign strategy exposure");
   VPCheck(!SBVPAccountingAllows(true,false,0,5,5,why),"shared total position cap enforced");
   VPCheck(SBBrokerDailyLossBreached(9800,10000,2) && !SBBrokerDailyLossBreached(9800.01,10000,2),"exact two-percent broker-day equity loss locks; smaller loss remains below limit");
   VPCheck(SBBrokerDailyLossBreached(10000,0,2),"unknown broker-day equity baseline fails closed");
   int minutes[];ArrayResize(minutes,1440);ArrayInitialize(minutes,0);SBVPMarkWindow(minutes,-60,60);SBVPMarkWindow(minutes,30,120);int count=0;for(int i=0;i<1440;i++)count+=minutes[i];VPCheck(count==120,"overnight and overlapping symbol sessions union exactly");
   VPCheck(SBVPBrokerDay(D'2026.08.03 23:59:59')==D'2026.08.03' && SBVPBrokerDay(D'2026.08.04')==D'2026.08.04',"broker calendar-day boundaries independent of NY/UTC");
   SBVPProfile p=VPProfile(100),loaded={};p.id="frozen-native-test";
   string file="ScalpingBot\\VP.fixture.profile";if(FileIsExist(file))FileDelete(file);
   VPCheck(SBVPWriteFrozen(file,D'2026.08.04',p),"frozen profile durable write");
   VPCheck(SBVPReadFrozen(file,D'2026.08.04',loaded) && loaded.poc==p.poc && loaded.id==p.id,"restart reconstructs exact frozen levels");
   VPCheck(!SBVPReadFrozen(file,D'2026.08.05',loaded),"stale day cache rejected");FileDelete(file);
   MqlRates b[];ArrayResize(b,2);VPBar(b[0],0,100,102,99,101);VPBar(b[1],1,101,103,100,102);b[0].tick_volume=10;b[1].tick_volume=20;
   MqlRates d=b[0];d.high=103;d.close=102;d.tick_volume=30;
   VPCheck(SBVPDailyMatches(b,d,.01),"partial broker session verified against complete D1 OHLC/tick volume");
   d.tick_volume=31;VPCheck(!SBVPDailyMatches(b,d,.01),"missing historical M1 volume cannot masquerade as holiday");
   MqlRates future[];ArrayResize(future,8);for(int i=0;i<8;i++)VPBar(future[i],i,100,101,99,100);future[3].high=105;
   VPCheck(!SBORBPivotAt(future,3,4,1,2,2,300) && SBORBPivotAt(future,3,5,1,2,2,300),"structural pivot only available after two right-hand closes");
   sb_instance="SB.TEST.VP.FIXTURE.";sb_account=sb_instance+"R.";GlobalVariablesDeleteAll(sb_instance);
   VPCheck(SBConsume(SB_VP_POC,"consumed") && SBConsumed(SB_VP_POC,"consumed") && !SBConsumed(SB_VP_REVERSAL,"consumed"),"consumption persists and methods stay independent");GlobalVariablesDeleteAll(sb_instance);
   VPCheck(SBMagic(5)!=SBMagic(6) && SBMagic(6)!=SBMagic(7) && SBStrategyFromMagic(SBMagic(7))==7,"unique magic routing and restart position classification");
  }
int OnInit(){if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;VPRunTests();PrintFormat("VP_TEST_RESULT | checks=%d failures=%d",vp_checks,vp_failures);return vp_failures==0?INIT_SUCCEEDED:INIT_FAILED;}
void OnTick(){}
double OnTester(){PrintFormat("VP_TEST_RESULT | checks=%d failures=%d",vp_checks,vp_failures);return vp_failures==0?vp_checks:-vp_failures;}
