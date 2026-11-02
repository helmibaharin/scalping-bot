#ifndef SB_TRIANGLE_DETECTOR
#define SB_TRIANGLE_DETECTOR
bool SBTriangleEnabled(int type)
  { return (type==SB_ASCENDING && InpEnableAscendingTriangle) || (type==SB_DESCENDING && InpEnableDescendingTriangle) || (type==SB_SYMMETRICAL && InpEnableSymmetricalTriangle); }
double SBUpper(SBTriangle &p,datetime time){return SBLine((double)time,(double)p.h1,p.hp1,(double)p.h2,p.hp2);}
double SBLower(SBTriangle &p,datetime time){return SBLine((double)time,(double)p.l1,p.lp1,(double)p.l2,p.lp2);}
bool SBDetectTriangle(MqlRates &bars[],int end,SBTriangle &p)
  {
   int left=InpTrianglePivotLeft,right=InpTrianglePivotRight,period=PeriodSeconds(InpTriangleTimeframe);
   int start=MathMax(left,end-InpTriangleMaxDurationBars+1);
   int highs[],lows[];
   for(int i=start;i<=end-right;i++)
     {
      if(SBPivotHigh(bars,i,left,right,end))
        {int n=ArraySize(highs);if(n==0 || i-highs[n-1]>=InpTriangleMinSeparationBars){ArrayResize(highs,n+1);highs[n]=i;}}
      if(SBPivotLow(bars,i,left,right,end))
        {int n=ArraySize(lows);if(n==0 || i-lows[n-1]>=InpTriangleMinSeparationBars){ArrayResize(lows,n+1);lows[n]=i;}}
     }
   int nh=ArraySize(highs),nl=ArraySize(lows);if(nh<InpTriangleMinTouches || nl<InpTriangleMinTouches)return false;
   int h1=highs[nh-2],h2=highs[nh-1],l1=lows[nl-2],l2=lows[nl-1];
   // Most recent endpoints; all additional touches must fit these fixed lines.
   int first=MathMin(highs[nh-InpTriangleMinTouches],lows[nl-InpTriangleMinTouches]);
   int last=MathMax(h2,l2),duration=last-first;
   if(duration<InpTriangleMinDurationBars || duration>InpTriangleMaxDurationBars || end-last>InpTriangleMaxPatternAgeBars)return false;
   for(int i=first+1;i<=end;i++)if(bars[i].time-bars[i-1].time!=period)return false;
   p.h1=bars[h1].time;p.h2=bars[h2].time;p.l1=bars[l1].time;p.l2=bars[l2].time;
   p.hp1=bars[h1].high;p.hp2=bars[h2].high;p.lp1=bars[l1].low;p.lp2=bars[l2].low;
   if(p.h2<=p.h1 || p.l2<=p.l1)return false;
   double r=(p.hp2-p.hp1)/(double)(p.h2-p.h1),s=(p.lp2-p.lp1)/(double)(p.l2-p.l1);
   double tolerance=InpTriangleHorizontalTolerancePoints*_Point;
   double flat=tolerance/MathMax(period,(double)(bars[last].time-bars[first].time));
   p.type=SBClassifyTriangle(r,s,flat);if(!SBTriangleEnabled(p.type))return false;
   if(s<=r)return false;
   datetime t=bars[end].time;
   double upper=SBUpper(p,t),lower=SBLower(p,t),initial=SBUpper(p,bars[first].time)-SBLower(p,bars[first].time);
   p.apex=(double)t+(upper-lower)/(s-r);
   double apex_bars=(p.apex-(double)t)/period;
   if(!SBConverges(initial,upper-lower,InpTriangleMinHeightPoints*_Point,InpTriangleMinConvergence,apex_bars,InpTriangleMinApexBars,InpTriangleMaxApexBars))return false;
   for(int i=nh-InpTriangleMinTouches;i<nh;i++)if(MathAbs(bars[highs[i]].high-SBUpper(p,bars[highs[i]].time))>tolerance)return false;
   for(int i=nl-InpTriangleMinTouches;i<nl;i++)if(MathAbs(bars[lows[i]].low-SBLower(p,bars[lows[i]].time))>tolerance)return false;
   // All formation closes before the signal candle must lie inside fixed lines.
   for(int i=first;i<end;i++)if(bars[i].close>SBUpper(p,bars[i].time)+tolerance || bars[i].close<SBLower(p,bars[i].time)-tolerance)return false;
   p.formed=t;
   p.id=SBId(_Symbol+"|"+IntegerToString((int)InpTriangleTimeframe)+"|"+IntegerToString((long)p.h1)+"|"+IntegerToString((long)p.h2)+"|"+
             IntegerToString((long)p.l1)+"|"+IntegerToString((long)p.l2)+"|"+IntegerToString(p.type));
   return true;
  }
#endif
