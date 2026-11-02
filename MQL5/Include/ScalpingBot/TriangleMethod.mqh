#ifndef SB_TRIANGLE_METHOD
#define SB_TRIANGLE_METHOD
SBTriangleState sb_triangle;
datetime sb_triangle_last=0;
void SBCancelTriangle(string reason,bool persist)
  {
   if(persist)SBConsume(SB_TRIANGLE,sb_triangle.pattern.id);
   SBEvent(SB_TRIANGLE,"SETUP_INVALIDATED",sb_triangle.pattern.id+" "+reason);
   ZeroMemory(sb_triangle);
  }
void SBTriangleBar(MqlRates &bars[],int end,bool actionable,bool replay)
  {
   MqlRates b=bars[end];int period=PeriodSeconds(InpTriangleTimeframe);
   if(sb_triangle.phase==0)
     {
      SBTriangle p={};if(!SBDetectTriangle(bars,end,p) || SBConsumed(SB_TRIANGLE,p.id))return;
      sb_triangle.pattern=p;sb_triangle.phase=1;
      SBEvent(SB_TRIANGLE,SBPatternName(p.type)+"_DETECTED",p.id);
      SBTrend(p.id+".resistance",p.h1,p.hp1,p.h2,p.hp2,clrTomato);
      SBTrend(p.id+".support",p.l1,p.lp1,p.l2,p.lp2,clrDodgerBlue);
      SBMarker(SB_TRIANGLE,p.id+".H1",p.h1,p.hp1,clrTomato);SBMarker(SB_TRIANGLE,p.id+".H2",p.h2,p.hp2,clrTomato);
      SBMarker(SB_TRIANGLE,p.id+".L1",p.l1,p.lp1,clrDodgerBlue);SBMarker(SB_TRIANGLE,p.id+".L2",p.l2,p.lp2,clrDodgerBlue);
     }
   SBTriangle p=sb_triangle.pattern;
   double upper=SBUpper(p,b.time),lower=SBLower(p,b.time),tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(upper<=lower || b.time>=p.apex || b.time-p.formed>InpTriangleMaxPatternAgeBars*period)
     {SBCancelTriangle("APEX_GEOMETRY_OR_AGE",!replay);return;}
   if(sb_triangle.phase==1)
     {
      if((p.apex-(double)b.time)/period<InpTriangleMinApexBars){SBCancelTriangle("TOO_CLOSE_TO_APEX",!replay);return;}
      if(end<1)return;
      int break_direction=SBTriangleBreak(bars[end-1].close,SBUpper(p,bars[end-1].time),SBLower(p,bars[end-1].time),b.close,upper,lower,InpTriangleBreakoutClearancePoints*_Point);
      if(break_direction==0)return;
      sb_triangle.direction=break_direction;sb_triangle.phase=2;sb_triangle.breakout=b.time;
      SBEvent(SB_TRIANGLE,"BREAKOUT_CONFIRMED",p.id+" dir="+IntegerToString(break_direction));
      SBMarker(SB_TRIANGLE,p.id+".break",b.time,b.close,clrOrange);return;
     }
   int dir=sb_triangle.direction;
   if((b.time-sb_triangle.breakout)/period>InpTriangleMaxRetestBars){SBCancelTriangle("RETEST_TIMEOUT",!replay);return;}
   double line=dir>0?upper:lower;
   if(SBTriangleFailed(dir,b.close,line,InpTriangleInvalidationPoints*_Point))
     {SBCancelTriangle("FAILED_RETEST_OR_CONFLICTING_BREAKOUT",!replay);return;}
   if(sb_triangle.phase==2)
     {
      if(b.time<=sb_triangle.breakout || !SBRetestTouch(dir,b.high,b.low,b.close,line,InpTriangleRetestTolerancePoints*_Point))return;
      sb_triangle.phase=3;sb_triangle.retest=b.time;sb_triangle.retest_low=b.low;sb_triangle.retest_high=b.high;
      SBEvent(SB_TRIANGLE,"RETEST_CONFIRMED",p.id);SBMarker(SB_TRIANGLE,p.id+".retest",b.time,line,clrAqua);return;
     }
   if(b.time<=sb_triangle.retest)return;
   // One completed right-hand candle must confirm the protective retest extreme.
   if((dir>0 && b.low<=sb_triangle.retest_low) || (dir<0 && b.high>=sb_triangle.retest_high))
     {sb_triangle.retest=b.time;sb_triangle.retest_low=MathMin(sb_triangle.retest_low,b.low);sb_triangle.retest_high=MathMax(sb_triangle.retest_high,b.high);return;}
   if(!SBContinuation(dir,b.open,b.close,line,InpTriangleRequireDirectionalBody,tick))return;
   SBSignal signal={};signal.strategy=SB_TRIANGLE;signal.pattern_type=p.type;signal.id=p.id;signal.direction=dir;signal.candle=b.time;
   signal.sl_method="RETEST_SWING";signal.rr=InpTriangleRewardRiskRatio;signal.max_stop_points=InpTriangleMaxStopPoints;
   signal.structural_sl=dir>0?sb_triangle.retest_low-InpTriangleStopBufferPoints*_Point:sb_triangle.retest_high+InpTriangleStopBufferPoints*_Point;
   SBEvent(SB_TRIANGLE,"CONTINUATION_CONFIRMED",p.id+(actionable?" fresh":" replay: no entry"));
   SBMarker(SB_TRIANGLE,p.id+".confirm",b.time,b.close,clrLimeGreen);
   if(actionable)SBExecute(signal);
   else SBConsume(SB_TRIANGLE,p.id); // Historical confirmation is retired, never chased after restart.
   ZeroMemory(sb_triangle);
  }
void SBEvaluateTriangle(bool startup)
  {
   if(!InpEnableTriangleMethod)return;
   datetime closed=iTime(_Symbol,InpTriangleTimeframe,1);if(closed<=0 || (!startup && closed<=sb_triangle_last))return;
   int count=InpTriangleMaxPatternAgeBars+InpTriangleMaxDurationBars+InpTriangleMaxRetestBars+InpTrianglePivotLeft+InpTrianglePivotRight+10;
   count=MathMin(count,InpMaxReplayBars);
   MqlRates bars[];int n=CopyRates(_Symbol,InpTriangleTimeframe,1,count,bars);if(n<InpTriangleMinDurationBars+5)return;
   int period=PeriodSeconds(InpTriangleTimeframe);
   for(int i=InpTrianglePivotLeft;i<n;i++)
     {
      if(bars[i].time<=sb_triangle_last)continue;
      if(i>0 && bars[i].time-bars[i-1].time!=period)
        {ZeroMemory(sb_triangle);sb_triangle_last=bars[i].time;continue;}
      // Each detector only sees indices <= i: pivots must have their right confirmation closed.
      SBTriangleBar(bars,i,!startup && i==n-1,startup);
      sb_triangle_last=bars[i].time;
     }
  }
#endif
