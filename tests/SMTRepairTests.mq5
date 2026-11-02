#property strict
// Use actual trap/runtime logic with only the two history API boundaries replaced.
#include "../MQL5/Include/ScalpingBot/Config.mqh"
#include "../MQL5/Include/ScalpingBot/StrategyInterface.mqh"
#include "../MQL5/Include/ScalpingBot/SetupExitPolicy.mqh"
#include "../MQL5/Include/ScalpingBot/Rules.mqh"
#include "../MQL5/Include/ScalpingBot/NewYorkTime.mqh"
#include "../MQL5/Include/ScalpingBot/Diagnostics.mqh"
#include "../MQL5/Include/ScalpingBot/SessionRange.mqh"
#include "../MQL5/Include/ScalpingBot/ORBExternal.mqh"
#include "../MQL5/Include/ScalpingBot/StatePersistence.mqh"
#include "../MQL5/Include/ScalpingBot/SMTContext.mqh"
#include "../MQL5/Include/ScalpingBot/ShapeEngine.mqh"
#include "../MQL5/Include/ScalpingBot/VolumeProfileSessions.mqh"
#include "../MQL5/Include/ScalpingBot/TradeLedger.mqh"
#include "../MQL5/Include/ScalpingBot/VolumeProfilePolicy.mqh"
#include "../MQL5/Include/ScalpingBot/RiskManager.mqh"
#include "../MQL5/Include/ScalpingBot/TradeExecutor.mqh"
bool repair_load_ok=true,repair_context_ok=false;int repair_context_calls=0;
datetime repair_context_at=0;MqlRates repair_traps[];
bool RepairLoad(ENUM_TIMEFRAMES tf,datetime decision,int count,MqlRates &bars[])
  {if(!repair_load_ok)return false;ArrayCopy(bars,repair_traps);return true;}
bool RepairContext(datetime decision,bool locations)
  {repair_context_calls++;repair_context_at=decision;return repair_context_ok;}
#define SBSMTLoad RepairLoad
#define SBSMTContext RepairContext
#include "../MQL5/Include/ScalpingBot/SmartMoneyTrap.mqh"
#undef SBSMTLoad
#undef SBSMTContext
#define OnInit SBRepairProductionInit
#define OnTick SBRepairProductionTick
#define OnTimer SBRepairProductionTimer
#define OnDeinit SBRepairProductionDeinit
#define OnTradeTransaction SBRepairProductionTransaction
#define OnTester SBRepairProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int repair_checks=0,repair_failures=0;bool runtime_checked=false;
void Check(bool ok,string why){repair_checks++;if(!ok)repair_failures++;Print(ok?"SMT_REPAIR_PASS | ":"SMT_REPAIR_FAIL | ",why);}
void Suite()
  {
   Check(!SBSessionContains(0,0,0,false) && !SBSessionContains(0,0,43200,false),"zero-duration Saturday row is closed");
   Check(SBSessionContains(0,86400,0,false) && SBSessionContains(0,86400,86399,false),"genuine 24h session stays open");
   Check(!SBSessionContains(0,86400,0,true),"midnight end is exclusive and has no next-day spill");
   Check(!SBSessionContains(3600,82800,3599,false) && SBSessionContains(3600,82800,3600,false) && !SBSessionContains(3600,82800,82800,false),"ordinary session endpoints remain half-open");
   Check(SBSessionContains(79200,7200,80000,false) && !SBSessionContains(79200,7200,3600,false),"overnight start applies to its starting day");
   Check(SBSessionContains(79200,7200,7199,true) && !SBSessionContains(79200,7200,7200,true),"overnight end applies only to previous-day spill");
   Check(SBSessionContains(79200,93600,3600,true),"explicit next-day raw endpoint retains overnight spill");
   Check(SBSessionContains(3600,90000,3600,false) && !SBSessionContains(3600,90000,0,false) && SBSessionContains(3600,90000,0,true),"24h session starting at 01:00 retains correct day attribution");
   Check(!SBSessionContains(-1,86400,0,false) && !SBSessionContains(0,172800,0,false),"invalid session intervals fail closed");
   Check(!SBSession(D'2026.10.31 12:00'),"actual broker Saturday zero row is not tradable");
   Check(SBSMTGapAllowed(D'2026.10.30',D'2026.11.02',86400),"actual broker D1 weekend gap preserves trend history");
   Check(SBSMTGapAllowed(D'2026.10.30 20:00',D'2026.11.02',14400),"actual broker H4 weekend gap preserves trend history");
   Check(!SBSMTGapAllowed(D'2026.11.02 10:00',D'2026.11.02 12:00',3600),"missing weekday tradable candle still fails validation");
   Check(SBSMTTrendRejectReason(SMT_INSUFFICIENT)=="SMT_TREND_INSUFFICIENT_DATA" && SBSMTTrendRejectReason(SMT_NEUTRAL)=="SMT_TREND_NEUTRAL" && SBSMTTrendRejectReason(-1)=="SMT_TREND_MISMATCH","history deficiency is distinct from neutral/opposing trend");
   ZeroMemory(sb_smt);sb_smt_wait="";ArrayResize(repair_traps,3);
   datetime decision=D'2026.08.03 10:15';int seconds=PeriodSeconds(InpSMTTrapTF);
   for(int i=0;i<3;i++){ZeroMemory(repair_traps[i]);repair_traps[i].time=decision-(3-i)*seconds;repair_traps[i].open=100;repair_traps[i].close=100;repair_traps[i].low=99;repair_traps[i].high=101;}
   repair_load_ok=false;
   Check(!SBSMTCheckTrap(decision) && sb_smt.last_trap==0,"pending trap history does not commit trap cursor");
   repair_load_ok=true;repair_context_ok=false;
   Check(!SBSMTCheckTrap(decision) && sb_smt.last_trap==0 && repair_context_calls==1,"pending zone history leaves same trap retryable");
   Check(!SBSMTCheckTrap(decision) && repair_context_calls==2 && sb_smt.last_trap==0,"same exact trap snapshot retries without a later candle");
   repair_context_ok=true;
   Check(SBSMTCheckTrap(decision) && sb_smt.last_trap==repair_traps[2].time && repair_context_calls==3 && repair_context_at==repair_traps[2].time,"successful context commits original pre-trap snapshot only after history loads");
   Check(SBSMTCheckTrap(decision) && repair_context_calls==3,"already evaluated trap is idempotent");
   ZeroMemory(sb_smt);repair_context_ok=false;
   Check(SBSMTCheckTrap(decision+seconds) && sb_smt.last_trap==repair_traps[2].time,"stale trap retires without chasing a later quote");
   Check(OrdersTotal()==0 && PositionsTotal()==0,"history retry checks send no orders");
  }
int OnInit(){if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;Suite();PrintFormat("SMT_REPAIR_TEST_RESULT | checks=%d failures=%d",repair_checks,repair_failures);return repair_failures==0?INIT_SUCCEEDED:INIT_FAILED;}
void OnTick()
  {
   if(runtime_checked)return;
   datetime latest=iTime(_Symbol,InpSMTEntryTF,1);int seconds=PeriodSeconds(InpSMTEntryTF),trap_seconds=PeriodSeconds(InpSMTTrapTF);
   if(latest<=0 || (long)latest%trap_seconds!=0)return;
   ZeroMemory(sb_smt);sb_smt.last=latest-seconds;repair_load_ok=false;
   SBEvaluateSMT(false);Check(sb_smt.last==latest-seconds,"runtime retains entry cursor while trap history is pending");
   for(int i=0;i<3;i++)repair_traps[i].time=latest-(3-i)*trap_seconds;
   repair_load_ok=true;repair_context_ok=false;
   SBEvaluateSMT(false);Check(sb_smt.last==latest-seconds && sb_smt.last_trap==0,"runtime retains both cursors while zone history is pending");
   repair_context_ok=true;
   SBEvaluateSMT(false);Check(sb_smt.last==latest && sb_smt.last_trap==latest-trap_seconds,"same completed entry candle resumes after history succeeds");
   runtime_checked=true;
  }
double OnTester(){Check(runtime_checked,"runtime retry exercised against actual entry history");PrintFormat("SMT_REPAIR_TEST_RESULT | checks=%d failures=%d runtime=%d",repair_checks,repair_failures,runtime_checked);return repair_failures==0 && runtime_checked?repair_checks:-1;}
