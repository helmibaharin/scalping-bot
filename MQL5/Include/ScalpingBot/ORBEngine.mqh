#ifndef SB_ORB_ENGINE
#define SB_ORB_ENGINE
#include "ORBTypes.mqh"
// Pure chronological engine. Every call sees only bars[0..end].
bool SBORBPivotAt(MqlRates &bars[],int at,int end,int type,int left,int right,int seconds)
  {
   if(at<left || at+right>end)return false;
   for(int j=at-left;j<=at+right;j++)
     {
      if(j>at-left && bars[j].time-bars[j-1].time!=seconds)return false;
      if(j==at)continue;
      if(type>0 && bars[j].high>=bars[at].high)return false;
      if(type<0 && bars[j].low<=bars[at].low)return false;
     }
   return true;
  }
int SBORBTrend(SBORBStructure &s)
  {
   if(s.previous_high.time==0 || s.previous_low.time==0)return 0;
   if(s.high.price>s.previous_high.price && s.low.price>s.previous_low.price)return 1;
   if(s.high.price<s.previous_high.price && s.low.price<s.previous_low.price)return -1;
   return 0;
  }
void SBORBStructureStep(SBORBStructure &s,MqlRates &bars[],int end,int left,int right,int seconds,double clearance,SBORBBreak &event)
  {
   ZeroMemory(event);MqlRates b=bars[end];event.prior_trend=s.trend;
   // A swing confirmed at this close cannot also be broken at this close.
   if(s.high.time>0 && !s.high.broken && s.high.known<=b.time && b.close>s.high.price+clearance)
     {event.direction=1;event.pivot=s.high.time;event.known=s.high.known;event.price=s.high.price;s.high.broken=true;}
   if(s.low.time>0 && !s.low.broken && s.low.known<=b.time && b.close<s.low.price-clearance)
     {event.direction=-1;event.pivot=s.low.time;event.known=s.low.known;event.price=s.low.price;s.low.broken=true;}
   int at=end-right;
   if(SBORBPivotAt(bars,at,end,1,left,right,seconds))
     {s.previous_high=s.high;s.high.time=bars[at].time;s.high.known=b.time+seconds;s.high.price=bars[at].high;s.high.type=1;s.high.broken=false;}
   if(SBORBPivotAt(bars,at,end,-1,left,right,seconds))
     {s.previous_low=s.low;s.low.time=bars[at].time;s.low.known=b.time+seconds;s.low.price=bars[at].low;s.low.type=-1;s.low.broken=false;}
   s.trend=SBORBTrend(s);
  }
int SBORBBreakout(double previous,double close,double high,double low,double clearance)
  {
   if(previous<=high+clearance && close>high+clearance)return 1;
   if(previous>=low-clearance && close<low-clearance)return -1;
   return 0;
  }
bool SBORBInside(double close,double high,double low){return close<high && close>low;}
bool SBORBActive(SBORBCandidate &c){return c.phase>=ORB_WAIT_RETEST && c.phase<=ORB_READY;}
void SBORBStart(SBORBCandidate &c,int mode,int direction,datetime stamp,double anchor,double excursion,int trend)
  {
   ZeroMemory(c);c.mode=mode;c.direction=direction;c.breakout=stamp;c.sequence_start=stamp;c.anchor=anchor;c.excursion=excursion;
   c.phase=mode==1?ORB_WAIT_RETEST:ORB_WAIT_CHOCH;c.opposing=trend==-direction;
   c.reason=mode==1?"ORB_WAIT_RETEST":"ORB_WAIT_CHOCH";
  }
bool SBORBFVGInvalid(SBORBFVG &f,double close)
  {return f.present && (f.direction>0?close<f.bottom:close>f.top);}
void SBORBUpdateFVG(SBORBCandidate &c,MqlRates &bars[],int end,double min_gap,double max_distance,int max_age,int seconds)
  {
   if(c.fvg.present)
     {
      if(SBORBFVGInvalid(c.fvg,bars[end].close))c.fvg.invalid=true;
      // An associated invalidation cannot disappear by age expiry or replacement.
      if(c.fvg.invalid){c.phase=ORB_INVALID;c.reason="ORB_FVG_INVALID";}
      else if(bars[end].time+seconds-c.fvg.formed>max_age*seconds){c.phase=ORB_EXPIRED;c.reason="ORB_FVG_EXPIRED";}
      return;
     }
   if(end<2 || bars[end-1].time<c.breakout || bars[end].time-bars[end-2].time!=2*seconds ||
      bars[end].time-c.breakout>max_age*seconds)return;
   double bottom=c.direction>0?bars[end-2].high:bars[end].high;
   double top=c.direction>0?bars[end].low:bars[end-2].low;
   if(top-bottom<min_gap || top<=bottom || MathAbs((top+bottom)/2-c.anchor)>max_distance)return;
   c.fvg.present=true;c.fvg.direction=c.direction;c.fvg.bottom=bottom;c.fvg.top=top;c.fvg.formed=bars[end].time+seconds;
  }
void SBORBCandidateStep(SBORBCandidate &c,SBORBStructure &s,SBORBBreak &event,MqlRates &bars[],int end,
                        double tolerance,double invalidation,bool conditional_choch,bool require_bos,
                        int retest_timeout,int confirmation_timeout,int seconds)
  {
   if(!SBORBActive(c))return;MqlRates b=bars[end];int dir=c.direction;
   if(b.time<=c.breakout)return;
   if(b.time-c.breakout>confirmation_timeout*seconds || (c.phase==ORB_WAIT_RETEST && b.time-c.breakout>retest_timeout*seconds))
     {c.phase=ORB_EXPIRED;c.reason="ORB_SETUP_EXPIRED";return;}
   if(c.mode==1 && dir*(b.close-c.anchor)<-invalidation)
     {c.phase=ORB_INVALID;c.reason="ORB_RETEST_FAILED";return;}
   if(c.protective>0 && dir*(b.close-c.protective)<0)
     {c.phase=ORB_INVALID;c.reason="ORB_PROTECTIVE_SWING_BROKEN";return;}
   if(c.phase==ORB_WAIT_RETEST)
     {
      bool touch=dir>0?(b.low<=c.anchor+tolerance && b.high>=c.anchor-tolerance && b.close>=c.anchor):
                       (b.high>=c.anchor-tolerance && b.low<=c.anchor+tolerance && b.close<=c.anchor);
      if(!touch)return;
      c.retest=b.time;c.opposing=c.opposing || s.trend==-dir;
      c.phase=(conditional_choch && c.opposing)?ORB_WAIT_CHOCH:ORB_WAIT_BOS;
      c.reason=c.phase==ORB_WAIT_CHOCH?"ORB_WAIT_CHOCH":"ORB_WAIT_BOS";return;
     }
   // Opposing HH/HL or LH/LL arising during the pullback also requires CHoCH.
   if(c.mode==1 && conditional_choch && !c.choch_done && s.trend==-dir)
     {c.opposing=true;c.phase=ORB_WAIT_CHOCH;}
   if(c.mode==2 && s.trend==-dir)c.opposing=true;
   SBORBPivot protection;if(dir>0)protection=s.low;else protection=s.high;
   datetime origin=c.mode==1?c.retest:c.breakout;
   if(protection.time>=origin && protection.known<=b.time && !protection.broken)
     {c.protective=protection.price;c.protective_time=protection.time;}
   if(c.phase==ORB_WAIT_CHOCH)
     {
      if(c.opposing && event.direction==dir && event.pivot>0 && event.known<=b.time && event.pivot>=c.breakout)
        {c.choch_done=true;c.choch=b.time;c.choch_pivot=event.pivot;c.phase=ORB_WAIT_BOS;c.reason="ORB_WAIT_BOS";}
      return; // CHoCH and BOS must be distinct candles and pivots.
     }
   bool bos=event.direction==dir && event.pivot>=origin && event.known<=b.time;
   if(c.choch_done)bos=bos && b.time>c.choch && event.pivot!=c.choch_pivot && event.known>c.choch;
   if(bos){c.bos_done=true;c.bos=b.time;}
   if((c.bos_done || (!require_bos && c.mode==1)) && (c.mode!=2 || c.choch_done) &&
      (c.mode==2 || c.protective>0))
     {c.phase=ORB_READY;c.reason="ORB_TRADE_READY";}
  }
bool SBORBRoom(int direction,double entry,double sl,double rr,SBORBLevel &levels[],int policy,double proximity,double clearance,datetime decision,
               double &nearest,double &room,string &level_type)
  {
   nearest=0;room=DBL_MAX;level_type="UNAVAILABLE";
   for(int i=0;i<ArraySize(levels);i++)
     {
      SBORBLevel level=levels[i];if(level.known>decision || level.side!=direction)continue;
      double distance=direction*(level.price-entry);
      // Selective: two prior completed closes accepted beyond this level and price still beyond.
      bool accepted=level.acceptance_closes>=2 && level.accepted<=decision && distance<=-clearance;
      if(policy==ORB_SELECTIVE && accepted)continue;
      if(distance< -proximity)continue;
      double effective=MathMax(0,distance);
      if(effective<room){room=effective;nearest=level.price;level_type=level.type;}
     }
   double required=direction*(entry-sl)*rr;
   if(required<=0)return false;
   return policy==ORB_WARNING || nearest==0 || room-proximity>=required;
  }
void SBORBSweepStep(SBORBLevel &level,MqlRates &b,int seconds,double clearance,int window)
  {
   if(level.known>b.time)return;
   bool penetrated=level.side>0?b.high>level.price+clearance:b.low<level.price-clearance;
   bool returned=level.side>0?b.close<level.price:b.close>level.price;
   if(level.side>0?b.high>=level.price:b.low<=level.price)level.touched=true;
   if(penetrated && (level.penetration==0 || b.time-level.penetration>window*seconds))level.penetration=b.time;
   if(level.penetration>0 && b.time-level.penetration<=window*seconds && returned && level.sweep_origin!=level.penetration)
     {level.swept=true;level.sweep_origin=level.penetration;level.sweep_known=b.time+seconds;}
   bool beyond=level.side*(b.close-level.price)>clearance;
   level.closed_beyond=level.closed_beyond || beyond;
   level.acceptance_closes=beyond?level.acceptance_closes+1:0;
   if(level.acceptance_closes>=2)level.accepted=b.time+seconds;
  }
#endif
