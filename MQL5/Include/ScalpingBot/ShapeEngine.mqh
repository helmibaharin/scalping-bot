#ifndef SB_SHAPE_ENGINE
#define SB_SHAPE_ENGINE
#include "ShapeDetector.mqh"
struct SBShapeLevel {double price;int side;datetime known,time;string source;};
SBShapeLevel sb_shape_levels[];
SBShapeLevel sb_shape_formation_levels[],sb_shape_context_levels[];
SBShapeCandidate sb_shapes[];
SBORBStructure sb_shape_structure;
datetime sb_shape_last=0,sb_shape_formation=0,sb_shape_context=0;
int sb_shape_context_trend=0;
void SBShapeTransition(SBShapeCandidate &c,int phase,datetime time,string reason)
  {
   if(c.phase==phase && c.reason==reason)return;c.phase=phase;c.last=time;c.reason=reason;
   SBEvent(SB_TRIANGLE,"SHAPE_STATE",StringFormat("pattern=%s id=%s phase=%s at=%I64d reason=%s liquidity=%s CHoCH=%I64d BOS=%I64d",
    SBShapeSubtype(c.pattern.type),c.pattern.id,SBShapePhaseName(phase),(long)time,reason,SBLiquidityName(c.classification),(long)c.choch,(long)c.bos));
  }
bool SBShapeTerminal(int phase){return phase==SH_EXECUTED || phase==SH_INVALIDATED || phase==SH_EXPIRED || phase==SH_BLOCKED;}
bool SBShapeAdd(SBShapePattern &p)
  {
   for(int i=0;i<ArraySize(sb_shapes);i++)
     {
      SBShapePattern q=sb_shapes[i].pattern;if(q.id==p.id)return false;
      datetime a=MathMax(p.first,q.first),z=MathMin(p.formed,q.formed);
      double span=(double)MathMin(p.formed-p.first,q.formed-q.first),tolerance=MathMax(p.atr,q.atr)*InpShapeToleranceATR;
      if(SBShapeFamily(p.type)==SBShapeFamily(q.type) && p.direction==q.direction && z>a && span>0 && (z-a)/span>=0.8 &&
         MathAbs(SBShapeUpper(p,z)-SBShapeUpper(q,z))<=tolerance && MathAbs(SBShapeLower(p,z)-SBShapeLower(q,z))<=tolerance)return false;
     }
   if(SBConsumed(SB_TRIANGLE,p.id))return false;
   int slot=-1;
   for(int i=0;i<ArraySize(sb_shapes);i++)if(SBShapeTerminal(sb_shapes[i].phase)){slot=i;break;}
   if(slot<0){slot=ArraySize(sb_shapes);if(slot>=InpShapeMaxCandidates)return false;ArrayResize(sb_shapes,slot+1);}
   ZeroMemory(sb_shapes[slot]);sb_shapes[slot].pattern=p;
   SBEvent(SB_TRIANGLE,"PATTERN_DETECTED",p.id+" "+SBShapeSubtype(p.type)+" pivots="+p.pivots);
   SBShapeTransition(sb_shapes[slot],SH_WAIT_BREAKOUT,p.known,"CONFIRMED_PIVOTS");
   if(InpShapeDraw)
     {SBTrend("SH."+p.id+".upper",p.u1,p.up1,p.u2,p.up2,clrTomato);SBTrend("SH."+p.id+".lower",p.l1,p.lo1,p.l2,p.lo2,clrDodgerBlue);}
   return true;
  }
void SBShapeLevelAdd(double price,int side,datetime known,datetime time,string source)
  {
   if(price<=0)return;int n=ArraySize(sb_shape_levels);if(n>=1200)return;
   ArrayResize(sb_shape_levels,n+1);sb_shape_levels[n].price=price;sb_shape_levels[n].side=side;sb_shape_levels[n].known=known;sb_shape_levels[n].time=time;sb_shape_levels[n].source=source;
  }
bool SBShapeNearestTarget(int direction,double entry,datetime decision,double &tp,string &source)
  {
   double nearest=DBL_MAX;tp=0;source="";
   for(int i=0;i<ArraySize(sb_shape_levels);i++)
     {
      SBShapeLevel l=sb_shape_levels[i];if(l.known>decision || l.side!=direction)continue;
      double d=direction*(l.price-entry);if(d<=0 || d>=nearest)continue;
      nearest=d;tp=l.price-direction*InpShapeTPBufferPoints*_Point;source=l.source;
     }
   return tp>0 && direction*(tp-entry)>0;
  }
bool SBShapeDynamic(SBSignal &s){return s.strategy==SB_TRIANGLE && StringLen(s.method)>0 && (SBSetupBasedExits(s.strategy,s.method) || s.method=="TRAP_REVERSAL" || s.pattern_type>3);}
bool SBShapePlanGeometry(SBSignal &s,double entry,double sl,double &tp,string &why)
  {
   double distance=s.direction*(entry-sl);if(distance<=0){why="SHAPE_INVALID_STOP";return false;}
   if(s.method=="TRAP_REVERSAL")
     {string source;if(!SBShapeNearestTarget(s.direction,entry,TimeCurrent(),tp,source)){why="SHAPE_NO_OPPOSING_TARGET";return false;}}
   else tp=s.target;
   tp=SBRoundPrice(tp,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),-s.direction);
   double rr=s.direction*(tp-entry)/distance;
   double minimum=SBShapeMinimumRR(s.method,SBSetupBasedExits(s.strategy,s.method));
   if(tp<=0 || rr<=0 || rr<minimum){why="SHAPE_NEAREST_TARGET_RR_REJECT";return false;}
   return true;
  }
// Pure transition engine: the structural event uses only pivots known BEFORE b.open.
void SBShapeStep(SBShapeCandidate &c,MqlRates &b,MqlRates &previous,SBORBBreak &event,int trend,int seconds)
  {
   if(SBShapeTerminal(c.phase) || b.time<c.pattern.known)return;
   if(b.time-c.pattern.known>InpTriangleMaxPatternAgeBars*PeriodSeconds(InpShapeFormationTF))
     {SBShapeTransition(c,SH_EXPIRED,b.time,"PATTERN_MAX_AGE");return;}
   double upper=SBShapeUpper(c.pattern,b.time),lower=SBShapeLower(c.pattern,b.time),clearance=InpTriangleBreakoutClearancePoints*_Point;
   if(upper<=lower){SBShapeTransition(c,SH_INVALIDATED,b.time,"BOUNDARIES_CROSSED");return;}
   if(c.trap>0)
     {
      if(b.time<=c.trap)return;
      if((c.direction>0 && b.low<c.extreme) || (c.direction<0 && b.high>c.extreme))
        {SBShapeTransition(c,SH_INVALIDATED,b.time,"SWEEP_EXTREME_BREACHED");return;}
      if(b.time-c.trap>InpShapeConfirmationBars*seconds){SBShapeTransition(c,SH_EXPIRED,b.time,"REVERSAL_TIMEOUT");return;}
      if((c.direction<0 && b.close>c.anchor+clearance) || (c.direction>0 && b.close<c.anchor-clearance))
        {SBShapeTransition(c,SH_INVALIDATED,b.time,"BREAKOUT_REESTABLISHED");return;}
      if(c.choch>0 && c.direction*(b.close-c.choch_level)<-clearance)
        {SBShapeTransition(c,SH_INVALIDATED,b.time,"CHOCH_FAILED");return;}
      if(event.direction!=c.direction || event.known>b.time || event.pivot<=0)return;
      if(c.opposing && c.choch==0)
        {c.choch=b.time;c.choch_pivot=event.pivot;c.choch_level=event.price;SBShapeTransition(c,SH_WAIT_BOS,b.time,"CHOCH_CONFIRMED_WAIT_DISTINCT_BOS");return;}
      if(c.choch>0 && (b.time<=c.choch || event.pivot==c.choch_pivot || event.pivot<=c.choch || event.known<=c.choch))return;
      c.bos=b.time;c.bos_level=event.price;SBShapeTransition(c,SH_REVERSAL_READY,b.time,"POST_TRAP_BOS_CONFIRMED");return;
     }
   c.classification=SBLiquidityStep(c.sweep,b,upper,lower,c.pattern.known,seconds,InpShapeFailureBars,InpShapeSweepPoints*_Point);
   if(c.classification==INSUFFICIENT_DATA)
     {SBShapeTransition(c,SH_INVALIDATED,b.time,"AMBIGUOUS_OR_MISSING_LIQUIDITY_DATA");return;}
   if(c.classification==SWEEP_REENTRY_CONFIRMED || c.classification==BREAKOUT_FAILED)
     {
      c.continuation_cancelled=true;
      if(!InpShapeReversal || c.trap_seen){SBShapeTransition(c,SH_INVALIDATED,b.time,"CONTINUATION_FAILED_REVERSAL_DISABLED_OR_CONSUMED");return;}
      c.trap_seen=true;c.trap=b.time;c.direction=-c.sweep.side;c.extreme=c.sweep.extreme;c.anchor=c.sweep.level;
      c.opposing=trend==-c.direction;c.protective=c.extreme-c.direction*InpTriangleStopBufferPoints*_Point;
      SBShapeTransition(c,c.opposing?SH_WAIT_CHOCH:SH_WAIT_BOS,b.time,c.opposing?"TRAP_CONFIRMED_CHOCH_REQUIRED":"TRAP_CONFIRMED_CHOCH_NOT_APPLICABLE");return;
     }
   if(!InpShapeContinuation || c.continuation_cancelled)return;
   if(c.phase==SH_WAIT_BREAKOUT)
     {
      int dir=SBTriangleBreak(previous.close,SBShapeUpper(c.pattern,previous.time),SBShapeLower(c.pattern,previous.time),b.close,upper,lower,clearance);
      if(dir==0 || (c.pattern.direction!=0 && dir!=c.pattern.direction) || MathAbs(b.close-b.open)<c.pattern.atr*InpShapeBreakBodyATR || dir*(b.close-b.open)<=0)return;
      c.direction=dir;c.breakout=b.time;c.anchor=dir>0?upper:lower;
      SBShapeTransition(c,SH_WAIT_RETEST,b.time,"BREAKOUT_CONFIRMED_CLOSE_AND_DISPLACEMENT");return;
     }
   if(b.time-c.breakout>InpTriangleMaxRetestBars*seconds){SBShapeTransition(c,SH_EXPIRED,b.time,"RETEST_TIMEOUT");return;}
   double line=c.direction>0?upper:lower;
   if(c.direction*(b.close-line)<0){SBShapeTransition(c,SH_INVALIDATED,b.time,"CONTINUATION_FAILED_OUTSIDE_SWEEP_WINDOW");return;}
   if(c.retest==0)
     {
      if(b.time<=c.breakout || !SBRetestTouch(c.direction,b.high,b.low,b.close,line,InpTriangleRetestTolerancePoints*_Point))return;
      c.retest=b.time;c.protective=c.direction>0?b.low:b.high;return;
     }
   if(b.time<=c.retest)return;
   if((c.direction>0 && b.low<=c.protective) || (c.direction<0 && b.high>=c.protective))
     {c.retest=b.time;c.protective=c.direction>0?MathMin(c.protective,b.low):MathMax(c.protective,b.high);return;}
   if(SBContinuation(c.direction,b.open,b.close,line,InpTriangleRequireDirectionalBody,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)))
     {c.protective-=c.direction*InpTriangleStopBufferPoints*_Point;SBShapeTransition(c,SH_CONTINUATION_READY,b.time,"RETEST_SWING_AND_LATER_CONTINUATION");}
  }
#endif
