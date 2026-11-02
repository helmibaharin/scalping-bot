#ifndef SB_SMT_CONTEXT
#define SB_SMT_CONTEXT
#include "SMTEngine.mqh"
SBSMTState sb_smt;
SBSMTLocation sb_smt_locations[];
string sb_smt_wait="";
bool SBSMTLoad(ENUM_TIMEFRAMES tf,datetime decision,int count,MqlRates &bars[])
  {
   int seconds=PeriodSeconds(tf),n=CopyRates(_Symbol,tf,decision-1,count+1,bars);
   if(n<InpSMTATRPeriod+InpSMTPivotLeft+InpSMTPivotRight+5)return false;
   datetime latest_open=bars[n-1].time;int complete=n;
   while(complete>0 && bars[complete-1].time+seconds>decision)complete--;
   ArrayResize(bars,complete);
   if(complete<InpSMTATRPeriod+InpSMTPivotLeft+InpSMTPivotRight+5)return false;
   if(decision-bars[complete-1].time>2*seconds &&
      !(decision-latest_open<seconds && SBSMTGapAllowed(bars[complete-1].time,latest_open,seconds)))return false;
   for(int i=0;i<complete;i++)if(!SBORBValidOHLC(bars[i]) || (i>0 && bars[i].time<=bars[i-1].time))return false;
   return true;
  }
int SBSMTLoadTrend(ENUM_TIMEFRAMES tf,datetime decision)
  {MqlRates bars[];if(!SBSMTLoad(tf,decision,InpSMTLookbackBars,bars))return SMT_INSUFFICIENT;return SBSMTTrend(bars,decision,PeriodSeconds(tf));}
bool SBSMTContext(datetime decision,bool locations)
  {
   sb_smt.trend=InpSMTTrendMode==2?SMT_NEUTRAL:SBSMTLoadTrend(InpSMTTrendTF,decision);
   sb_smt.context=SBSMTLoadTrend(InpSMTContextTF,decision);
   if(!locations)return true;
   ArrayResize(sb_smt_locations,0);MqlRates primary[],secondary[];
   if(!SBSMTLoad(InpSMTZoneTF,decision,InpSMTLookbackBars,primary)){sb_smt.history_ok=false;return false;}
   SBSMTBuildLocations(primary,(int)InpSMTZoneTF,decision,sb_smt_locations);
   if(InpSMTSecondaryZoneTF!=InpSMTZoneTF)
     {
      if(!SBSMTLoad(InpSMTSecondaryZoneTF,decision,InpSMTLookbackBars,secondary)){sb_smt.history_ok=false;return false;}
      SBSMTBuildLocations(secondary,(int)InpSMTSecondaryZoneTF,decision,sb_smt_locations);
     }
   // Resolve the unfinished HTF interval with CLOSED M1 bars. Otherwise a zone
   // touched earlier in the hour could incorrectly appear fresh at an M15 trap.
   for(int i=0;i<ArraySize(sb_smt_locations);i++)
     {
      SBSMTLocation location=sb_smt_locations[i];int tf_seconds=PeriodSeconds((ENUM_TIMEFRAMES)location.tf);
      if(!location.valid || tf_seconds==60 || (location.type!=SMT_SUPPLY && location.type!=SMT_DEMAND))continue;
      bool owned=SBSMTActive(sb_smt.candidate) && location.id==sb_smt.candidate.location.id;
      bool recent=location.first_touch+tf_seconds>=decision-InpSMTReentryMaxBars*PeriodSeconds(InpSMTTrapTF);
      if(!location.fresh && !owned && !recent)continue;
      datetime completed_end=primary[ArraySize(primary)-1].time+PeriodSeconds(InpSMTZoneTF);
      if(location.tf!=(int)InpSMTZoneTF)completed_end=secondary[ArraySize(secondary)-1].time+PeriodSeconds(InpSMTSecondaryZoneTF);
      datetime from=location.first_touch>0?location.first_touch:(datetime)MathMax((double)location.known,(double)completed_end);
      datetime to=location.first_touch>0?(datetime)MathMin((double)decision,(double)(location.first_touch+tf_seconds)):decision;
      to=(datetime)((long)to/60*60);if(from>=to)continue;
      MqlRates minutes[];int n=CopyRates(_Symbol,PERIOD_M1,from,to-1,minutes);
      if(n<1){sb_smt.history_ok=false;return false;}
      if((minutes[0].time>from && SBSession(from+30)) ||
         (minutes[n-1].time+60<to && SBSession(to-30))){sb_smt.history_ok=false;return false;}
      location.first_touch=0;location.fresh=true;
      for(int j=0;j<n;j++)
        {
         if(minutes[j].time+60>decision)break;
         if(!SBORBValidOHLC(minutes[j])){sb_smt.history_ok=false;return false;}
         if(j>0 && !SBSMTGapAllowed(minutes[j-1].time,minutes[j].time,60)){sb_smt.history_ok=false;return false;}
         if(minutes[j].high>=location.lower && minutes[j].low<=location.upper)
           {location.first_touch=minutes[j].time;location.fresh=false;break;}
        }
      sb_smt_locations[i]=location;
     }
   sb_smt.history_ok=true;return true;
  }
bool SBSMTLocationAlive(SBSMTCandidate &c,datetime decision)
  {
   for(int i=0;i<ArraySize(sb_smt_locations);i++)
     {
      SBSMTLocation location=sb_smt_locations[i];if(location.id!=c.location.id)continue;
      // First contact is the trap itself; freshness is tested before that trap.
      datetime sequence=c.trap.pattern==3?c.trap.breakout:c.trap.start;
      return location.valid && location.known<=sequence && location.known<=decision &&
             (!(location.type==SMT_SUPPLY || location.type==SMT_DEMAND) || !InpSMTRequireFreshZones ||
              location.first_touch==0 || location.first_touch>=sequence);
     }
   return false;
  }
string SBSMTSharedTrapKey(SBSMTTrap &trap)
  {return sb_instance+"SMT.X."+SBId(IntegerToString((long)trap.known)+"|"+IntegerToString(trap.direction));}
bool SBSMTPlanGeometry(SBSignal &signal,double entry,double sl,double &tp,string &why)
  {
   if(signal.strategy!=SB_SMT)return true;
   SBSMTCandidate c=sb_smt.candidate;
   MqlTick live;
   if(!SymbolInfoTick(_Symbol,live) || (signal.direction>0?live.bid<c.trap.extreme:live.bid>c.trap.extreme))
     {why="SMT_TRAP_INVALIDATED";return false;}
   if(c.trap.id!=signal.id || c.phase!=SMT_READY || !SBSMTContext(TimeCurrent(),true) || !SBSMTLocationAlive(c,TimeCurrent()))
     {why="SMT_LOCATION_OR_HISTORY_INVALID";return false;}
   if(!SBSMTTrendAllows(signal.direction,sb_smt.trend,InpSMTTrendMode,InpSMTAllowNeutralTrend) ||
      (InpSMTRequireContextAlignment && sb_smt.context!=signal.direction))
     {why="SMT_TREND_MISMATCH";return false;}
   if(MathAbs(entry-(signal.direction>0?c.trap.lower:c.trap.upper))>InpSMTMaxEntryExtensionATR*c.atr)
     {why="SMT_ENTRY_TOO_EXTENDED";return false;}
   string target;double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(!SBSMTSelectTarget(signal.direction,entry,sb_smt_locations,TimeCurrent(),MathMax(tick,InpSMTTPBufferPoints*_Point),tick,tp,target))
     {why="SMT_NO_VALID_TP_ZONE";return false;}
   double rr;
   if(!SBSMTRRAllows(entry,sl,tp,signal.direction,InpSMTUseMinimumRR && !SBSetupBasedExits(SB_SMT),InpSMTMinimumRR,rr))
     {why="SMT_RR_BELOW_MINIMUM";return false;}
   SBEvent(SB_SMT,"SMT_DYNAMIC_GEOMETRY",StringFormat("PROFILE=%s SL=SWEEP TP_ZONE=%s TP=%.8f RR=%.5f entry=%.8f no_fixed_R_target=true",SBSMTProfileName(),target,tp,rr,entry));
   return true;
  }
bool SBSMTRevalidatePlan(SBPlan &plan,string &why)
  {
   if(plan.signal.strategy!=SB_SMT)return true;
   MqlTick q;datetime utc;if(!SBFreshQuote(q,utc,why))return false;
   double entry=plan.signal.direction>0?q.ask:q.bid,tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(MathAbs(entry-plan.entry)>tick*0.1 || (q.ask-q.bid)/_Point>MathMin(InpMaxSpreadPoints,InpSMTMaxSpreadPoints))
     {why="SMT_REVALIDATION_QUOTE_CHANGED";return false;}
   if(!SBStops(plan.signal.direction,plan.sl,plan.tp,q,true)){why="SMT_BROKER_CONSTRAINT_CHANGED";return false;}
   if(plan.signal.direction>0?q.bid<sb_smt.candidate.trap.extreme:q.bid>sb_smt.candidate.trap.extreme)
     {why="SMT_TRAP_INVALIDATED";return false;}
   double tp=0;if(!SBSMTPlanGeometry(plan.signal,entry,plan.sl,tp,why))return false;
   if(MathAbs(tp-plan.tp)>tick*0.1){why="SMT_TARGET_CHANGED";return false;}
   return true;
  }
#endif
