#ifndef SB_SHAPE_DRAWING
#define SB_SHAPE_DRAWING
string SBShapeDrawingPrefix(string id){return sb_object_prefix+"TRIANGLE.SH."+id+".";}
void SBShapeEraseDrawing(string id)
  {
   if(id=="")return;
   ObjectsDeleteAll(0,SBShapeDrawingPrefix(id));
   // Candidate annotations are separate from executed trade entry/SL/TP objects.
   string prefix=sb_object_prefix+SBName(SB_TRIANGLE)+"."+id;
   ObjectDelete(0,prefix+".sweep");ObjectDelete(0,prefix+".CHoCH");ObjectDelete(0,prefix+".BOS");
  }
void SBShapeDrawBoundary(string name,datetime start,double first,datetime finish,double last,color col)
  {
   if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_TREND,0,start,first,finish,last);
   ObjectMove(0,name,0,start,first);ObjectMove(0,name,1,finish,last);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }
void SBShapeDrawCandidate(SBShapeCandidate &c,datetime decision)
  {
   if(!InpDrawObjects || !InpShapeDraw || SBShapeTerminal(c.phase))
     {SBShapeEraseDrawing(c.pattern.id);return;}
   SBShapePattern p=c.pattern;datetime finish=(datetime)MathMax((long)decision,(long)c.available);
   // Hide unusable geometry without changing candidate state or entry decisions.
   double upper=SBShapeUpper(p,finish),lower=SBShapeLower(p,finish);
   if(finish<p.known || upper<=lower || finish-p.known>InpTriangleMaxPatternAgeBars*PeriodSeconds(InpShapeFormationTF))
     {SBShapeEraseDrawing(p.id);return;}
   string prefix=SBShapeDrawingPrefix(p.id);
   SBShapeDrawBoundary(prefix+"upper",p.u1,p.up1,finish,upper,clrTomato);
   SBShapeDrawBoundary(prefix+"lower",p.l1,p.lo1,finish,lower,clrDodgerBlue);
   string label=prefix+"status";
   if(ObjectFind(0,label)<0)ObjectCreate(0,label,OBJ_TEXT,0,finish,upper);
   ObjectMove(0,label,0,finish,upper);
   ObjectSetString(0,label,OBJPROP_TEXT,SBShapeSubtype(p.type)+" | "+SBShapePhaseName(c.phase));
   ObjectSetInteger(0,label,OBJPROP_COLOR,clrSilver);ObjectSetInteger(0,label,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
  }
#endif
