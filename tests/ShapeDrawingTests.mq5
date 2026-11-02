#property strict
#include "../MQL5/Include/ScalpingBot/Config.mqh"
bool drawing_enabled=true,shape_drawing_enabled=true;
#define InpDrawObjects drawing_enabled
#define InpShapeDraw shape_drawing_enabled
#define OnInit SBDrawingProductionInit
#define OnTick SBDrawingProductionTick
#define OnTimer SBDrawingProductionTimer
#define OnDeinit SBDrawingProductionDeinit
#define OnTradeTransaction SBDrawingProductionTransaction
#define OnTester SBDrawingProductionTester
#include "../MQL5/Experts/ScalpingBot.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit
#undef OnTradeTransaction
#undef OnTester
int drawing_checks=0,drawing_failures=0;
void Check(bool ok,string reason){drawing_checks++;if(!ok)drawing_failures++;Print(ok?"SHAPE_DRAWING_PASS | ":"SHAPE_DRAWING_FAIL | ",reason);}
void Fixture(SBShapeCandidate &c)
  {
   ZeroMemory(c);c.phase=SH_WAIT_BREAKOUT;c.pattern.id="drawing-candidate";c.pattern.type=SH_ASCENDING;
   c.pattern.first=TimeCurrent()-7200;c.pattern.formed=TimeCurrent()-3600;c.pattern.known=TimeCurrent()-900;c.available=c.pattern.known;
   c.pattern.u1=c.pattern.first;c.pattern.u2=c.pattern.formed;c.pattern.up1=110;c.pattern.up2=110;
   c.pattern.l1=c.pattern.first;c.pattern.l2=c.pattern.formed;c.pattern.lo1=90;c.pattern.lo2=95;c.pattern.atr=2;
  }
void Suite()
  {
   sb_instance="SB.TEST.SHAPE.DRAWING.";sb_object_prefix=sb_instance;sb_account=sb_instance+"R.";
   GlobalVariablesDeleteAll(sb_instance);ObjectsDeleteAll(0,sb_object_prefix);
   SBShapeCandidate c;Fixture(c);datetime decision=TimeCurrent();string prefix=SBShapeDrawingPrefix(c.pattern.id);
   SBShapeDrawCandidate(c,decision);
   Check(ObjectFind(0,prefix+"upper")>=0 && ObjectFind(0,prefix+"lower")>=0 && ObjectFind(0,prefix+"status")>=0,"active pattern draws two finite boundaries and status");
   Check(ObjectGetInteger(0,prefix+"upper",OBJPROP_RAY_RIGHT)==0 && ObjectGetInteger(0,prefix+"lower",OBJPROP_RAY_RIGHT)==0,"active pattern has no infinite right rays");
   Check(ObjectGetInteger(0,prefix+"upper",OBJPROP_RAY_LEFT)==0,"active pattern has no infinite left ray");
   Check(ObjectGetInteger(0,prefix+"upper",OBJPROP_TIME,1)==decision,"boundary ends at evaluated decision, not future chart space");
   Check(StringFind(ObjectGetString(0,prefix+"status",OBJPROP_TEXT),"ASCENDING_TRIANGLE | WAIT_BREAKOUT")>=0,"label distinguishes candidate type and actual phase");
   Check(c.phase==SH_WAIT_BREAKOUT && c.last==0,"drawing cannot change candidate state");
   int total=ObjectsTotal(0);SBShapeDrawCandidate(c,decision+300);
   Check(ObjectsTotal(0)==total && ObjectGetInteger(0,prefix+"upper",OBJPROP_TIME,1)==decision+300,"refresh updates existing objects without duplicates");
   string trade=sb_object_prefix+SBName(SB_TRIANGLE)+"."+c.pattern.id;
   SBHLine(SB_TRIANGLE,c.pattern.id+".SL",85,clrRed);SBHLine(SB_TRIANGLE,c.pattern.id+".TP",120,clrLimeGreen);
   SBMarker(SB_TRIANGLE,c.pattern.id+".entry",decision,100,clrWhite);
   SBHLine(SB_4H,"unrelated",105,clrOrange);
   int phases[]={SH_INVALIDATED,SH_EXPIRED,SH_BLOCKED,SH_EXECUTED};
   for(int i=0;i<ArraySize(phases);i++)
     {
      Fixture(c);SBShapeDrawCandidate(c,decision);
      SBHLine(SB_TRIANGLE,c.pattern.id+".sweep",90,clrOrange);SBHLine(SB_TRIANGLE,c.pattern.id+".CHoCH",100,clrAqua);SBHLine(SB_TRIANGLE,c.pattern.id+".BOS",105,clrLimeGreen);
      SBShapeTransition(c,phases[i],decision,"drawing-fixture");
      Check(ObjectFind(0,prefix+"upper")<0 && ObjectFind(0,prefix+"lower")<0 && ObjectFind(0,prefix+"status")<0,"terminal phase removes pattern geometry: "+SBShapePhaseName(phases[i]));
      Check(ObjectFind(0,trade+".sweep")<0 && ObjectFind(0,trade+".CHoCH")<0 && ObjectFind(0,trade+".BOS")<0,"terminal phase removes candidate-only annotations");
      SBShapeDrawCandidate(c,decision);
      Check(ObjectFind(0,prefix+"upper")<0 && ObjectFind(0,trade+".SL")>=0 && ObjectFind(0,trade+".TP")>=0 && ObjectFind(0,trade+".entry")>=0,"terminal refresh stays clean and retains trade records");
     }
   Check(ObjectFind(0,sb_object_prefix+SBName(SB_4H)+".unrelated")>=0,"cleanup cannot delete another strategy's objects");
   Fixture(c);c.pattern.lo1=120;c.pattern.lo2=120;SBShapeDrawCandidate(c,decision);
   Check(ObjectFind(0,prefix+"upper")<0 && c.phase==SH_WAIT_BREAKOUT,"already crossed geometry is hidden without altering decisions");
   Fixture(c);c.pattern.known=decision-(InpTriangleMaxPatternAgeBars+1)*PeriodSeconds(InpShapeFormationTF);SBShapeDrawCandidate(c,decision);
   Check(ObjectFind(0,prefix+"upper")<0 && c.phase==SH_WAIT_BREAKOUT,"aged geometry is hidden without altering candidate state");
   Fixture(c);SBShapeDrawCandidate(c,decision);shape_drawing_enabled=false;SBShapeDrawCandidate(c,decision);
   Check(ObjectFind(0,prefix+"upper")<0,"shape drawing switch removes owned geometry");shape_drawing_enabled=true;
   SBShapeDrawCandidate(c,decision);drawing_enabled=false;SBShapeDrawCandidate(c,decision);
   Check(ObjectFind(0,prefix+"upper")<0,"global drawing switch removes owned geometry");drawing_enabled=true;
   Check(OrdersTotal()==0 && PositionsTotal()==0,"chart fixture never submits trades");
   ObjectsDeleteAll(0,sb_object_prefix);GlobalVariablesDeleteAll(sb_instance);
  }
int OnInit(){if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;Suite();PrintFormat("SHAPE_DRAWING_TEST_RESULT | checks=%d failures=%d",drawing_checks,drawing_failures);return drawing_failures==0?INIT_SUCCEEDED:INIT_FAILED;}
void OnTick(){}
double OnTester(){PrintFormat("SHAPE_DRAWING_TEST_RESULT | checks=%d failures=%d",drawing_checks,drawing_failures);return drawing_failures==0?drawing_checks:-1;}
