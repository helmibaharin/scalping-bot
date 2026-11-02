#ifndef SB_LIQUIDITY_SWEEP
#define SB_LIQUIDITY_SWEEP
// Pure completed-bar classifier. References must be confirmed before bar OPEN.
enum SBLiquidityClass { NO_TRAP_DETECTED=0,POSSIBLE_SWEEP,SWEEP_REENTRY_CONFIRMED,BREAKOUT_HOLDING,BREAKOUT_FAILED,INSUFFICIENT_DATA };
struct SBSweep {int side;datetime started;double extreme,level;bool active;};
string SBLiquidityName(int c)
  {switch(c){case POSSIBLE_SWEEP:return "POSSIBLE_SWEEP";case SWEEP_REENTRY_CONFIRMED:return "SWEEP_REENTRY_CONFIRMED";case BREAKOUT_HOLDING:return "BREAKOUT_HOLDING";case BREAKOUT_FAILED:return "BREAKOUT_FAILED";case INSUFFICIENT_DATA:return "INSUFFICIENT_DATA";}return "NO_TRAP_DETECTED";}
int SBLiquidityStep(SBSweep &s,MqlRates &b,double upper,double lower,datetime known,int seconds,int window,double penetration)
  {
   if(known>b.time || upper<=lower || lower<=0 || seconds<=0)return INSUFFICIENT_DATA;
   if(s.active)
     {
      if(b.time-s.started>window*seconds){s.active=false;return NO_TRAP_DETECTED;}
      s.extreme=s.side>0?MathMax(s.extreme,b.high):MathMin(s.extreme,b.low);
      if((s.side>0 && b.close<s.level) || (s.side<0 && b.close>s.level))
        {s.active=false;return BREAKOUT_FAILED;}
      return BREAKOUT_HOLDING;
     }
   bool up=b.high>upper+penetration,down=b.low<lower-penetration;
   if(up && down)return INSUFFICIENT_DATA; // Ambiguous two-sided excursion: no assumed intrabar path.
   if(!up && !down)return NO_TRAP_DETECTED;
   s.side=up?1:-1;s.level=up?upper:lower;s.extreme=up?b.high:b.low;s.started=b.time;
   if((up && b.close<upper) || (down && b.close>lower))return SWEEP_REENTRY_CONFIRMED;
   s.active=true;return (up?b.close>upper:b.close<lower)?BREAKOUT_HOLDING:POSSIBLE_SWEEP;
  }
#endif
