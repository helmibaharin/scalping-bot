#property strict
#include "../MQL5/Include/ScalpingBot/Config.mqh"
bool range_test_draw=true;
#define InpDrawObjects range_test_draw
#define OnInit SBLabelProductionInit
#define OnTick SBLabelProductionTick
#define OnTimer SBLabelProductionTimer
#define OnDeinit SBLabelProductionDeinit
#define OnTradeTransaction SBLabelProductionTransaction
#define OnTester SBLabelProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int label_checks=0,label_failures=0;
void Check(bool ok,string reason){label_checks++;if(!ok)label_failures++;Print(ok?"RANGE_LABEL_PASS | ":"RANGE_LABEL_FAIL | ",reason);}
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   sb_object_prefix="SB.TEST.RANGE.LABEL.";
   string a=sb_object_prefix+"4H.2026.11.02.rangeHigh",b=sb_object_prefix+"ORB.H1_SWING_H",c=sb_object_prefix+"ORB.rangeHigh";
   SBHLine(SB_4H,"2026.11.02.rangeHigh",3919.14,clrOrange);
   SBHLine(SB_ORB,"H1_SWING_H",3919.14,clrSlateGray);
   SBHLine(SB_ORB,"rangeHigh",3919.14,clrOrangeRed);
   Check(ObjectFind(0,a)>=0 && ObjectFind(0,b)>=0 && ObjectFind(0,c)>=0,"coincident S1 range, ORB H1 reference and ORB range remain separate objects");
   Check(ObjectGetDouble(0,a,OBJPROP_PRICE)==3919.14 && ObjectGetDouble(0,b,OBJPROP_PRICE)==3919.14,"overlapping screenshot prices are preserved");
   Check(ObjectGetString(0,a+".label",OBJPROP_TEXT)=="S1 4H RANGE HIGH 3919.14","S1 range has explicit visible high label");
   Check(ObjectGetString(0,c+".label",OBJPROP_TEXT)=="S3 ORB RANGE HIGH 3919.14","ORB range has its own visible high label");
   Print("RANGE_LABEL_TOOLTIP | actual=[",ObjectGetString(0,b,OBJPROP_TOOLTIP),"] description=[",ObjectGetString(0,b,OBJPROP_TEXT),"]");
   Check(ObjectGetString(0,b,OBJPROP_TEXT)=="ORB REFERENCE - H1 SWING HIGH 3919.14","grey H1 reference description clearly identifies its purpose (tooltip checked outside tester)");
   Check(ObjectFind(0,b+".label")<0,"reference tooltip does not add more chart labels");
   Check(ObjectGetInteger(0,a+".label",OBJPROP_ANCHOR)!=ObjectGetInteger(0,c+".label",OBJPROP_ANCHOR),"coincident S1/ORB range labels sit on opposite sides of their line");
   SBHLine(SB_ORB,"rangeHigh",3920,clrOrangeRed);
   Check(ObjectGetDouble(0,a,OBJPROP_PRICE)==3919.14 && ObjectGetDouble(0,b,OBJPROP_PRICE)==3919.14 && ObjectGetDouble(0,c,OBJPROP_PRICE)==3920,"updating ORB cannot move S1 or its H1 reference");
   SBHLine(SB_4H,"2026.11.02.rangeLow",3890.99,clrOrange);SBHLine(SB_ORB,"rangeLow",3890.99,clrOrangeRed);
   Check(SBRangeLineCaption(SB_4H,"2026.11.02.rangeLow")=="S1 4H RANGE LOW" && SBRangeLineCaption(SB_ORB,"rangeLow")=="S3 ORB RANGE LOW","high/low captions never swap strategies");
   Check(SBRangeLineCaption(SB_ORB,"H4_SWING_H")=="ORB REFERENCE - H4 SWING HIGH" && SBRangeLineCaption(SB_ORB,"H4_SWING_L")=="ORB REFERENCE - H4 SWING LOW","H4 references are distinct from S1's NY range");
   Check(SBRangeLineCaption(SB_4H,"trade.SL")=="" && SBRangeLineCaption(SB_TRIANGLE,"trade.TP")=="","trade protections and other strategies cannot receive range labels");
   int total=ObjectsTotal(0);SBHLine(SB_4H,"2026.11.02.rangeHigh",3919.14,clrOrange);
   Check(ObjectsTotal(0)==total,"refresh creates no duplicates");
   Check(OrdersTotal()==0 && PositionsTotal()==0,"label fixture never places trades");
   ObjectsDeleteAll(0,sb_object_prefix);
   PrintFormat("RANGE_LABEL_TEST_RESULT | checks=%d failures=%d",label_checks,label_failures);
   return label_failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
double OnTester(){PrintFormat("RANGE_LABEL_TEST_RESULT | checks=%d failures=%d",label_checks,label_failures);return label_failures==0?label_checks:-1;}
