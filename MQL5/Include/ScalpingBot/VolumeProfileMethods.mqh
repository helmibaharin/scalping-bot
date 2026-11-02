#ifndef SB_VP_METHODS
#define SB_VP_METHODS
#include "VolumeProfileEngine.mqh"
enum SBVPPhase { VP_IDLE=0,VP_WAIT_REJECTION,VP_WAIT_CONFIRMATION,VP_WAIT_REENTRY,VP_WAIT_PULLBACK,VP_WAIT_BOS,VP_READY,VP_CONSUMED,VP_INVALIDATED };
struct SBVPCandidate
  {
   int method,phase,direction,consecutive;datetime start,rejection,pullback,bos_known,bos_pivot,last;
   double extreme,break_close,bos_level,atr,body,displacement,wick,nearest,body_inside;
   string id,reason,confirmation;bool engulf,directional,deep_body;
  };
datetime SBVPBrokerDay(datetime t){return (datetime)((long)t/86400*86400);}
double SBVPATR(MqlRates &b[],int end,int period)
  {if(end<period)return 0;double tr=0;for(int i=end-period+1;i<=end;i++)tr+=MathMax(b[i].high-b[i].low,MathMax(MathAbs(b[i].high-b[i-1].close),MathAbs(b[i].low-b[i-1].close)));return tr/period;}
void SBVPInvalidate(SBVPCandidate &c,datetime time,string reason)
  {c.phase=VP_INVALIDATED;c.reason=reason;c.last=time;}
void SBVPStart(SBVPCandidate &c,int method,int direction,MqlRates &b,SBVPProfile &p,double atr)
  {
   ZeroMemory(c);c.method=method;c.direction=direction;c.start=b.time;c.last=b.time;c.atr=atr;c.extreme=direction>0?b.low:b.high;
   c.id=SBId(_Symbol+"|VP|"+p.id+"|"+IntegerToString(method)+"|"+IntegerToString(direction)+"|"+IntegerToString((long)b.time));
  }
bool SBVPEngulf(MqlRates &previous,MqlRates &b,int direction,double tolerance)
  {
   if(direction*(previous.close-previous.open)>=0 || direction*(b.close-b.open)<=0)return false;
   return MathMin(b.open,b.close)<=MathMin(previous.open,previous.close)+tolerance && MathMax(b.open,b.close)>=MathMax(previous.open,previous.close)-tolerance;
  }
bool SBVPExpired(SBVPCandidate &c,MqlRates &b,int seconds)
  {if(c.phase==VP_IDLE || c.phase==VP_CONSUMED || c.phase==VP_INVALIDATED)return false;if(b.time-c.start>InpVPSetupExpiryBars*seconds){SBVPInvalidate(c,b.time,"SETUP_EXPIRED_MISSING_CONFIRMATION_OR_BOS");return true;}return false;}
void SBVPPOCStep(SBVPCandidate &c,SBVPProfile &p,MqlRates &previous,MqlRates &b,double atr,double tick,int seconds)
  {
   if(SBVPCloseLocation(p)==0){c.phase=VP_IDLE;c.reason="PREVIOUS_CLOSE_INSIDE_VALUE_INELIGIBLE";return;}
   if(SBVPExpired(c,b,seconds) || c.phase==VP_READY)return;
   int dir=SBVPCloseLocation(p);double tolerance=InpVPPOCProximityATR*atr;
   if(c.phase==VP_CONSUMED || c.phase==VP_INVALIDATED){if(b.time<=c.last)return;c.phase=VP_IDLE;}
   if(c.phase==VP_IDLE)
     {
      bool from_correct_side=dir*(previous.close-p.poc)>tolerance;
      bool approaching=dir*(previous.close-b.close)>0 || (dir>0?b.low<previous.low:b.high>previous.high);
      bool test=dir>0?b.low<=p.poc+tolerance:b.high>=p.poc-tolerance;
      if(!from_correct_side || !approaching || !test)return;
      SBVPStart(c,1,dir,b,p,atr);c.phase=VP_WAIT_REJECTION;c.reason="COHERENT_POC_APPROACH_TEST";
     }
   double penetration=dir>0?MathMax(0,p.poc-b.low):MathMax(0,b.high-p.poc);
   if(penetration>InpVPPOCMaxPenetrationATR*atr || dir*(b.close-p.poc)<=0)
     {SBVPInvalidate(c,b.time,"POC_REJECTION_FAILED_OR_EXCESS_PENETRATION");return;}
   if(c.phase==VP_WAIT_REJECTION)
     {
      if(dir*(b.close-b.open)<=0)return;
      c.rejection=b.time;c.phase=VP_WAIT_CONFIRMATION;c.reason="POC_REJECTION_CONFIRMED";c.consecutive=0;
      // Engulfing can confirm this completed rejection; a touch by itself cannot.
     }
   if(MathAbs(b.close-p.poc)>InpVPMaxEntryExtensionATR*atr){SBVPInvalidate(c,b.time,"POC_CONFIRMATION_TOO_EXTENDED");return;}
   c.engulf=SBVPEngulf(previous,b,dir,InpVPEngulfToleranceTicks*tick);
   if(b.time>c.rejection)
     {if(dir*(b.close-b.open)>0 && dir*(b.close-previous.close)>0)c.consecutive++;else c.consecutive=0;}
   c.directional=c.consecutive>=InpVPDirectionalCandles;
   if(!c.engulf && !c.directional)return;
   c.phase=VP_READY;c.last=b.time;c.atr=atr;
   c.confirmation=c.engulf?(dir>0?"BULLISH_ENGULFING":"BEARISH_ENGULFING"):(dir>0?"MULTIPLE_BULLISH_CANDLES":"MULTIPLE_BEARISH_CANDLES");
   c.reason=c.engulf?"ENGULFING_2R":"DIRECTIONAL_CANDLES_1_5R";
  }
void SBVPReversalStep(SBVPCandidate &c,SBVPProfile &p,MqlRates &previous,MqlRates &b,SBORBStructure &structure,double atr,int seconds)
  {
   if(SBVPCloseLocation(p)!=0){c.phase=VP_IDLE;c.reason="PREVIOUS_CLOSE_OUTSIDE_VALUE_INELIGIBLE";return;}
   if(SBVPExpired(c,b,seconds) || c.phase==VP_READY)return;
   if(c.phase==VP_CONSUMED || c.phase==VP_INVALIDATED){if(b.time<=c.last)return;c.phase=VP_IDLE;}
   bool below=b.low<p.val,above=b.high>p.vah;
   if(c.phase==VP_IDLE)
     {
      if(below && above){SBVPInvalidate(c,b.time,"TWO_SIDED_EXCURSION_AMBIGUOUS");return;}
      if(!below && !above)return;
      // A fresh crossing from a completed inside/at-boundary close is mandatory.
      if(previous.close<p.val || previous.close>p.vah)return;
      SBVPStart(c,2,below?1:-1,b,p,atr);c.phase=VP_WAIT_REENTRY;c.reason="FRESH_OUTSIDE_VALUE_EXCURSION";
     }
   c.extreme=c.direction>0?MathMin(c.extreme,b.low):MathMax(c.extreme,b.high);
   if(!(b.close>p.val && b.close<p.vah))return;
   SBORBPivot pivot=c.direction>0?structure.low:structure.high;
   bool confirmed=pivot.time>=c.start && pivot.known<=b.time && (c.direction>0?pivot.price<=c.extreme:pivot.price>=c.extreme);
   if(confirmed)c.extreme=pivot.price;
   else if(!InpVPExcursionStopFallback){SBVPInvalidate(c,b.time,"NO_KNOWN_EXCURSION_SWING_FALLBACK_DISABLED");return;}
   c.confirmation=confirmed?"CONFIRMED_EXCURSION_SWING":"COMPLETED_EXCURSION_EXTREME_FALLBACK";
   c.phase=VP_READY;c.last=b.time;c.atr=atr;c.reason="STRICT_COMPLETED_CLOSE_BACK_INSIDE_VALUE";
  }
void SBVPBreakoutStep(SBVPCandidate &c,SBVPProfile &p,MqlRates &previous,MqlRates &b,SBORBStructure &structure,double atr,double tick,int seconds)
  {
   if(SBVPExpired(c,b,seconds) || c.phase==VP_READY)return;
   if(c.phase==VP_CONSUMED || c.phase==VP_INVALIDATED){if(b.time<=c.last)return;c.phase=VP_IDLE;}
   if(c.phase==VP_IDLE)
     {
      int dir=previous.close<=p.vah && b.close>=p.vah+InpVPBreakoutDistanceATR*atr?1:
        (previous.close>=p.val && b.close<=p.val-InpVPBreakoutDistanceATR*atr?-1:0);
      if(dir==0 || dir*(b.close-b.open)<=0 || MathAbs(b.close-b.open)<InpVPBreakoutBodyATR*atr)return;
      SBVPStart(c,3,dir,b,p,atr);c.phase=VP_WAIT_PULLBACK;c.break_close=b.close;c.body=MathAbs(b.close-b.open)/atr;
      c.displacement=dir*(b.close-(dir>0?p.vah:p.val))/atr;c.reason="SIGNIFICANT_COMPLETED_BREAKOUT_WAIT_PULLBACK";return;
     }
   int dir=c.direction;double level=dir>0?p.vah:p.val,epsilon=tick*1e-6;
   c.body_inside=MathMax(0,MathMax(-dir*(b.open-level),-dir*(b.close-level)))/atr;
   c.deep_body=c.body_inside>InpVPDiagnosticDeepBodyATR;
   c.wick=(dir>0?MathMax(0,level-b.low):MathMax(0,b.high-level))/atr;
   if(dir*(b.open-level)<-epsilon || dir*(b.close-level)<-epsilon)
     {SBVPInvalidate(c,b.time,"PULLBACK_BODY_INSIDE_VALUE");return;}
   if(c.wick>InpVPWickToleranceATR+1e-9){SBVPInvalidate(c,b.time,"EXCESSIVE_WICK_PENETRATION");return;}
   if(c.phase==VP_WAIT_PULLBACK)
     {
      double near=dir>0?b.low-level:level-b.high;
      double retrace=dir>0?c.break_close-b.low:b.high-c.break_close;
      if(near>InpVPPullbackProximityATR*atr || retrace<InpVPMinimumRetracementATR*atr)return;
      c.nearest=near/atr;c.pullback=b.time;c.extreme=dir>0?b.low:b.high;c.phase=VP_WAIT_BOS;c.reason="WICK_ONLY_PULLBACK_WAIT_CONFIRMED_STRUCTURE";
      return; // Pullback candle is never its own subsequent BOS.
     }
   if(b.time<=c.pullback)return;
   if((dir>0 && b.low<c.extreme-epsilon) || (dir<0 && b.high>c.extreme+epsilon))
     {SBVPInvalidate(c,b.time,"PULLBACK_STRUCTURE_BROKEN_BEFORE_BOS");return;}
   SBORBPivot protect=dir>0?structure.low:structure.high;
   bool protective_known=protect.time==c.pullback && protect.known<=b.time && MathAbs(protect.price-c.extreme)<=epsilon;
   if(c.bos_pivot==0)
     {
      SBORBPivot pivot=dir>0?structure.high:structure.low;
      if(pivot.time>0 && !(pivot.broken && pivot.time<c.start) && pivot.time>=c.start-InpVPBOSReferenceMaxAgeBars*seconds && pivot.time<=c.pullback && pivot.known<=b.time && dir*(pivot.price-level)>0)
        {c.bos_pivot=pivot.time;c.bos_known=pivot.known;c.bos_level=pivot.price;}
     }
   if(!protective_known || c.bos_pivot==0 || c.bos_known>b.time)return;
   if(dir*(previous.close-c.bos_level)>0 || dir*(b.close-c.bos_level)<=epsilon)return;
   c.phase=VP_READY;c.last=b.time;c.atr=atr;c.confirmation="CONFIRMED_DIRECTIONAL_BOS";c.reason="BREAKOUT_PULLBACK_BOS_COMPLETE";
  }
void SBVPMakeSignal(SBVPCandidate &c,SBVPProfile &p,MqlRates &b,int context,SBSignal &s)
  {
   ZeroMemory(s);s.strategy=4+c.method;s.direction=c.direction;s.id=c.id;s.pattern_id=c.id;s.pattern_type=c.method;
   s.candle=b.time;s.entry_confirmation=b.time+PeriodSeconds(InpVPEntryTF);s.method=SBStableName(s.strategy);s.family="VOLUME_PROFILE";s.subtype=c.confirmation;
   s.vp_profile=p.id;s.vp_quality=p.quality;s.vp_atr=c.atr;s.vp_poc=p.poc;s.vp_vah=p.vah;s.vp_val=p.val;s.vp_context=context;
   s.vp_break_distance=c.displacement;s.vp_body=c.body;s.vp_wick=c.wick;s.vp_bos=c.bos_level;s.vp_engulf=c.engulf;s.vp_directional=c.directional;
   s.max_stop_points=InpVPMaxStopPoints;s.boundary=c.method==1?p.poc:(c.method==2?(c.direction>0?p.val:p.vah):(c.direction>0?p.vah:p.val));
   s.structural_sl=(c.method==1?p.poc:c.extreme)-c.direction*InpVPStopBufferATR*c.atr;
   s.sl_method=c.method==1?"POC_ATR_BUFFER":(c.method==2?c.confirmation:"CONFIRMED_PULLBACK_SWING");
   s.rr=c.method==1?(c.engulf?InpVPPOCEngulfRR:InpVPPOCDirectionalRR):(c.method==2?InpVPReversalRR:InpVPBreakoutRR);
   s.pivots=StringFormat("VP_PROFILE=%s;QUALITY=%s;ATR=%.10f;POC=%.10f;VAH=%.10f;VAL=%.10f;M15_CONTEXT=%d;BREAK_ATR=%.6f;BODY_ATR=%.6f;WICK_ATR=%.6f;BOS=%.10f;ENGULF=%d;DIRECTIONAL=%d;REF=%I64d;COVERAGE=%.8f",
    p.id,p.quality,c.atr,p.poc,p.vah,p.val,context,c.displacement,c.body,c.wick,c.bos_level,c.engulf,c.directional,(long)p.day,p.coverage);
  }
// First earliest confirmation wins only inside S5. Opposing earliest ties skip all.
int SBVPCoordinate(SBSignal &signals[])
  {
   if(ArraySize(signals)==0)return -1;int selected=0;
   for(int i=1;i<ArraySize(signals);i++)if(signals[i].entry_confirmation<signals[selected].entry_confirmation ||
      (signals[i].entry_confirmation==signals[selected].entry_confirmation && signals[i].strategy<signals[selected].strategy))selected=i;
   for(int i=0;i<ArraySize(signals);i++)if(signals[i].entry_confirmation==signals[selected].entry_confirmation && signals[i].direction!=signals[selected].direction)return -2;
   return selected;
  }
#endif
