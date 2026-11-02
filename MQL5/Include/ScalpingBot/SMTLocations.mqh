#ifndef SB_SMT_LOCATIONS
#define SB_SMT_LOCATIONS
#include "SMTTypes.mqh"
double SBSMTATR(MqlRates &bars[],int end,int period)
  {
   if(end<period)return 0;double sum=0;
   for(int i=end-period+1;i<=end;i++)sum+=MathMax(bars[i].high-bars[i].low,MathMax(MathAbs(bars[i].high-bars[i-1].close),MathAbs(bars[i].low-bars[i-1].close)));
   return sum/period;
  }
bool SBSMTContiguous(MqlRates &bars[],int first,int last,int seconds)
  {
   if(first<0 || last>=ArraySize(bars) || first>last)return false;
   for(int i=first;i<=last;i++)if(!SBORBValidOHLC(bars[i]) || (i>first && bars[i].time-bars[i-1].time!=seconds))return false;
   return true;
  }
int SBSMTClassify(SBORBStructure &s,int highs,int lows)
  {if(highs<InpSMTMinConfirmedPivots || lows<InpSMTMinConfirmedPivots)return SMT_INSUFFICIENT;return SBORBTrend(s);}
bool SBSMTGapAllowed(datetime previous,datetime next,int seconds)
  {
   if(next-previous==seconds)return true;
   if(next<=previous || next-previous>14*86400)return false;
   for(datetime stamp=previous+seconds;stamp<next;stamp+=seconds)if(SBSession(stamp+seconds/2))return false;
   return true;
  }
int SBSMTTrend(MqlRates &bars[],datetime decision,int seconds)
  {
   SBORBStructure s={};SBORBBreak event={};int highs=0,lows=0;
   for(int i=0;i<ArraySize(bars);i++)
     {
      if(bars[i].time+seconds>decision)break;
      if(i>0 && !SBSMTGapAllowed(bars[i-1].time,bars[i].time,seconds)){ZeroMemory(s);highs=0;lows=0;}
      datetime high=s.high.time,low=s.low.time;
      SBORBStructureStep(s,bars,i,InpSMTPivotLeft,InpSMTPivotRight,seconds,InpSMTBOSClearancePoints*_Point,event);
      if(s.high.time!=high)highs++;if(s.low.time!=low)lows++;
     }
   return SBSMTClassify(s,highs,lows);
  }
bool SBSMTTrendAllows(int direction,int trend,int mode,bool allow_neutral)
  {return mode!=0 || trend==direction || (allow_neutral && trend==SMT_NEUTRAL);}
bool SBSMTStrongDeparture(MqlRates &bars[],int origin,int end,int direction,double atr)
  {
   if(atr<=0 || origin<0 || end-origin!=InpSMTDepartureBars || direction*(bars[origin].close-bars[origin].open)>=0)return false;
   if(direction*(bars[end].close-(direction>0?bars[origin].high:bars[origin].low))<InpSMTDepartureDistanceATR*atr)return false;
   for(int i=origin+1;i<=end;i++)
     {
      double range=bars[i].high-bars[i].low,body=direction*(bars[i].close-bars[i].open);
      if(range<=0 || body<InpSMTMomentumBodyATR*atr)return false;
      double close_tail=direction>0?bars[i].high-bars[i].close:bars[i].close-bars[i].low;
      double opposing_wick=direction>0?bars[i].open-bars[i].low:bars[i].high-bars[i].open;
      if(close_tail/range>InpSMTDepartureCloseFraction || opposing_wick/range>InpSMTMaxOpposingWickFraction)return false;
     }
   return true;
  }
void SBSMTLocationUpdate(SBSMTLocation &location,MqlRates &b,int seconds)
  {
   if(!location.valid || b.time<location.known)return;
   if(b.time+seconds-location.known>InpSMTZoneMaxAgeBars*seconds)
     {location.valid=false;location.reason="SMT_ZONE_EXPIRED";return;}
   bool touch=b.high>=location.lower && b.low<=location.upper;
   if(touch && location.first_touch==0){location.first_touch=b.time;location.fresh=false;}
   bool zone=location.type==SMT_SUPPLY || location.type==SMT_DEMAND;
   if(zone && (location.direction>0?b.close<location.lower:b.close>location.upper))
     {location.valid=false;location.reason="SMT_ZONE_INVALIDATED";return;}
   if(!zone)
     {
      bool outside=b.close>location.upper+InpSMTBOSClearancePoints*_Point || b.close<location.lower-InpSMTBOSClearancePoints*_Point;
      // Liquidity references only count closes through their swept side.
      if(location.type==SMT_BSL)outside=b.close>location.upper+InpSMTBOSClearancePoints*_Point;
      if(location.type==SMT_SSL)outside=b.close<location.lower-InpSMTBOSClearancePoints*_Point;
      location.acceptance=outside?location.acceptance+1:0;
      if(location.acceptance>=InpSMTAcceptanceCloses){location.valid=false;location.reason="SMT_LOCATION_ACCEPTED_BREAK";}
     }
  }
void SBSMTAddLocation(SBSMTLocation &locations[],int type,int tf,int direction,double upper,double lower,datetime formed,datetime known)
  {
   if(upper<lower || lower<=0)return;
   SBSMTLocation location={};location.type=type;location.tf=tf;location.direction=direction;location.upper=upper;location.lower=lower;
   location.formed=formed;location.known=known;location.valid=true;location.fresh=true;
   location.momentum=type==SMT_SUPPLY || type==SMT_DEMAND;location.bos=location.momentum;location.reason="SMT_LOCATION_VALID";
   location.id=SBId(IntegerToString(tf)+"|"+IntegerToString(type)+"|"+IntegerToString((long)formed));
   int n=ArraySize(locations);
   for(int i=0;i<n;i++)if(locations[i].id==location.id)return;
   ArrayResize(locations,n+1);locations[n]=location;
  }
bool SBSMTConsolidation(MqlRates &bars[],int end,int seconds,double atr,int &direction,double &upper,double &lower)
  {
   int first=end-InpSMTConsolidationBars+1,prior=first-1-InpSMTPriorMoveBars;
   if(atr<=0 || prior<0 || !SBSMTContiguous(bars,prior,end,seconds))return false;
   upper=-DBL_MAX;lower=DBL_MAX;
   for(int i=first;i<=end;i++){upper=MathMax(upper,bars[i].high);lower=MathMin(lower,bars[i].low);}
   if(upper<=lower || upper-lower>InpSMTConsolidationMaxWidthATR*atr || MathAbs(bars[end].close-bars[first].open)>(upper-lower)*0.5)return false;
   double move=bars[first-1].close-bars[prior].close;
   if(MathAbs(move)<InpSMTPriorMoveATR*atr)return false;
   direction=move<0?1:-1;int highs=0,lows=0;
   double tolerance=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),InpSMTEqualLevelTolerancePoints*_Point);
   for(int i=first;i<=end;i++){if(upper-bars[i].high<=tolerance)highs++;if(bars[i].low-lower<=tolerance)lows++;}
   return highs>=InpSMTConsolidationTouches && lows>=InpSMTConsolidationTouches;
  }
void SBSMTBuildLocations(MqlRates &bars[],int tf,datetime decision,SBSMTLocation &locations[])
  {
   int seconds=PeriodSeconds((ENUM_TIMEFRAMES)tf);SBORBStructure s={};SBORBBreak event={};
   for(int i=0;i<ArraySize(bars);i++)
     {
      MqlRates b=bars[i];if(b.time+seconds>decision)break;
      if(i>0 && !SBSMTGapAllowed(bars[i-1].time,b.time,seconds))
        {
         ZeroMemory(s);
         for(int j=0;j<ArraySize(locations);j++)if(locations[j].tf==tf){locations[j].valid=false;locations[j].reason="SMT_HISTORY_GAP";}
        }
      for(int j=0;j<ArraySize(locations);j++)if(locations[j].tf==tf)SBSMTLocationUpdate(locations[j],b,seconds);
      datetime old_high=s.high.time,old_low=s.low.time;
      SBORBStructureStep(s,bars,i,InpSMTPivotLeft,InpSMTPivotRight,seconds,InpSMTBOSClearancePoints*_Point,event);
      int at=i-InpSMTPivotRight;double atr=SBSMTATR(bars,i,InpSMTATRPeriod);
      if(atr<=0)continue;
      if(s.high.time!=old_high && InpSMTUseBSL && bars[at].high-bars[at].low>=InpSMTSignificantSwingATR*atr)
        {
         double low=s.high.price,high=s.high.price;
         if(s.previous_high.time>0 && MathAbs(s.high.price-s.previous_high.price)<=InpSMTEqualLevelTolerancePoints*_Point)
           {low=MathMin(s.high.price,s.previous_high.price);high=MathMax(s.high.price,s.previous_high.price);}
         SBSMTAddLocation(locations,SMT_BSL,tf,-1,high,low,s.high.time,s.high.known);
        }
      if(s.low.time!=old_low && InpSMTUseSSL && bars[at].high-bars[at].low>=InpSMTSignificantSwingATR*atr)
        {
         double low=s.low.price,high=s.low.price;
         if(s.previous_low.time>0 && MathAbs(s.low.price-s.previous_low.price)<=InpSMTEqualLevelTolerancePoints*_Point)
           {low=MathMin(s.low.price,s.previous_low.price);high=MathMax(s.low.price,s.previous_low.price);}
         SBSMTAddLocation(locations,SMT_SSL,tf,1,high,low,s.low.time,s.low.known);
        }
      int origin=i-InpSMTDepartureBars;
      if(event.direction!=0 && origin>InpSMTATRPeriod && event.known<=bars[origin+1].time &&
         SBSMTContiguous(bars,origin,i,seconds) && SBSMTStrongDeparture(bars,origin,i,event.direction,SBSMTATR(bars,origin,InpSMTATRPeriod)))
        {
         int type=event.direction>0?SMT_DEMAND:SMT_SUPPLY;
         if((type==SMT_DEMAND && InpSMTUseDemand) || (type==SMT_SUPPLY && InpSMTUseSupply))
           SBSMTAddLocation(locations,type,tf,event.direction,InpSMTZoneUseWicks?bars[origin].high:MathMax(bars[origin].open,bars[origin].close),
             InpSMTZoneUseWicks?bars[origin].low:MathMin(bars[origin].open,bars[origin].close),bars[origin].time,b.time+seconds);
        }
      int dir=0;double upper=0,lower=0;
      if(SBSMTConsolidation(bars,i,seconds,atr,dir,upper,lower) && ((dir>0 && InpSMTUseAccumulation) || (dir<0 && InpSMTUseDistribution)))
         SBSMTAddLocation(locations,dir>0?SMT_ACCUMULATION:SMT_DISTRIBUTION,tf,dir,upper,lower,bars[i-InpSMTConsolidationBars+1].time,b.time+seconds);
     }
  }
bool SBSMTSelectTarget(int direction,double entry,SBSMTLocation &locations[],datetime decision,double buffer,double tick,double &tp,string &id)
  {
   double closest=DBL_MAX;tp=0;id="";bool eligible=false;
   for(int i=0;i<ArraySize(locations);i++)
     {
      SBSMTLocation zone=locations[i];
      if(!zone.valid || !zone.momentum || !zone.bos || zone.known>decision ||
         zone.type!=(direction>0?SMT_SUPPLY:SMT_DEMAND))continue;
      if(direction>0?zone.upper<=entry:zone.lower>=entry)continue;
      double boundary=direction>0?zone.lower:zone.upper,distance=direction*(boundary-entry);
      if(distance<closest){closest=distance;id=zone.id;tp=SBRoundPrice(boundary-direction*buffer,tick,-direction);eligible=!InpSMTRequireFreshZones || zone.fresh;}
     }
   // Never skip an obstructing near/overlapping zone to manufacture a farther target.
   return eligible && id!="" && direction*(tp-entry)>=tick;
  }
bool SBSMTRRAllows(double entry,double sl,double tp,int direction,bool minimum_enabled,double minimum,double &rr)
  {
   double risk=direction*(entry-sl),reward=direction*(tp-entry);rr=risk>0?reward/risk:0;
   return risk>0 && reward>0 && (!minimum_enabled || rr>=minimum);
  }
bool SBSMTFilledRRValid(double entry,double sl,double tp,int direction,double net_reward,double risk,bool minimum_enabled,double minimum)
  {
   double rr=0;return risk>0 && net_reward>0 && SBSMTRRAllows(entry,sl,tp,direction,minimum_enabled,minimum,rr) &&
                      (!minimum_enabled || net_reward/risk>=minimum);
  }
#endif
