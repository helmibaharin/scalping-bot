#property strict
// Read-only native replay of today's already completed screenshot candles.
// Runs only in the disposable workspace terminal; no order functions are called.
#include "../MQL5/Include/ScalpingBot/Config.mqh"
bool screenshot_draw=false;
#define InpDrawObjects screenshot_draw
#define OnInit SBScreenshotProductionInit
#define OnTick SBScreenshotProductionTick
#define OnTimer SBScreenshotProductionTimer
#define OnDeinit SBScreenshotProductionDeinit
#define OnTradeTransaction SBScreenshotProductionTransaction
#define OnTester SBScreenshotProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int checks=0,failures=0;
void Check(bool ok,string reason){checks++;Print(ok?"SHAPE_SCREENSHOT_ASSERT_PASS | ":"SHAPE_SCREENSHOT_ASSERT_FAIL | ",reason);if(!ok)failures++;}
void SaveBars(string name,MqlRates &bars[])
  {
   int h=FileOpen(name,FILE_WRITE|FILE_CSV|FILE_ANSI,',');if(h==INVALID_HANDLE){Check(false,"export file available");return;}
   FileWrite(h,"broker_time","open","high","low","close","tick_volume");
   for(int i=0;i<ArraySize(bars);i++)FileWrite(h,(long)bars[i].time,bars[i].open,bars[i].high,bars[i].low,bars[i].close,bars[i].tick_volume);
   FileClose(h);
  }
void OnStart()
  {
   string path=TerminalInfoString(TERMINAL_DATA_PATH);StringToLower(path);StringReplace(path,"/","\\");
   if(MQLInfoInteger(MQL_TESTER) || StringFind(path,"\\scalping-bot\\artifacts\\test-terminal")<0)
     {Print("SHAPE_SCREENSHOT_REFUSED | disposable workspace terminal only");return;}
   if(!SymbolSelect("XAUUSD",true) || _Symbol!="XAUUSD"){Print("SHAPE_SCREENSHOT_REFUSED | XAUUSD chart required");TerminalClose(0);return;}
   datetime decision=D'2026.11.02 13:15';MqlRates old[],fresh[],entry[];
   bool loaded=false;ulong start=GetTickCount64();
   while(GetTickCount64()-start<60000 && !IsStopped())
     {
      if(TimeCurrent()>=decision && SBShapeLoad(PERIOD_M15,decision-300,InpShapeLookback,old) &&
         SBShapeLoad(PERIOD_M15,decision,InpShapeLookback,fresh) && CopyRates(_Symbol,PERIOD_M5,decision-600,decision-1,entry)==2)
        {loaded=true;break;}
      Sleep(200);
     }
   Check(loaded,"closed screenshot history loaded with exact broker-time cutoff");
   sb_instance="SB.TEST.SCREENSHOT.";sb_object_prefix=sb_instance;
   if(loaded)
     {
      Check(fresh[ArraySize(fresh)-1].time==D'2026.11.02 13:00' && old[ArraySize(old)-1].time==D'2026.11.02 12:45',"new cutoff includes 13:00-13:15 formation candle that old cutoff withheld");
      bool future=false;for(int i=0;i<ArraySize(fresh);i++)if(fresh[i].time+900>decision)future=true;
      Check(!future,"no post-13:15 candle included in screenshot replay");
      SBShapePattern old_patterns[],patterns[];SBShapeDetect(old,ArraySize(old)-1,old_patterns);SBShapeDetect(fresh,ArraySize(fresh)-1,patterns);
      bool was_known=false,found=false;
      for(int i=0;i<ArraySize(old_patterns);i++)if(old_patterns[i].id=="1357682230")was_known=true;
      Check(!was_known,"old cutoff cannot yet confirm screenshot triangle");
      for(int i=0;i<ArraySize(patterns);i++)if(patterns[i].id=="1357682230")
        {
         found=true;Check(patterns[i].known==decision,"actual screenshot pivots confirm at 13:15");
         Check(SBShapeAdd(patterns[i],decision),"screenshot triangle enters production candidate registry immediately");
         int index=ArraySize(sb_shapes)-1;
         Check(sb_shapes[index].available==decision,"production candidate availability is 13:15 instead of 13:20");
         SBORBBreak event={};SBShapeDecisionStep(sb_shapes[index],entry[1],entry[0],event,0,300);
         Print("SHAPE_SCREENSHOT_DECISION | at=",TimeToString(decision,TIME_DATE|TIME_SECONDS)," id=",patterns[i].id," phase=",SBShapePhaseName(sb_shapes[index].phase)," reason=",sb_shapes[index].reason);
        }
      Check(found,"same anchored triangle ID as user screenshot found from historical market candles");
      SaveBars("shape_timing_screenshot_m15.csv",fresh);SaveBars("shape_timing_screenshot_m5.csv",entry);
     }
   int receipt=FileOpen("shape_timing_screenshot_result.json",FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(receipt!=INVALID_HANDLE)
     {
      FileWrite(receipt,StringFormat("{\"status\":\"%s\",\"checks\":%d,\"failures\":%d,\"cutoff_broker\":\"2026.11.02 13:15\",\"pattern_id\":\"1357682230\",\"mode\":\"READ_ONLY_NATIVE_CLOSED_HISTORY_REPLAY\"}",failures==0?"PASS":"FAIL",checks,failures));FileClose(receipt);
     }
   PrintFormat("SHAPE_SCREENSHOT_TEST_RESULT | checks=%d failures=%d",checks,failures);TerminalClose(0);
  }
