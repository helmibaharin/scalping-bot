#ifndef SB_VP_RUNTIME
#define SB_VP_RUNTIME
#include "VolumeProfileDrawing.mqh"
SBVPCandidate sb_vp_methods[3];SBORBStructure sb_vp_structure;
datetime sb_vp_last=0,sb_vp_context_last=0,sb_vp_load_retry=0;int sb_vp_context_trend=0;
int sb_vp_signals=INVALID_HANDLE,sb_vp_profiles=INVALID_HANDLE;
string SBVPPhaseName(int phase)
  {switch(phase){case VP_IDLE:return "WAIT_ELIGIBILITY_OR_FRESH_SETUP";case VP_WAIT_REJECTION:return "WAIT_POC_REJECTION";case VP_WAIT_CONFIRMATION:return "WAIT_POC_CONFIRMATION";case VP_WAIT_REENTRY:return "WAIT_REENTRY_CLOSE";case VP_WAIT_PULLBACK:return "WAIT_PULLBACK";case VP_WAIT_BOS:return "WAIT_BOS";case VP_READY:return "SIGNAL_READY";case VP_CONSUMED:return "CONSUMED";case VP_INVALIDATED:return "INVALIDATED";}return "UNKNOWN";}
bool SBVPInitDiagnostics()
  {
   string base=StringFormat("ScalpingBot\\%I64d_%s_%I64u_%I64u_%I64u",AccountInfoInteger(ACCOUNT_LOGIN),_Symbol,InpVPMagicPOCBounce,InpVPMagicValueReversal,InpVPMagicBreakout);
   string signals=base+"_vp_signals.csv",profiles=base+"_vp_profiles.csv";
   if(MQLInfoInteger(MQL_TESTER)){if(FileIsExist(signals) && !FileDelete(signals))return false;if(FileIsExist(profiles) && !FileDelete(profiles))return false;SBVPClearTesterProfiles();}
   sb_vp_signals=FileOpen(signals,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   sb_vp_profiles=FileOpen(profiles,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(sb_vp_signals==INVALID_HANDLE || sb_vp_profiles==INVALID_HANDLE)return false;
   if(FileSize(sb_vp_signals)==0)FileWrite(sb_vp_signals,"timestamp","strategy","method","magic","setup_id","signal_id","direction","previous_state","state","confirmation_type","profile_id","poc","vah","val","atr","breakout_distance_atr","body_size_atr","wick_penetration_atr","bos_level","entry_candidate","sl_candidate","tp_candidate","planned_rr","signal_status","rejection_reason","m15_context","engulf_raw","directional_raw","reference_date","quality","coverage","body_penetration_atr","diagnostic_deep_body");
   if(FileSize(sb_vp_profiles)==0)FileWrite(sb_vp_profiles,"active_day","reference_date","session_start","session_end","profile_id","symbol","source_timeframe","volume_source","bin_size","value_area_fraction","m1_count","expected_m1_count","coverage_ratio","total_tick_volume","poc","vah","val","previous_close","previous_close_location","data_quality_status","poc_tied_bins","weighted_center","reason");
   FileSeek(sb_vp_signals,0,SEEK_END);FileSeek(sb_vp_profiles,0,SEEK_END);return true;
  }
void SBVPLogProfile()
  {
   SBVPProfile p=sb_vp_profile;
   if(sb_vp_profiles!=INVALID_HANDLE){FileWrite(sb_vp_profiles,(long)sb_vp_day,(long)p.day,(long)p.start,(long)p.end,p.id,_Symbol,"M1","TICK_VOLUME",p.bin,p.fraction,p.count,p.expected,p.coverage,p.volume,p.poc,p.vah,p.val,p.close,SBVPCloseLocation(p),p.quality,p.ties,p.center,p.reason);FileFlush(sb_vp_profiles);}
   SBVPDrawProfile(true);
  }
void SBVPTrace(SBVPCandidate &c,int previous,MqlRates &b,double atr,string status,string reason)
  {
   SBSignal s={};SBVPMakeSignal(c,sb_vp_profile,b,sb_vp_context_trend,s);double stop=s.structural_sl,target=0;
   if(c.phase==VP_READY && c.direction*(b.close-stop)>0)target=SBTarget(c.direction,b.close,stop,s.rr);
   if(sb_vp_signals!=INVALID_HANDLE)
     {FileWrite(sb_vp_signals,(long)(b.time+PeriodSeconds(InpVPEntryTF)),"S5_VOLUME_PROFILE",SBStableName(4+c.method),SBMagic(4+c.method),c.id,c.id,c.direction,SBVPPhaseName(previous),SBVPPhaseName(c.phase),c.confirmation,sb_vp_profile.id,sb_vp_profile.poc,sb_vp_profile.vah,sb_vp_profile.val,atr,c.displacement,c.body,c.wick,c.bos_level,b.close,stop,target,s.rr,status,reason,sb_vp_context_trend,c.engulf,c.directional,(long)sb_vp_profile.day,sb_vp_profile.quality,sb_vp_profile.coverage,c.body_inside,c.deep_body);FileFlush(sb_vp_signals);}
   if(previous!=c.phase || status=="BLOCKED" || status=="SIGNAL")SBEvent(4+c.method,"VP_STATE",StringFormat("profile=%s setup=%s at=%I64d from=%s to=%s trigger=%s ATR=%.10f BOS=%.10f",sb_vp_profile.id,c.id,(long)(b.time+PeriodSeconds(InpVPEntryTF)),SBVPPhaseName(previous),SBVPPhaseName(c.phase),reason,atr,c.bos_level));
  }
void SBVPDropAll(datetime time,string reason)
  {
   for(int i=0;i<3;i++)
     {if(StringLen(sb_vp_methods[i].id)>0 && sb_vp_methods[i].phase!=VP_CONSUMED){SBConsume(5+i,sb_vp_methods[i].id);SBVPInvalidate(sb_vp_methods[i],time,reason);}}
  }
void SBVPBlockedSignal(SBSignal &s,string reason)
  {
   SBConsume(s.strategy,s.id);SBPlan p={};p.signal=s;p.magic=SBMagic(s.strategy);p.sl=s.structural_sl;
   SBLogPlan(p,"ENTRY_REJECT",reason);
  }
void SBVPEvaluateBar(MqlRates &bars[],int end,bool actionable)
  {
   int seconds=PeriodSeconds(InpVPEntryTF);MqlRates b=bars[end];double atr=SBVPATR(bars,end,InpVPATRPeriod);
   if(atr<=0 || !MathIsValidNumber(atr)){SBVPDropAll(b.time,"ATR_UNAVAILABLE");return;}
   SBORBBreak structural={};SBORBStructureStep(sb_vp_structure,bars,end,InpVPPivotLeft,InpVPPivotRight,seconds,0,structural);
   MqlRates context[];
   if(!SBShapeLoad(InpVPStructureTF,b.time+seconds,InpVPStructureLookback,context))
     {SBVPDropAll(b.time,"M15_CONTEXT_DATA_UNAVAILABLE");return;}
   int nc=ArraySize(context);
   if(context[nc-1].time>sb_vp_context_last)
     {SBORBStructure s={};SBORBBreak event={};for(int i=0;i<nc;i++)SBORBStructureStep(s,context,i,InpVPPivotLeft,InpVPPivotRight,PeriodSeconds(InpVPStructureTF),0,event);sb_vp_context_trend=s.trend;sb_vp_context_last=context[nc-1].time;}
   SBSignal ready[];
   for(int i=0;i<3;i++)
     {
      bool enabled=i==0?InpVPEnablePOCBounce:(i==1?InpVPEnableValueReversal:InpVPEnableBreakout);if(!enabled)continue;
      int previous=sb_vp_methods[i].phase;sb_vp_methods[i].method=i+1;
      if(i==0)SBVPPOCStep(sb_vp_methods[i],sb_vp_profile,bars[end-1],b,atr,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),seconds);
      if(i==1)SBVPReversalStep(sb_vp_methods[i],sb_vp_profile,bars[end-1],b,sb_vp_structure,atr,seconds);
      if(i==2)SBVPBreakoutStep(sb_vp_methods[i],sb_vp_profile,bars[end-1],b,sb_vp_structure,atr,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),seconds);
      SBVPTrace(sb_vp_methods[i],previous,b,atr,sb_vp_methods[i].phase==VP_READY?"SIGNAL":"EVALUATED",sb_vp_methods[i].reason);
      if(sb_vp_methods[i].phase==VP_INVALIDATED && StringLen(sb_vp_methods[i].id)>0)SBConsume(5+i,sb_vp_methods[i].id);
      if(sb_vp_methods[i].phase!=VP_READY)continue;
      SBSignal signal={};SBVPMakeSignal(sb_vp_methods[i],sb_vp_profile,b,sb_vp_context_trend,signal);
      int n=ArraySize(ready);ArrayResize(ready,n+1);ready[n]=signal;
     }
   int chosen=SBVPCoordinate(ready);
   for(int i=0;i<ArraySize(ready);i++)
     {
      SBSignal signal=ready[i];int method=signal.strategy-5;string reason="";
      if(!actionable)reason="HISTORICAL_CONFIRMATION_RETIRED";
      else if(chosen==-2)reason="SIMULTANEOUS_OPPOSING_SIGNAL";
      else if(i!=chosen)reason="S5_SAME_DIRECTION_TIE_LOWER_PRIORITY";
      else if(InpVPRequireContextAlignment && sb_vp_context_trend!=0 && sb_vp_context_trend!=signal.direction)reason="VP_M15_CONTEXT_COUNTERTREND";
      if(StringLen(reason)>0)
        {if(actionable)SBVPBlockedSignal(signal,reason);else SBConsume(signal.strategy,signal.id);}
      else {SBExecute(signal);reason=sb_execution_reason;}
      int previous=sb_vp_methods[method].phase;sb_vp_methods[method].phase=VP_CONSUMED;sb_vp_methods[method].last=b.time;
      SBVPTrace(sb_vp_methods[method],previous,b,atr,reason=="SIGNAL_ONLY" || StringFind(reason,"ORDER_RESULT")==0?"EXECUTION":"BLOCKED",reason);
     }
  }
void SBEvaluateVP(bool startup)
  {
   if(!InpEnableVolumeProfile)return;datetime closed=iTime(_Symbol,InpVPEntryTF,1);if(closed<=0)return;
   datetime current_day=SBVPBrokerDay(TimeCurrent()),old_day=sb_vp_day;bool was_valid=sb_vp_profile.valid;
   if(old_day!=current_day){SBVPDropAll(closed,"BROKER_DAY_ROLLOVER");for(int i=0;i<3;i++)ZeroMemory(sb_vp_methods[i]);}
   if(!SBVPEnsureProfile(TimeCurrent())){SBVPDropAll(closed,"FROZEN_REFERENCE_PROFILE_UNAVAILABLE");return;}
   if(!was_valid || old_day!=current_day)SBVPLogProfile();
   if(!startup && closed<=sb_vp_last)return;
   if(TimeCurrent()<sb_vp_load_retry)return;
   MqlRates bars[];int n=CopyRates(_Symbol,InpVPEntryTF,1,MathMin(InpMaxReplayBars,InpVPStructureLookback+600),bars),seconds=PeriodSeconds(InpVPEntryTF);
   if(n<InpVPATRPeriod+InpVPPivotLeft+InpVPPivotRight+2 || bars[n-1].time!=closed)
     {SBVPDropAll(closed,"M5_HISTORY_UNAVAILABLE");sb_vp_load_retry=TimeCurrent()+InpVPProfileRetrySeconds;return;}
   for(int i=1;i<n;i++)
     {
      if(bars[i].time<=sb_vp_last)continue;
      if(bars[i].time-bars[i-1].time!=seconds){SBVPDropAll(bars[i].time,"M5_DATA_GAP");ZeroMemory(sb_vp_structure);}
      if(bars[i].time<current_day)
        {SBORBBreak event={};SBORBStructureStep(sb_vp_structure,bars,i,InpVPPivotLeft,InpVPPivotRight,seconds,0,event);sb_vp_last=bars[i].time;continue;}
      SBVPEvaluateBar(bars,i,!startup && i==n-1);sb_vp_last=bars[i].time;
     }
  }
#endif
