#property strict
#include "../MQL5/Include/ScalpingBot/Config.mqh"
bool test_verified=true,test_draw=true;
SB_BROKER_DST test_rule=SB_FIXED;
int test_winter=180,test_summer=180;
datetime test_from=D'2007.01.01',test_until=D'2038.01.01';
string test_table="";
#define InpBrokerTimeVerified test_verified
#define InpBrokerDSTRule test_rule
#define InpBrokerWinterUTCMinutes test_winter
#define InpBrokerSummerUTCMinutes test_summer
#define InpBrokerMappingFromUTC test_from
#define InpBrokerMappingUntilUTC test_until
#define InpBrokerUTCTransitions test_table
#define InpDrawObjects test_draw
#define OnInit SBRangeProductionInit
#define OnTick SBRangeProductionTick
#define OnTimer SBRangeProductionTimer
#define OnDeinit SBRangeProductionDeinit
#define OnTradeTransaction SBRangeProductionTransaction
#define OnTester SBRangeProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int checks=0,failures=0,next_scenario=0,restart_stage=0;
int scenario_minute[]={60,241,480,578,586,600};
datetime next_check=0;
void Check(bool ok,string why){checks++;Print(ok?"RANGE_ASSERT_PASS | ":"RANGE_ASSERT_FAIL | ",why);if(!ok)failures++;}
void Defaults(){test_verified=true;test_rule=SB_FIXED;test_winter=180;test_summer=180;test_from=D'2007.01.01';test_until=D'2038.01.01';test_table="";}
void Bars(MqlRates &bars[],SBSessionRange &r,int count)
  {
   ArrayResize(bars,count);
   for(int i=0;i<count;i++){ZeroMemory(bars[i]);SBUTCToServer(r.start_utc+i*60,bars[i].time);bars[i].open=100;bars[i].high=101+i;bars[i].low=99-i*.01;bars[i].close=100;}
  }
void UnitSuite()
  {
   Defaults();SBSessionRange r={};MqlRates bars[];
   Check(SBRangeWindow(D'2026.08.03',0,240,r) && r.start_utc==D'2026.08.03 04:00' && r.end_utc==D'2026.08.03 08:00',"NY midnight to 04:00 converts independently of broker H4");
   Check(SBRangeMapping(r) && r.from==D'2026.08.03 07:00',"synthetic UTC+3 mapping exact window");
   r.cutoff=r.start_utc+3600;r.expected=60;Bars(bars,r,60);
   Check(SBValidateRangeBars(bars,r.cutoff,r) && !r.ready && r.state=="RANGE_FORMING" && r.high==160,"S1 01:00 recovers completed first hour");
   r.cutoff=r.end_utc;r.expected=240;Bars(bars,r,240);
   Check(SBValidateRangeBars(bars,r.end_utc+60,r) && r.ready && r.high==340,"S1 04:01 full exact M1 range");
   Check(SBValidateRangeBars(bars,r.end_utc+6*3600,r) && r.ready,"S1 10:00 full range is independent of attachment time");
   bars[1].time=bars[0].time;Check(!SBValidateRangeBars(bars,r.end_utc,r) && !r.ready,"duplicate minute rejected");
   Bars(bars,r,240);bars[8].low=0;Check(!SBValidateRangeBars(bars,r.end_utc,r),"invalid OHLC rejected");
   Bars(bars,r,240);bars[0].time-=60;Check(!SBValidateRangeBars(bars,r.end_utc,r),"outside-session candle rejected");
   Bars(bars,r,239);Check(!SBValidateRangeBars(bars,r.end_utc,r) && r.state=="RANGE_HISTORY_INCOMPLETE","missing final minute remains retryable");
   Bars(bars,r,240);Check(SBValidateRangeBars(bars,r.end_utc,r) && r.ready,"same state recovers after history arrives");
   Check(!SBValidateRangeBars(bars,r.end_utc-1,r),"future close relative to simulated decision rejected");
   SBRangeWindow(D'2026.08.03',570,585,r);SBRangeMapping(r);r.cutoff=r.start_utc+8*60;r.expected=8;Bars(bars,r,8);
   Check(SBValidateRangeBars(bars,r.cutoff+20,r) && r.state=="RANGE_FORMING" && !r.ready,"ORB 09:38 includes eight completed M1 candles");
   r.cutoff=r.end_utc;r.expected=15;Bars(bars,r,15);
   Check(SBValidateRangeBars(bars,r.end_utc+60,r) && r.ready && r.high==115,"ORB 09:46 exact 15 candles");
   Check(SBValidateRangeBars(bars,r.end_utc+15*60,r) && r.ready,"ORB 10:00 late recovery");
   test_verified=false;Check(!SBRangeMapping(r) && r.reason=="BROKER_MAPPING_NOT_VERIFIED","unverified mapping cannot be bypassed by recovery");Defaults();
   Check(!SBRangeWindow(D'2026.08.02',0,240,r) && r.state=="DAY_INVALID" && r.reason=="NY_WEEKEND","weekend remains invalid calendar day");
   datetime days[]={D'2026.03.06',D'2026.03.09',D'2026.03.30',D'2026.10.23',D'2026.10.26',D'2026.11.02'};
   int nyhours[]={14,13,13,13,13,14},brokerhours[]={16,15,16,16,15,16};
   test_rule=SB_EU;test_winter=120;test_summer=180;
   for(int i=0;i<6;i++)
     {
      Check(SBRangeWindow(days[i],570,585,r) && r.start_utc==days[i]+nyhours[i]*3600+1800,"independent NY DST ORB boundary "+TimeToString(days[i],TIME_DATE));
      Check(SBRangeMapping(r) && r.from==days[i]+brokerhours[i]*3600+1800,"independent broker EU DST boundary "+TimeToString(days[i],TIME_DATE));
     }
   Defaults();test_rule=SB_UTC_TABLE;test_from=D'2026.01.01';test_until=D'2027.01.01';
   test_table="2026.01.01 00:00=120;2026.08.03 05:00=180";SBRangeWindow(D'2026.08.03',0,240,r);
   Check(!SBRangeMapping(r) && r.state=="TIMEZONE_MAPPING_UNVERIFIED","broker jump within range fails safely");
   test_table="2026.01.01 00:00=180;2026.08.03 05:00=120";
   Check(!SBRangeMapping(r) && r.reason=="BROKER_MAPPING_SERVER_FOLD_AMBIGUOUS","folded historical broker minute rejected");Defaults();
   datetime t=D'2026.08.03 12:00';
   Check(!SBFreshSessionConfirmation(t,t+300,t+301),"pre-startup completed confirmation is never actionable");
   Check(SBFreshSessionConfirmation(t,t+299,t+300),"fresh post-startup completed confirmation eligible");
   Check(!SBFreshSessionConfirmation(t,t,t+299),"forming M5 never actionable");
   SBRangeWindow(D'2026.08.03',0,240,r);Bars(bars,r,3);
   for(int i=0;i<3;i++)bars[i].time=t+i*300;
   string why;Check(SBReplayCoverage(bars,t,t+600,300,why),"contiguous replay preflight");
   bars[1].time+=60;Check(!SBReplayCoverage(bars,t,t+600,300,why),"M5 missing data cannot partially mutate setup state");
   SBORBCandidate c={};c.phase=ORB_READY;c.id="fixture-old-confirmation";MqlRates b={};
   SBORBFinishCandidate(c,b,false);Check(c.phase==ORB_EXECUTED && SBConsumed(SB_ORB,c.id),"historical ORB ready confirmation retired and persisted");
   SBORBCandidate e={};SBORBStart(e,1,1,t,100,103,0);SBORBStructure structure={};SBORBBreak event={};
   ArrayResize(bars,1);ZeroMemory(bars[0]);bars[0].time=t+(InpORBConfirmationTimeoutBars+2)*300;bars[0].open=102;bars[0].high=104;bars[0].low=101;bars[0].close=103;
   SBORBCandidateStep(e,structure,event,bars,0,1,1,true,true,InpORBMaxRetestBars,InpORBConfirmationTimeoutBars,300);
   Check(e.phase==ORB_EXPIRED,"historical candidate past timeout never reactivated");
   ZeroMemory(sb_four);sb_four.day=D'2026.08.03';sb_four.high=110;sb_four.low=90;sb_four.ready=true;sb_four_last=0;
   ArrayResize(bars,2);ZeroMemory(bars[0]);bars[0].time=D'2026.08.03 12:00';bars[0].open=109;bars[0].high=113;bars[0].low=100;bars[0].close=112;
   bars[1]=bars[0];bars[1].time+=300;bars[1].open=112;bars[1].high=114;bars[1].low=99;bars[1].close=100;
   SB4HBar(bars,0,false);Check(sb_four.side==1,"historical S1 excursion reconstructs pending setup");
   SB4HBar(bars,1,false);Check(sb_four.side==0 && PositionsTotal()==0,"historical S1 return retires setup without an order");
   bars[1].time+=600;SB4HBar(bars,1,false);Check(!sb_four.invalid && StringFind(sb_four_wait,"RANGE_HISTORY_INCOMPLETE")==0,"M5 gap does not permanently invalidate S1 day");sb_four_wait="";
   Check(SBRangeWindow(D'2026.08.04',0,240,r) && r.day==D'2026.08.04',"next NY date selects new range window");
  }
void DrawingSuite()
  {
   SBVPProfile saved=sb_vp_profile;datetime saved_day=sb_vp_day;
   sb_vp_day=SBVPBrokerDay(TimeCurrent());ZeroMemory(sb_vp_profile);
   sb_vp_profile.valid=true;sb_vp_profile.id="drawing-fixture";sb_vp_profile.day=sb_vp_day-86400;sb_vp_profile.end=sb_vp_day;
   sb_vp_profile.poc=2500;sb_vp_profile.vah=2510;sb_vp_profile.val=2490;
   SBVPDrawProfile(true);Check(SBVPObjectsPresent(),"validated frozen profile creates exactly three lines and labels");
   Check(ObjectGetInteger(0,SBVPObjectPrefix()+"POC",OBJPROP_COLOR)==clrYellow && ObjectGetInteger(0,SBVPObjectPrefix()+"POC",OBJPROP_STYLE)==STYLE_SOLID,"POC yellow solid");
   Check(ObjectGetInteger(0,SBVPObjectPrefix()+"VAH",OBJPROP_COLOR)==clrLimeGreen && ObjectGetInteger(0,SBVPObjectPrefix()+"VAL",OBJPROP_STYLE)==STYLE_DASH,"VAH and VAL green dashed");
   Check(ObjectGetInteger(0,SBVPObjectPrefix()+"POC",OBJPROP_TIMEFRAMES)==OBJ_ALL_PERIODS,"levels visible on M1 M5 M15 and all chart periods");
   Check(StringFind(ObjectGetString(0,SBVPObjectPrefix()+"POC.label",OBJPROP_TEXT),DoubleToString(2500,_Digits))>=0,"label contains actual price");
   int objects=ObjectsTotal(0);SBVPDrawProfile(true);Check(ObjectsTotal(0)==objects,"repeat redraw creates no duplicate objects");
   ObjectsDeleteAll(0,SBVPObjectPrefix());sb_started=true;long lp=0;double dp=0;string sp="";OnChartEvent(CHARTEVENT_CHART_CHANGE,lp,dp,sp);sb_started=false;
   Check(SBVPObjectsPresent(),"chart-change handler recreates removed profile objects");
   sb_vp_profile.id="new-day-fixture";sb_vp_profile.poc=2501;SBVPDrawProfile(true);
   Check(ObjectsTotal(0)==objects && ObjectGetDouble(0,SBVPObjectPrefix()+"POC",OBJPROP_PRICE)==2501,"new frozen profile updates stable objects");
   sb_vp_profile.valid=false;SBVPDrawProfile(true);Check(!SBVPObjectsPresent(),"invalid profile removes stale levels");
   sb_vp_profile=saved;sb_vp_day=saved_day;
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   sb_object_prefix="SB.TEST.RANGE.";sb_instance="SB.TEST.RANGE.";sb_account=sb_instance+"R.";
   GlobalVariablesDeleteAll(sb_instance);sb_signal_after=TimeCurrent();
   UnitSuite();DrawingSuite();PrintFormat("RANGE_UNIT_RESULT | checks=%d failures=%d",checks,failures);
   return failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void RecoverAt(int minute,datetime utc)
  {
   ZeroMemory(sb_four);ZeroMemory(sb_four_range);sb_four_last=0;sb_four_replay_retry=0;
   ZeroMemory(sb_orb);ZeroMemory(sb_orb_range);sb_orb_replay_retry=0;
   sb_signal_after=TimeCurrent();
   if(minute==60 || minute==241 || minute==600)
     {
      SBEvaluate4H(utc,true);
      Check(minute==60?(sb_four_range.state=="RANGE_FORMING" && sb_four_range.valid>=60):(sb_four.ready && sb_four_range.valid==240),"ACTUAL_XAUUSD S1 NY minute "+IntegerToString(minute)+" "+sb_four_range.state+" "+sb_four_range.reason);
      if(sb_four.ready)
        {
         MqlRates exact[];CopyRates(_Symbol,PERIOD_M1,sb_four_range.from,sb_four_range.to-1,exact);double h=0,l=DBL_MAX;
         for(int i=0;i<ArraySize(exact);i++){h=MathMax(h,exact[i].high);l=MathMin(l,exact[i].low);}
         Check(h==sb_four.high && l==sb_four.low,"S1 extrema equal independent historical M1 scan");
         datetime last=sb_four_last;SBEvaluate4H(utc,false);Check(sb_four_last==last,"same S1 candle not replayed twice");
        }
     }
   if(minute>=480)
     {
      SBEvaluateORB(utc,true);
      Check(minute==480?sb_orb_range.state=="WAITING_FOR_SESSION":(minute==578?(sb_orb_range.state=="RANGE_FORMING" && sb_orb_range.valid>=8):(sb_orb.ready && sb_orb_range.valid==15)),"ACTUAL_XAUUSD ORB NY minute "+IntegerToString(minute)+" "+sb_orb_range.state+" "+sb_orb_range.reason);
      if(sb_orb.ready){datetime last=sb_orb.last;SBEvaluateORB(utc,false);Check(sb_orb.last==last,"same ORB candle not replayed twice");}
     }
   Check(PositionsTotal()==0 && OrdersTotal()==0,"range/setup replay never sends retroactive orders");
  }
bool SimulatedEntry(int strategy)
  {
   MqlTick q;if(!SymbolInfoTick(_Symbol,q))return false;
   MqlTradeRequest r={};MqlTradeResult result={};r.action=TRADE_ACTION_DEAL;r.symbol=_Symbol;r.magic=SBMagic(strategy);r.type=ORDER_TYPE_BUY;
   r.volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);r.price=q.ask;r.deviation=50;
   if(!SBFilling(r.type_filling))return false;
   return OrderSend(r,result) && result.retcode==TRADE_RETCODE_DONE;
  }
void RestartSuite(datetime utc)
  {
   datetime day,midnight,last;SBNYDay(utc,day,midnight);string why;
   Check(SimulatedEntry(SB_4H),"tester-only S1 entry accepted");
   Check(SimulatedEntry(SB_ORB) && SimulatedEntry(SB_ORB),"tester-only two independent ORB entries accepted");
   ZeroMemory(sb_four);ZeroMemory(sb_four_range);sb_four_last=0;ZeroMemory(sb_orb);ZeroMemory(sb_orb_range);
   SBEvaluate4H(utc,true);SBEvaluateORB(utc,true);
   Check(SBTradesTodayChecked(SB_4H,midnight,TimeCurrent(),last,why)==1,"S1 actual order history restores used daily slot after state reset");
   Check(SBTradesTodayChecked(SB_ORB,midnight,TimeCurrent(),last,why)==2,"ORB actual order history restores both daily slots after state reset");
   Check(SBOwnPositions(SB_4H)==1 && SBOwnPositions(SB_ORB)==2,"hedging positions recovered by independent magics");
   Check(SBTradesTodayChecked(SB_TRIANGLE,midnight,TimeCurrent(),last,why)==0,"restart counts remain strategy independent");
   MqlTick q;SymbolInfoTick(_Symbol,q);MqlTradeRequest request={};MqlTradeResult result={};
   request.action=TRADE_ACTION_PENDING;request.symbol=_Symbol;request.magic=InpORBMagicNumber;request.type=ORDER_TYPE_BUY_LIMIT;request.volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   request.price=SBRoundPrice(q.bid*.9,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),-1);request.type_filling=ORDER_FILLING_RETURN;
   Check(OrderSend(request,result) && result.retcode==TRADE_RETCODE_DONE,"tester-only independent pending order accepted");
   ZeroMemory(sb_orb);ZeroMemory(sb_orb_range);SBEvaluateORB(utc,true);
   Check(OrdersTotal()==1 && OrderGetTicket(0)>0 && (ulong)OrderGetInteger(ORDER_MAGIC)==InpORBMagicNumber,"pending order remains discoverable after ORB state recovery");
   // Production planner still checks reconstructed limits. Remove only fixture account gates.
   SBPut(sb_account+"halt",0);SBPut(sb_account+"intent",0);SBPut(sb_account+"daily_lock",0);
   Check(Inp4HMaxTradesPerNYDay==1 && InpORBMaxTradesPerNYDay==2,"existing daily caps unchanged");
  }
void OnTick()
  {
   datetime utc,ny;if(!SBServerToUTC(TimeCurrent(),utc) || !SBNYLocal(utc,ny))return;
   MqlDateTime t;TimeToStruct(ny,t);if(t.day!=3 || t.mon!=8 || t.year!=2026)return;
   int minute=t.hour*60+t.min;
   if(next_scenario<ArraySize(scenario_minute) && minute>=scenario_minute[next_scenario])
     {RecoverAt(scenario_minute[next_scenario],utc);next_scenario++;}
   if(next_scenario==ArraySize(scenario_minute) && restart_stage==0 && minute>=601)
     {RestartSuite(utc);restart_stage=1;PrintFormat("RANGE_TEST_RESULT | checks=%d failures=%d scenarios=%d restart=%d",checks,failures,next_scenario,restart_stage);}
  }
void OnDeinit(const int reason){ObjectsDeleteAll(0,sb_object_prefix);GlobalVariablesDeleteAll(sb_instance);}
double OnTester(){PrintFormat("RANGE_TEST_RESULT | checks=%d failures=%d scenarios=%d restart=%d",checks,failures,next_scenario,restart_stage);return failures==0 && next_scenario==6 && restart_stage==1?checks:-1;}
