#ifndef SB_SMT_ENGINE
#define SB_SMT_ENGINE
#include "SMTLocations.mqh"
bool SBSMTInside(MqlRates &b,double upper,double lower,double tolerance)
  {return b.high<=upper+tolerance && b.low>=lower-tolerance;}
int SBSMTTrapDirection(MqlRates &b,double upper,double lower,double penetration)
  {
   if(b.close<=lower || b.close>=upper)return 0;
   bool upper_sweep=b.high>upper+penetration,lower_sweep=b.low<lower-penetration;
   if(upper_sweep==lower_sweep)return 0;
   return lower_sweep?1:-1;
  }
void SBSMTSetTrap(SBSMTTrap &trap,int pattern,int direction,int babies,MqlRates &mother,MqlRates &last,int seconds,double extreme,datetime breakout)
  {
   ZeroMemory(trap);trap.pattern=pattern;trap.direction=direction;trap.babies=babies;
   trap.upper=mother.high;trap.lower=mother.low;trap.mother=mother.time;trap.start=last.time;
   trap.known=last.time+seconds;trap.extreme=extreme;trap.breakout=breakout;
   trap.id=SBId(_Symbol+"|SMT|"+IntegerToString(InpSMTProfile)+"|"+IntegerToString((long)last.time)+"|"+IntegerToString(direction));
  }
bool SBSMTMotherTrap(MqlRates &bars[],int end,int seconds,int babies,int pattern,SBSMTTrap &trap)
  {
   int mother=end-babies-1;
   if(mother<0 || end-mother>InpSMTMaxPatternAgeBars || !SBSMTContiguous(bars,mother,end,seconds))return false;
   for(int i=mother+1;i<end;i++)if(!SBSMTInside(bars[i],bars[mother].high,bars[mother].low,InpSMTInsideTolerancePoints*_Point))return false;
   int direction=SBSMTTrapDirection(bars[end],bars[mother].high,bars[mother].low,InpSMTSweepPenetrationPoints*_Point);
   if(direction==0)return false;
   SBSMTSetTrap(trap,pattern,direction,babies,bars[mother],bars[end],seconds,direction>0?bars[end].low:bars[end].high,bars[end].time);return true;
  }
bool SBSMTRangeReentry(MqlRates &bars[],int end,int breakout,int seconds,double upper,double lower,double &extreme,int &direction)
  {
   if(breakout<1 || end<=breakout || end-breakout>InpSMTReentryMaxBars || !SBSMTContiguous(bars,breakout-1,end,seconds))return false;
   double clear=InpSMTSweepPenetrationPoints*_Point;
   int side=bars[breakout].close>upper+clear?1:(bars[breakout].close<lower-clear?-1:0);
   if(side==0 || bars[breakout-1].close>upper || bars[breakout-1].close<lower)return false;
   if(bars[end].close<=lower || bars[end].close>=upper || side*(bars[end].close-bars[end].open)>=0)return false;
   extreme=side>0?bars[breakout].high:bars[breakout].low;
   for(int i=breakout+1;i<=end;i++)
     {
      if(i<end && bars[i].close>lower && bars[i].close<upper)return false;
      extreme=side>0?MathMax(extreme,bars[i].high):MathMin(extreme,bars[i].low);
     }
   direction=-side;return true;
  }
bool SBSMTDetectTrap(MqlRates &bars[],int end,int seconds,SBSMTLocation &locations[],SBSMTTrap &trap)
  {
   if(InpSMTEnableClassic && SBSMTMotherTrap(bars,end,seconds,1,1,trap))return true;
   if(InpSMTEnableMultipleBaby)
      for(int babies=InpSMTMinBabyCandles;babies<=InpSMTMaxBabyCandles;babies++)
         if(SBSMTMotherTrap(bars,end,seconds,babies,2,trap))return true;
   if(!InpSMTEnableRangeTrap)return false;
   for(int breakout=end-1;breakout>=MathMax(1,end-InpSMTReentryMaxBars);breakout--)
     {
      for(int babies=1;babies<=InpSMTMaxBabyCandles;babies++)
        {
         int mother=breakout-babies-1;
         if(mother<0 || end-mother>InpSMTMaxPatternAgeBars || !SBSMTContiguous(bars,mother,end,seconds))continue;
         bool inside=true;for(int i=mother+1;i<breakout;i++)if(!SBSMTInside(bars[i],bars[mother].high,bars[mother].low,InpSMTInsideTolerancePoints*_Point))inside=false;
         double extreme;int dir;
         if(inside && SBSMTRangeReentry(bars,end,breakout,seconds,bars[mother].high,bars[mother].low,extreme,dir))
           {SBSMTSetTrap(trap,3,dir,babies,bars[mother],bars[end],seconds,extreme,bars[breakout].time);return true;}
        }
      for(int j=ArraySize(locations)-1;j>=0;j--)
        {
         SBSMTLocation location=locations[j];
         if(!location.valid || location.known>bars[breakout].time ||
            bars[end].time-location.known>InpSMTMaxPatternAgeBars*seconds ||
            (location.type!=SMT_ACCUMULATION && location.type!=SMT_DISTRIBUTION))continue;
         double extreme;int dir;
         if(SBSMTRangeReentry(bars,end,breakout,seconds,location.upper,location.lower,extreme,dir) && dir==location.direction)
           {
            MqlRates reference={};reference.time=location.formed;reference.high=location.upper;reference.low=location.lower;
            SBSMTSetTrap(trap,3,dir,0,reference,bars[end],seconds,extreme,bars[breakout].time);return true;
           }
        }
     }
   return false;
  }
bool SBSMTMatchLocation(SBSMTTrap &trap,SBSMTLocation &locations[],SBSMTLocation &chosen)
  {
   int rank=-1;datetime latest=0;
   for(int i=0;i<ArraySize(locations);i++)
     {
      SBSMTLocation location=locations[i];
      datetime reference=trap.pattern==3?trap.breakout:trap.start;
      if(!location.valid || location.known>reference || location.direction!=trap.direction)continue;
      bool zone=location.type==SMT_SUPPLY || location.type==SMT_DEMAND;
      if(zone && (!location.momentum || !location.bos || (InpSMTRequireFreshZones && !location.fresh &&
          (location.first_touch==0 || location.first_touch<reference))))continue;
      double tolerance=InpSMTLocationProximityPoints*_Point;
      if(zone)
        {
         bool intersects=trap.direction>0?(trap.extreme<=location.upper+tolerance && trap.upper>=location.lower-tolerance):
                                        (trap.extreme>=location.lower-tolerance && trap.lower<=location.upper+tolerance);
         if(!intersects)continue;
        }
      if(!zone && (trap.extreme<location.lower-tolerance || trap.extreme>location.upper+tolerance))
        {
         if(trap.direction>0 && trap.extreme>=location.lower-InpSMTSweepPenetrationPoints*_Point)continue;
         if(trap.direction<0 && trap.extreme<=location.upper+InpSMTSweepPenetrationPoints*_Point)continue;
         if(trap.upper<location.lower-tolerance || trap.lower>location.upper+tolerance)continue;
        }
      if(!zone && (trap.direction>0?trap.extreme>=location.lower-InpSMTSweepPenetrationPoints*_Point:
                                   trap.extreme<=location.upper+InpSMTSweepPenetrationPoints*_Point))continue;
      int score=zone?3:((location.type==SMT_BSL || location.type==SMT_SSL)?2:1);
      if(score>rank || (score==rank && location.known>latest)){chosen=location;rank=score;latest=location.known;}
     }
   return rank>=0;
  }
bool SBSMTActive(SBSMTCandidate &c){return c.phase>=SMT_TRAP_CONFIRMED && c.phase<=SMT_READY;}
void SBSMTStart(SBSMTCandidate &c,SBSMTTrap &trap,SBSMTLocation &location,int trend,int context,int local_trend,double atr)
  {
   ZeroMemory(c);c.trap=trap;c.location=location;c.trend=trend;c.context=context;c.atr=atr;
   c.opposing=local_trend==-trap.direction && InpSMTRequireConditionalCHoCH;
   c.phase=SMT_TRAP_CONFIRMED;c.changed=trap.known;c.reason="SMT_TRAP_CONFIRMED";
  }
void SBSMTStep(SBSMTCandidate &c,SBORBBreak &event,MqlRates &bars[],int end,int seconds,int trend,int context,bool location_alive)
  {
   if(!SBSMTActive(c))return;MqlRates b=bars[end];int dir=c.trap.direction;
   if(b.time<c.trap.known)return;
   if(b.time+seconds-c.trap.known>InpSMTConfirmationBars*seconds){c.phase=SMT_EXPIRED;c.reason="SMT_CONFIRMATION_EXPIRED";return;}
   if((dir>0?b.low<c.trap.extreme:b.high>c.trap.extreme))
     {c.phase=SMT_INVALIDATED;c.reason="SMT_TRAP_INVALIDATED";return;}
   if(!location_alive){c.phase=SMT_INVALIDATED;c.reason="SMT_LOCATION_INVALIDATED";return;}
   c.trend=trend;c.context=context;
   if(!SBSMTTrendAllows(dir,trend,InpSMTTrendMode,InpSMTAllowNeutralTrend) || (InpSMTRequireContextAlignment && context!=dir))
     {c.phase=SMT_INVALIDATED;c.reason=(trend==SMT_NEUTRAL || trend==SMT_INSUFFICIENT)?"SMT_TREND_NEUTRAL":"SMT_TREND_MISMATCH";return;}
   if(c.atr<=0 || MathAbs(b.close-(dir>0?c.trap.lower:c.trap.upper))>InpSMTMaxEntryExtensionATR*c.atr)
     {c.phase=SMT_INVALIDATED;c.reason="SMT_ENTRY_TOO_EXTENDED";return;}
   if(InpSMTUseFVGValidation)
     {
      SBORBCandidate fvg={};fvg.fvg=c.fvg;fvg.direction=dir;fvg.breakout=c.trap.start;
      fvg.anchor=dir>0?c.trap.lower:c.trap.upper;fvg.phase=ORB_WAIT_BOS;
      SBORBUpdateFVG(fvg,bars,end,InpSMTFVGMinGapPoints*_Point,InpSMTFVGMaxDistanceATR*c.atr,InpSMTFVGMaxAgeBars,seconds);
      c.fvg=fvg.fvg;
      if(fvg.phase==ORB_INVALID || fvg.phase==ORB_EXPIRED){c.phase=SMT_INVALIDATED;c.reason="SMT_FVG_INVALIDATED";return;}
     }
   if(c.phase==SMT_TRAP_CONFIRMED){c.phase=c.opposing?SMT_WAIT_CHOCH:SMT_WAIT_BOS;c.reason=c.opposing?"SMT_CHOCH_PENDING":"SMT_BOS_PENDING";}
   if(InpSMTRequireConditionalCHoCH && !c.choch_done && event.prior_trend==-dir)
     {c.opposing=true;c.phase=SMT_WAIT_CHOCH;c.reason="SMT_CHOCH_PENDING";}
   if(c.phase==SMT_WAIT_CHOCH)
     {
      if(event.direction==dir && event.known<=b.time)
        {c.choch_done=true;c.choch=b.time+seconds;c.choch_pivot=event.pivot;c.phase=SMT_WAIT_BOS;c.reason="SMT_CHOCH_CONFIRMED";}
      return;
     }
   if(event.direction==dir && event.pivot>0 && event.known<=b.time &&
      (!c.choch_done || (b.time+seconds>c.choch && event.pivot!=c.choch_pivot && event.known>=c.choch)))
     {c.bos_done=true;c.bos=b.time+seconds;c.phase=SMT_READY;c.reason="SMT_BOS_CONFIRMED";}
  }
#endif
