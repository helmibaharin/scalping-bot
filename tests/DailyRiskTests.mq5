#property strict
#include "../MQL5/Include/ScalpingBot/Config.mqh"
bool test_daily=true,test_broker=true,test_emergency=false;
int test_reset=0;
double test_daily_percent=1.0;
#define InpEnableDailyRiskLock test_daily
#define InpRiskBrokerDay test_broker
#define InpResetToken test_reset
#define InpEmergency test_emergency
#define InpDailyLossPercent test_daily_percent
#define OnInit SBDailyProductionInit
#define OnTick SBDailyProductionTick
#define OnTimer SBDailyProductionTimer
#define OnDeinit SBDailyProductionDeinit
#define OnTradeTransaction SBDailyProductionTransaction
#define OnTester SBDailyProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int daily_checks=0,daily_failures=0;
void DailyCheck(bool ok,string why){daily_checks++;Print(ok?"DAILY_RISK_ASSERT_PASS | ":"DAILY_RISK_ASSERT_FAIL | ",why);if(!ok)daily_failures++;}
void DailyFresh(bool broker,bool enabled)
  {
   sb_account="SB.TEST.DAILY_SWITCH."+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+".";
   GlobalVariablesDeleteAll(sb_account);sb_state_ok=true;test_daily=enabled;test_broker=broker;test_emergency=false;test_reset=0;test_daily_percent=1.0;
  }
void DailySuite(bool broker)
  {
   DailyFresh(broker,true);datetime utc=TimeCurrent()-120*60;double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   DailyCheck(SBUpdateAccount(utc),"default enabled account initializes");
   DailyCheck(SBRiskSignature()==SBRiskBaseSignature(),"enabled mode preserves old policy signature");
   DailyCheck(SBGet(sb_account+"daily_lock")==1,"default first attachment remains locked");
   SBPut(sb_account+"peak",equity*1.01);SBPut(sb_account+"halt",1);SBPut(sb_account+"intent",42);
   test_daily=false;
   DailyCheck(SBUpdateAccount(utc),"opt-out migrates an existing baseline lock without reset token");
   DailyCheck(SBGet(sb_account+"signature")==SBRiskSignature() && SBRiskSignature()!=SBRiskBaseSignature(),"disabled policy is distinct and persisted");
   DailyCheck(SBGet(sb_account+"peak")==equity*1.01,"disable preserves drawdown high-water mark");
   DailyCheck(SBGet(sb_account+"halt")==1 && SBGet(sb_account+"intent")==42,"disable preserves emergency latch and pending intent");
   DailyCheck(SBGet(sb_account+"reset")==0,"disable does not increment or consume reset token");
   DailyCheck(SBUpdateAccount(utc),"disabled policy survives another account-state update");
   test_daily=true;
   DailyCheck(!SBUpdateAccount(utc),"stale enabled controller cannot silently overwrite disabled account policy");
   test_reset=1;
   DailyCheck(!SBUpdateAccount(utc),"re-enable cannot bypass pending intent even with a token");
   SBPut(sb_account+"intent",0);
   DailyCheck(SBUpdateAccount(utc),"explicit flat-account reset permits re-enable");
   DailyCheck(SBGet(sb_account+"daily_lock")==1 && SBGet(sb_account+"signature")==SBRiskBaseSignature(),"re-enable restores daily baseline wait");
   DailyFresh(broker,false);
   DailyCheck(SBUpdateAccount(utc),"new disabled account initializes without a policy mismatch");
   DailyCheck(SBGet(sb_account+"signature")==SBRiskSignature(),"fresh opt-out signature is durable");
   SBPut(sb_account+"peak",equity*1.10);
   DailyCheck(SBUpdateAccount(utc) && SBGet(sb_account+"halt")==1,"maximum drawdown still latches when daily gate is disabled");
   DailyFresh(broker,false);SBUpdateAccount(utc);test_emergency=true;
   DailyCheck(SBUpdateAccount(utc) && SBGet(sb_account+"halt")==1,"emergency input still latches when daily gate is disabled");
   DailyFresh(broker,true);SBUpdateAccount(utc);test_daily_percent=1.5;test_daily=false;
   DailyCheck(!SBUpdateAccount(utc),"opt-out cannot migrate unrelated changed account-risk settings");
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   DailySuite(true);DailySuite(false);
   PrintFormat("DAILY_RISK_TEST_RESULT | checks=%d failures=%d",daily_checks,daily_failures);
   return daily_failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
void OnDeinit(const int reason){if(StringFind(sb_account,"SB.TEST.DAILY_SWITCH.")==0)GlobalVariablesDeleteAll(sb_account);}
double OnTester(){PrintFormat("DAILY_RISK_TEST_RESULT | checks=%d failures=%d",daily_checks,daily_failures);return daily_failures==0?daily_checks:-daily_failures;}
