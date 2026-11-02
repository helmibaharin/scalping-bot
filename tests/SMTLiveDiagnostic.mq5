#property strict
// Read-only native history inspection. Does not initialize the EA or call orders.
#define OnInit SBDiagnosticInit
#define OnTick SBDiagnosticTick
#define OnTimer SBDiagnosticTimer
#define OnDeinit SBDiagnosticDeinit
#define OnTradeTransaction SBDiagnosticTransaction
#define OnTester SBDiagnosticTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int diagnostic=INVALID_HANDLE;
void Note(string message){Print("SMT_LIVE_DIAGNOSTIC | ",message);if(diagnostic!=INVALID_HANDLE)FileWrite(diagnostic,message);}
void Inspect(ENUM_TIMEFRAMES tf,datetime decision)
  {
   MqlRates bars[];int seconds=PeriodSeconds(tf),n=CopyRates(_Symbol,tf,decision-1,InpSMTLookbackBars+1,bars);
   while(n>0 && bars[n-1].time+seconds>decision)n--;ArrayResize(bars,n);
   Note(StringFormat("TF=%s decision=%s complete_bars=%d series_synced=%d",EnumToString(tf),TimeToString(decision),n,SeriesInfoInteger(_Symbol,tf,SERIES_SYNCHRONIZED)));
   if(n<1)return;
   Note("first="+TimeToString(bars[0].time)+" last="+TimeToString(bars[n-1].time));
   SBORBStructure st={};SBORBBreak event={};int highs=0,lows=0,resets=0;
   for(int i=0;i<n;i++)
     {
      if(i>0 && !SBSMTGapAllowed(bars[i-1].time,bars[i].time,seconds))
        {
         Note(StringFormat("RESET TF=%s before=%s after=%s highs_before=%d lows_before=%d",EnumToString(tf),TimeToString(bars[i-1].time),TimeToString(bars[i].time),highs,lows));
         for(datetime stamp=bars[i-1].time+seconds;stamp<bars[i].time;stamp+=seconds)
            if(SBSession(stamp+seconds/2)){Note("missing_session_midpoint="+TimeToString(stamp+seconds/2));break;}
         ZeroMemory(st);highs=0;lows=0;resets++;
        }
      datetime old_high=st.high.time,old_low=st.low.time;
      SBORBStructureStep(st,bars,i,InpSMTPivotLeft,InpSMTPivotRight,seconds,InpSMTBOSClearancePoints*_Point,event);
      if(st.high.time!=old_high)highs++;if(st.low.time!=old_low)lows++;
     }
   MqlRates loaded[];bool ok=SBSMTLoad(tf,decision,InpSMTLookbackBars,loaded);
   Note(StringFormat("RESULT TF=%s load_ok=%d raw_trend=%s highs=%d lows=%d resets=%d returned_trend=%s",EnumToString(tf),ok,SBSMTTrendName(SBSMTClassify(st,highs,lows)),highs,lows,resets,SBSMTTrendName(SBSMTLoadTrend(tf,decision))));
  }
void OnStart()
  {
   string path=TerminalInfoString(TERMINAL_DATA_PATH);StringToLower(path);StringReplace(path,"/","\\");
   if(MQLInfoInteger(MQL_TESTER) || StringFind(path,"\\scalping-bot\\artifacts\\test-terminal")<0)return;
   if(!SymbolSelect("XAUUSD",true) || _Symbol!="XAUUSD"){TerminalClose(0);return;}
   diagnostic=FileOpen("smt_live_diagnostic.txt",FILE_WRITE|FILE_TXT|FILE_ANSI);
   ENUM_TIMEFRAMES frames[]={PERIOD_D1,PERIOD_H4,PERIOD_H1,PERIOD_M15};
   ulong started=GetTickCount64();bool ready=false;
   while(GetTickCount64()-started<45000 && !IsStopped())
     {
      ready=true;for(int i=0;i<ArraySize(frames);i++){MqlRates warm[];if(CopyRates(_Symbol,frames[i],0,301,warm)<100)ready=false;}
      if(ready && TimeCurrent()>D'2026.11.02')break;Sleep(200);
     }
   datetime decision=TimeCurrent();Note("MODE=READ_ONLY_NATIVE_HISTORY account_server="+AccountInfoString(ACCOUNT_SERVER)+" ready="+IntegerToString(ready));
   for(int day=0;day<7;day++)for(uint session=0;session<20;session++)
     {
      datetime a,b;if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)day,session,a,b))break;
      Note(StringFormat("SESSION day=%d index=%u raw_start=%I64d raw_end=%I64d",day,session,(long)a,(long)b));
     }
   for(int i=0;i<ArraySize(frames);i++)Inspect(frames[i],decision);
   if(diagnostic!=INVALID_HANDLE)FileClose(diagnostic);
   TerminalClose(0);
  }
