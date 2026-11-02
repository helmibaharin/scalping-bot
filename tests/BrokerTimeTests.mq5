#property strict
#include "../MQL5/Include/ScalpingBot/Config.mqh"
// Inject mutable test settings into unchanged production functions; actual input defaults remain untouched.
bool test_verified=true;
SB_BROKER_DST test_rule=SB_FIXED;
int test_winter=120,test_summer=180;
datetime test_from=D'2007.01.01',test_until=D'2038.01.01';
string test_table="";
#define InpBrokerTimeVerified test_verified
#define InpBrokerDSTRule test_rule
#define InpBrokerWinterUTCMinutes test_winter
#define InpBrokerSummerUTCMinutes test_summer
#define InpBrokerMappingFromUTC test_from
#define InpBrokerMappingUntilUTC test_until
#define InpBrokerUTCTransitions test_table
#define OnInit SBTimeProductionInit
#define OnTick SBTimeProductionTick
#define OnTimer SBTimeProductionTimer
#define OnDeinit SBTimeProductionDeinit
#define OnTradeTransaction SBTimeProductionTransaction
#define OnTester SBTimeProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int clock_checks=0,clock_failures=0;
void Check(bool ok,string name){clock_checks++;if(!ok){clock_failures++;Print("BROKER_TIME_ASSERT_FAIL | ",name);}else Print("BROKER_TIME_ASSERT_PASS | ",name);}
void Defaults(){test_verified=true;test_rule=SB_FIXED;test_winter=120;test_summer=180;test_from=D'2007.01.01';test_until=D'2038.01.01';test_table="";}
void BadTable(string value,string name){test_table=value;string why="";Check(!SBMappingConfigValid(why) && why!="",name);}
void RunClockTests()
  {
   Defaults();datetime utc=99,server=99,ny=0,day=0,midnight=0,last=99;string why="";
   test_verified=false;
   Check(!SBServerToUTCChecked(D'2026.08.03',utc,why) && utc==0 && why=="BROKER_MAPPING_NOT_VERIFIED","unverified inverse gives explicit reason and no output");
   Check(!SBUTCToServerChecked(D'2026.08.03',server,why) && server==0 && why=="BROKER_MAPPING_NOT_VERIFIED","unverified forward stays blocked");
   Check(SBTradesTodayChecked(SB_4H,D'2026.08.03',TimeCurrent(),last,why)==-1 && last==0 && why=="BROKER_MAPPING_NOT_VERIFIED","count unavailable retains safety sentinel and clears fill time");
   Check(SBTradeCountText(-1,1,why)=="UNKNOWN (BROKER_MAPPING_NOT_VERIFIED)/1","dashboard does not display negative trade count");
   Check(SBTradeCountText(0,1,"")=="0/1" && SBTradeCountText(1,2,"")=="1/2","known zero and one remain exact");
   Check(StringFind(SBTradeCountText(-1,1,"DEAL_HISTORY_UNAVAILABLE"),"DEAL_HISTORY_UNAVAILABLE")>=0,"dashboard distinguishes unavailable broker history");
   Defaults();Check(SBUTCToServer(D'2026.08.03 12:00',server) && server==D'2026.08.03 14:00',"fixed uses winter offset even in summer");
   Check(SBServerToUTC(server,utc) && utc==D'2026.08.03 12:00',"fixed inverse roundtrip");
   test_winter=345;Check(SBUTCToServer(D'2026.08.03 22:30',server) && server==D'2026.08.04 04:15',"fractional-hour positive offset crosses day");
   Check(SBServerToUTC(server,utc) && utc==D'2026.08.03 22:30',"fractional-hour inverse");
   test_winter=-330;Check(SBUTCToServer(D'2026.08.03 02:00',server) && server==D'2026.08.02 20:30',"negative offset crosses previous day");
   Defaults();Check(!SBUTCToServerChecked(test_until,server,why) && why=="BROKER_MAPPING_OUTSIDE_UTC_COVERAGE","upper coverage exclusive");
   Check(!SBUTCToServerChecked(test_from-1,server,why),"lower coverage outside");
   Check(SBUTCToServer(test_from,server),"lower coverage inclusive");
   test_winter=841;Check(!SBMappingConfigValid(why),"invalid offset rejected");
   Defaults();test_from=D'1986.01.01';Check(!SBMappingConfigValid(why),"unsupported NY history fails closed");
   Defaults();test_rule=SB_EU;test_from=D'1995.01.01';Check(!SBMappingConfigValid(why),"pre-1996 European rule not silently extrapolated");
   Defaults();test_rule=SB_EU;
   Check(SBUTCToServer(D'2026.03.29 00:59:59',server) && server==D'2026.03.29 02:59:59',"EU exact second before spring change");
   Check(SBUTCToServer(D'2026.03.29 01:00',server) && server==D'2026.03.29 04:00',"EU spring transition at 01 UTC");
   Check(!SBServerToUTCChecked(D'2026.03.29 03:30',utc,why) && why=="BROKER_MAPPING_SERVER_GAP","EU missing server hour rejected");
   Check(SBUTCToServer(D'2026.10.25 00:59:59',server) && server==D'2026.10.25 03:59:59',"EU second before autumn transition");
   Check(SBUTCToServer(D'2026.10.25 01:00',server) && server==D'2026.10.25 03:00',"EU fall transition exact boundary");
   Check(!SBServerToUTCChecked(D'2026.10.25 03:30',utc,why) && why=="BROKER_MAPPING_SERVER_FOLD_AMBIGUOUS","EU repeated server hour rejected");
   Check(SBServerToUTC(D'2026.10.25 04:00',utc) && utc==D'2026.10.25 02:00',"EU unique after fold");
   test_rule=SB_US;
   Check(SBBrokerOffset(D'2026.03.08 06:59:59')==120 && SBBrokerOffset(D'2026.03.08 07:00')==180,"US mode explicitly uses NY transition instants");
   Check(SBBrokerOffset(D'2026.11.01 05:59:59')==180 && SBBrokerOffset(D'2026.11.01 06:00')==120,"US fall exact transition");
   Check(SBNYLocal(D'2006.03.20 12:00',ny) && ny==D'2006.03.20 07:00',"pre-2007 NY remains EST in March");
   Check(SBNYLocal(D'2006.04.02 07:00',ny) && ny==D'2006.04.02 03:00',"1987-2006 NY spring calendar");
   Check(SBNYLocal(D'2007.03.11 07:00',ny) && ny==D'2007.03.11 03:00',"2007 NY rule change");
   Check(SBNYLocal(D'2026.03.08 06:59:59',ny) && ny==D'2026.03.08 01:59:59',"NY exact second before spring");
   Check(SBNYLocal(D'2026.03.08 07:00',ny) && ny==D'2026.03.08 03:00',"NY spring gap");
   Check(SBNYLocal(D'2026.11.01 06:00',ny) && ny==D'2026.11.01 01:00',"NY autumn fold");
   Check(!SBORBNYToUTC(D'2026.11.01 01:30',utc) && !SBORBNYToUTC(D'2026.03.08 02:30',utc),"production ORB NY inverse rejects repeated and missing local hours");
   Check(SBORBSessionUTC(D'2026.03.06',utc,server) && utc==D'2026.03.06 14:30',"ORB 09:30 NY before US spring");
   Check(SBORBSessionUTC(D'2026.03.09',utc,server) && utc==D'2026.03.09 13:30',"ORB 09:30 NY after US spring before EU spring");
   Check(SBORBSessionUTC(D'2026.10.26',utc,server) && utc==D'2026.10.26 13:30',"ORB after EU fall before US fall");
   Check(SBORBSessionUTC(D'2026.11.02',utc,server) && utc==D'2026.11.02 14:30',"ORB after US fall");
   Check(SBNYDay(D'2026.03.08 12:00',day,midnight) && midnight==D'2026.03.08 05:00',"spring NY midnight correct");
   Check(SBNYLocal(midnight+14400,ny) && ny!=day+14400,"existing 4H rejects three-hour spring 00-04 day");
   Check(SBNYDay(D'2026.11.01 12:00',day,midnight) && midnight==D'2026.11.01 04:00',"autumn NY midnight correct");
   Check(SBNYLocal(midnight+14400,ny) && ny!=day+14400,"existing 4H rejects five-hour autumn 00-04 day");
   Defaults();test_rule=SB_EU;
   for(int y=2025;y<=2027;y++)
     {
      datetime a,b;SBORBSessionUTC(SBDate(y,3,SBSunday(y,3,2)+1),a,b);
      Check(SBUTCToServer(a,server) && server==a+7200,"US/EU spring mismatch week uses separate broker and NY DST");
      SBORBSessionUTC(SBDate(y,10,SBLastSunday(y,10)+1),a,b);
      Check(SBUTCToServer(a,server) && server==a+7200,"EU/US fall mismatch week uses separate broker and NY DST");
     }
   Defaults();test_rule=SB_UTC_TABLE;test_from=D'2026.01.01';test_until=D'2027.01.01';
   test_table="2026.01.01 00:00=120;2026.03.08 00:00=180;2026.11.01 00:00=120";
   Check(SBMappingConfigValid(why) && ArraySize(sb_mapping_starts)==3,"explicit broker UTC transition table validates");
   Check(SBUTCToServer(D'2026.03.07 23:59:59',server) && server==D'2026.03.08 01:59:59',"custom second before broker-specific change");
   Check(SBUTCToServer(D'2026.03.08 00:00',server) && server==D'2026.03.08 03:00',"custom transition differs from built-in US instant");
   Check(!SBServerToUTCChecked(D'2026.03.08 02:30',utc,why) && why=="BROKER_MAPPING_SERVER_GAP","custom forward gap rejected");
   Check(!SBServerToUTCChecked(D'2026.11.01 02:30',utc,why) && why=="BROKER_MAPPING_SERVER_FOLD_AMBIGUOUS","custom autumn ambiguity rejected");
   Check(SBServerToUTC(D'2026.11.01 04:00',utc) && utc==D'2026.11.01 02:00',"custom unique post-fall conversion");
   test_table="2026.01.01 00:00=120;2026.03.08 00:00=180;2026.11.01 00:00=150";
   Check(SBUTCToServer(D'2026.11.01 01:00',server) && server==D'2026.11.01 03:30',"more than two custom offsets and half-hour policy change");
   Check(!SBServerToUTCChecked(D'2026.11.01 02:45',utc,why) && why=="BROKER_MAPPING_SERVER_FOLD_AMBIGUOUS","half-hour fold rejected");
   BadTable("","empty table rejected");BadTable("2026.01.01 00:00=120;","trailing separator rejected");
   BadTable("2026.01.02 00:00=120","first row must begin coverage");
   BadTable("2026.01.01 00:00=120;2026.01.01 00:00=180","duplicate UTC instant rejected");
   BadTable("2026.01.01 00:00=120;2026.03.01 00:00=180;2026.02.01 00:00=120","unordered rows rejected");
   BadTable("2026.01.01 00:00=120;2027.01.01 00:00=180","row outside exclusive coverage rejected");
   BadTable("2026.01.01 00:00=120;2026.02.30 00:00=180","normalized invalid date rejected");
   BadTable("2026.01.01=120","incomplete timestamp not inferred");
   BadTable("2026.01.01 00:00=+120","noncanonical number rejected");
   BadTable("2026.01.01 00:00=120x","noninteger offset rejected");
   BadTable("2026.01.01 00:00=841","oversized custom offset rejected");
   Defaults();Check(SBTradesTodayChecked(SB_4H,D'2026.08.02 22:00',TimeCurrent(),last,why)==0,"actual empty tester history returns known zero");
   Check(SBTradesTodayChecked(SB_4H,D'2037.01.01',TimeCurrent(),last,why)==-1 && why=="TRADE_HISTORY_INTERVAL_INVALID","future history interval stays unknown instead of becoming an empty zero");
   Check(StringFind(SBBrokerClockText(TimeCurrent()),"NY=")>=0,"clock diagnostic exposes UTC and NY mapping");
  }
int OnInit(){if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;RunClockTests();PrintFormat("BROKER_TIME_TEST_RESULT | checks=%d failures=%d",clock_checks,clock_failures);return clock_failures==0?INIT_SUCCEEDED:INIT_FAILED;}
void OnTick(){}
double OnTester(){PrintFormat("BROKER_TIME_TEST_RESULT | checks=%d failures=%d",clock_checks,clock_failures);return clock_failures==0?clock_checks:-clock_failures;}
