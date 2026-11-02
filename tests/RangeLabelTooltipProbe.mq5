#property strict
#define OnInit SBProbeProductionInit
#define OnTick SBProbeProductionTick
#define OnTimer SBProbeProductionTimer
#define OnDeinit SBProbeProductionDeinit
#define OnTradeTransaction SBProbeProductionTransaction
#define OnTester SBProbeProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
void OnStart()
  {
   string path=TerminalInfoString(TERMINAL_DATA_PATH);StringToLower(path);StringReplace(path,"/","\\");
   if(MQLInfoInteger(MQL_TESTER) || StringFind(path,"\\scalping-bot\\artifacts\\test-terminal")<0)return;
   sb_object_prefix="SB.TEST.LABEL.PROBE.";
   SBHLine(SB_ORB,"H1_SWING_H",3919.14,clrSlateGray);
   string actual=ObjectGetString(0,sb_object_prefix+"ORB.H1_SWING_H",OBJPROP_TOOLTIP);
   bool ok=actual=="ORB REFERENCE - H1 SWING HIGH "+DoubleToString(3919.14,_Digits);
   int h=FileOpen("range_label_tooltip.txt",FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h!=INVALID_HANDLE){FileWrite(h,ok?"PASS":"FAIL");FileWrite(h,actual);FileClose(h);}
   Print("RANGE_LABEL_TOOLTIP_PROBE | ",ok?"PASS":"FAIL"," actual=",actual);
   ObjectsDeleteAll(0,sb_object_prefix);TerminalClose(0);
  }
