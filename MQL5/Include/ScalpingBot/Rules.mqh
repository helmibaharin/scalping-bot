#ifndef SB_RULES
#define SB_RULES
// Pure decision rules, also exercised by the deterministic test harness.
bool SBUpperBody(double open,double close,double high,double tick)
  { return MathMin(open,close)<=high+tick*0.1 && close>high+tick*0.1; }
bool SBLowerBody(double open,double close,double low,double tick)
  { return MathMax(open,close)>=low-tick*0.1 && close<low-tick*0.1; }
bool SBInside(double close,double low,double high,double tick)
  { return close>low+tick*0.1 && close<high-tick*0.1; }
double SBLine(double t,double t1,double p1,double t2,double p2)
  { return t2>t1?p1+(p2-p1)*(t-t1)/(t2-t1):p1; }
double SBTarget(int direction,double entry,double stop,double rr)
  { return entry+direction*MathAbs(entry-stop)*rr; }
double SBRoundPrice(double price,double tick,int outward)
  { return (outward>0?MathCeil(price/tick-1e-9):MathFloor(price/tick+1e-9))*tick; }
double SBVolumeFloor(double volume,double step)
  { return step>0?MathFloor(volume/step+1e-9)*step:0; }
bool SBAccountingAllows(bool hedging,bool symbol_occupied,int positions,int maximum)
  { return positions<maximum && (hedging || !symbol_occupied); }
int SBClassifyTriangle(double resistance_slope,double support_slope,double flat)
  {
   if(MathAbs(resistance_slope)<=flat && support_slope>flat) return 1;
   if(resistance_slope < -flat && MathAbs(support_slope)<=flat) return 2;
   if(resistance_slope < -flat && support_slope>flat) return 3;
   return 0;
  }
bool SBConverges(double initial_height,double current_height,double minimum_height,double convergence,double apex_bars,int min_apex,int max_apex)
  { return initial_height>=minimum_height && current_height>0 && current_height<=initial_height*(1-convergence) && apex_bars>=min_apex && apex_bars<=max_apex; }
// Return event: 0 wait, 1 upper breakout, 2 lower breakout, 3 return, 4 conflict.
int SB4HStep(int &side,double &extreme,double open,double high,double low,double close,double range_low,double range_high,double tick)
  {
   if(side==0)
     {
      if(SBUpperBody(open,close,range_high,tick)) { side=1; extreme=high; return 1; }
      if(SBLowerBody(open,close,range_low,tick)) { side=-1; extreme=low; return 2; }
      return 0;
     }
   extreme=side>0?MathMax(extreme,high):MathMin(extreme,low);
   if((side>0 && close<range_low-tick*0.1) || (side<0 && close>range_high+tick*0.1)) { side=0; return 4; }
   if(SBInside(close,range_low,range_high,tick)) return 3;
   return 0;
  }
// Triangle breakout must be a new close crossing, never a wick or chase.
int SBTriangleBreak(double previous,double previous_upper,double previous_lower,double close,double upper,double lower,double clearance)
  {
   if(previous<=previous_upper && close>upper+clearance) return 1;
   if(previous>=previous_lower && close<lower-clearance) return -1;
   return 0;
  }
bool SBTriangleFailed(int direction,double close,double line,double invalidation)
  { return direction>0?close<line-invalidation:close>line+invalidation; }
bool SBRetestTouch(int direction,double high,double low,double close,double line,double tolerance)
  { return direction>0?(low<=line+tolerance && high>=line-tolerance && close>=line-tolerance):
                       (high>=line-tolerance && low<=line+tolerance && close<=line+tolerance); }
bool SBContinuation(int direction,double open,double close,double line,bool require_body,double tick)
  { return direction>0?(close>line+tick*0.1 && (!require_body || close>open)):
                       (close<line-tick*0.1 && (!require_body || close<open)); }
#endif
