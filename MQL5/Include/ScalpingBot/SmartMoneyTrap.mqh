#ifndef SB_SMART_MONEY_TRAP
#define SB_SMART_MONEY_TRAP
void SBSMTLog(SBSMTCandidate &c,datetime decision)
  {
   c.changed=decision;
   SBEvent(SB_SMT,c.reason,StringFormat("PROFILE=%s time=%s state=%d TREND_TF=%d TREND=%s CONTEXT=%s LOCATION=%s locationTF=%d zone=%s upper=%.8f lower=%.8f formed=%I64d known=%I64d FRESH=%s MOMENTUM=%s ZONE_BOS=%s PATTERN=%d babies=%d trapKnown=%I64d SWEEP=%.8f CHOCH=%s BOS=%s FVG=%s id=%s",
    SBSMTProfileName(),TimeToString(decision,TIME_DATE|TIME_SECONDS),c.phase,(int)InpSMTTrendTF,SBSMTTrendName(c.trend),SBSMTTrendName(c.context),
    SBSMTLocationName(c.location.type),c.location.tf,c.location.id,c.location.upper,c.location.lower,(long)c.location.formed,(long)c.location.known,
    c.location.fresh?"true":(c.location.first_touch>=(c.trap.pattern==3?c.trap.breakout:c.trap.start)?"FIRST_CONTACT_IN_SEQUENCE":"false"),
    c.location.momentum?"true":"false",c.location.bos?"true":"false",c.trap.pattern,c.trap.babies,(long)c.trap.known,c.trap.extreme,
    c.choch_done?"CONFIRMED":(c.opposing?"WAIT":"NOT_APPLICABLE"),c.bos_done?"CONFIRMED":"WAIT",c.fvg.present?(c.fvg.invalid?"INVALID":"VALID"):"UNAVAILABLE",c.trap.id));
  }
void SBSMTWait(string reason)
  {if(reason!=sb_smt_wait){SBEvent(SB_SMT,reason,"PROFILE="+SBSMTProfileName());sb_smt_wait=reason;}}
void SBSMTRejectTrap(SBSMTTrap &trap,string reason)
  {
   int valid=0,fresh=0,strong=0;string last="UNAVAILABLE";
   for(int i=0;i<ArraySize(sb_smt_locations);i++)
     {
      SBSMTLocation location=sb_smt_locations[i];if(location.direction!=trap.direction)continue;
      if(location.valid)valid++;if(location.fresh)fresh++;if(location.bos && location.momentum)strong++;
      if(!location.valid)last=location.reason;else if(!location.fresh)last="SMT_ZONE_NOT_FRESH";
     }
   SBEvent(SB_SMT,reason,StringFormat("PROFILE=%s id=%s pattern=%d trapKnown=%I64d direction=%d TREND=%s CONTEXT=%s valid_locations=%d fresh=%d strong_BOS=%d contextReason=%s",
     SBSMTProfileName(),trap.id,trap.pattern,(long)trap.known,trap.direction,SBSMTTrendName(sb_smt.trend),SBSMTTrendName(sb_smt.context),valid,fresh,strong,last));
  }
void SBSMTDrawCandidate(SBSMTCandidate &c)
  {
   if(!InpSMTDrawObjects)return;string prefix=SBSMTProfileName()+"."+IntegerToString((long)InpSMTMagicNumber)+".";
   SBZone(SB_SMT,prefix+c.location.id,c.location.formed,c.trap.known,c.location.upper,c.location.lower,c.trap.direction>0?clrSeaGreen:clrIndianRed);
   SBZone(SB_SMT,prefix+c.trap.id+".mother",c.trap.mother,c.trap.known,c.trap.upper,c.trap.lower,clrDodgerBlue);
   SBHLine(SB_SMT,prefix+c.trap.id+".sweep",c.trap.extreme,clrMagenta);
   SBMarker(SB_SMT,prefix+c.trap.id+".trap",c.trap.start,c.trap.extreme,clrYellow);
  }
void SBSMTDrawContext(datetime decision)
  {
   if(!InpSMTDrawObjects || !InpDrawObjects)return;
   string prefix=SBSMTProfileName()+"."+IntegerToString((long)InpSMTMagicNumber)+".ctx.";
   ObjectsDeleteAll(0,sb_object_prefix+"SMT."+prefix);int drawn=0;
   for(int i=ArraySize(sb_smt_locations)-1;i>=0 && drawn<40;i--)
     {
      SBSMTLocation location=sb_smt_locations[i];if(!location.valid)continue;
      if((location.type==SMT_SUPPLY || location.type==SMT_DEMAND) && InpSMTRequireFreshZones && !location.fresh)continue;
      if(location.type==SMT_BSL || location.type==SMT_SSL)SBHLine(SB_SMT,prefix+location.id,location.direction>0?location.lower:location.upper,clrGold);
      else SBZone(SB_SMT,prefix+location.id,location.formed,decision,location.upper,location.lower,location.direction>0?clrSeaGreen:clrIndianRed);
      drawn++;
     }
  }
void SBSMTFinish(SBSMTCandidate &c,MqlRates &b,bool actionable)
  {
   if(c.phase!=SMT_READY)return;
   if(!actionable || SBConsumed(SB_SMT,c.trap.id))
     {SBConsume(SB_SMT,c.trap.id);c.phase=SMT_EXECUTED;c.reason="SMT_REPLAY_OR_DUPLICATE_RETIRED";SBSMTLog(c,b.time+SBSignalSeconds(SB_SMT));return;}
   string key=SBSMTSharedTrapKey(c.trap);
   if(GlobalVariableCheck(key))
     {SBConsume(SB_SMT,c.trap.id);c.phase=SMT_BLOCKED;c.reason="SMT_CROSS_PROFILE_DUPLICATE";SBSMTLog(c,b.time+SBSignalSeconds(SB_SMT));return;}
   if(!SBPut(key,(double)TimeCurrent())){SBHalt("Cannot persist cross-profile SMT trap");return;}GlobalVariablesFlush();
   SBSignal signal={};signal.strategy=SB_SMT;signal.direction=c.trap.direction;signal.pattern_type=c.trap.pattern;
   signal.id=c.trap.id;signal.candle=b.time;signal.max_stop_points=InpSMTMaxStopPoints;signal.rr=1;
   MqlTick q;if(!SymbolInfoTick(_Symbol,q)){c.phase=SMT_BLOCKED;c.reason="SMT_QUOTE_UNAVAILABLE";SBConsume(SB_SMT,c.trap.id);SBSMTLog(c,b.time);return;}
   double buffer=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),InpSMTStopBufferPoints*_Point+
                       InpSMTStopATRBuffer*c.atr+InpSMTStopSpreadMultiplier*(q.ask-q.bid));
   signal.structural_sl=c.trap.extreme-signal.direction*buffer;signal.sl_method="SMT_SWEEP_DYNAMIC_ZONE";
   c.phase=SMT_VALIDATING_RISK;c.reason="SMT_VALIDATING_RISK";SBSMTLog(c,b.time+SBSignalSeconds(SB_SMT));
   // Geometry validates the live candidate at READY; the transition above is diagnostic.
   c.phase=SMT_READY;SBExecute(signal);
   c.phase=sb_execution_result<0?SMT_BLOCKED:SMT_EXECUTED;
   if(sb_execution_result<0 && (StringFind(sb_execution_reason,"SMT_TRAP_INVALIDATED")==0 || StringFind(sb_execution_reason,"SMT_LOCATION")==0))c.phase=SMT_INVALIDATED;
   c.reason=sb_execution_result<0?"SMT_ACCOUNT_RISK_BLOCKED "+sb_execution_reason:(sb_execution_result==1?"SMT_SIGNAL_ONLY":"SMT_ORDER_ACCEPTED");
   SBSMTLog(c,b.time+SBSignalSeconds(SB_SMT));
  }
void SBSMTCheckTrap(datetime decision)
  {
   MqlRates traps[];int seconds=PeriodSeconds(InpSMTTrapTF);
   if(!SBSMTLoad(InpSMTTrapTF,decision,MathMax(InpSMTATRPeriod+10,InpSMTMaxPatternAgeBars+InpSMTReentryMaxBars+5),traps))
     {SBSMTWait("SMT_TRAP_HISTORY_PENDING");return;}
   int end=ArraySize(traps)-1;
   if(traps[end].time<=sb_smt.last_trap)return;
   sb_smt.last_trap=traps[end].time;
   if(SBSMTActive(sb_smt.candidate) || traps[end].time+seconds<=decision-SBSignalSeconds(SB_SMT))return;
   if(!SBSMTContext(traps[end].time,true)){SBSMTWait("SMT_ZONE_HISTORY_PENDING");return;}
   SBSMTDrawContext(traps[end].time);
   SBSMTTrap trap={};
   if(!SBSMTDetectTrap(traps,end,seconds,sb_smt_locations,trap)){SBSMTWait("SMT_TRAP_NOT_CONFIRMED");return;}
   if(!SBSMTTrendAllows(trap.direction,sb_smt.trend,InpSMTTrendMode,InpSMTAllowNeutralTrend))
     {SBSMTRejectTrap(trap,sb_smt.trend==0 || sb_smt.trend==SMT_INSUFFICIENT?"SMT_TREND_NEUTRAL":"SMT_TREND_MISMATCH");return;}
   if(InpSMTRequireContextAlignment && sb_smt.context!=trap.direction){SBSMTRejectTrap(trap,"SMT_CONTEXT_MISMATCH");return;}
   SBSMTLocation location={};
   if(!SBSMTMatchLocation(trap,sb_smt_locations,location)){SBSMTRejectTrap(trap,"SMT_NO_VALID_LOCATION");return;}
   if(SBConsumed(SB_SMT,trap.id) || GlobalVariableCheck(SBSMTSharedTrapKey(trap))){SBSMTWait("SMT_DUPLICATE_RETIRED");return;}
   double atr=SBSMTATR(traps,end,InpSMTATRPeriod);
   SBSMTStart(sb_smt.candidate,trap,location,sb_smt.trend,sb_smt.context,sb_smt.structure.trend,atr);
   sb_smt_wait="";SBSMTLog(sb_smt.candidate,trap.known);SBSMTDrawCandidate(sb_smt.candidate);
  }
void SBEvaluateSMT(bool startup)
  {
   if(!InpEnableSMTStrategy)return;
   datetime closed=iTime(_Symbol,InpSMTEntryTF,1);if(closed<=0 || closed<=sb_smt.last)return;
   int seconds=PeriodSeconds(InpSMTEntryTF),ratio=PeriodSeconds(InpSMTTrapTF)/seconds;
   int count=MathMin(InpMaxReplayBars,InpSMTLookbackBars+InpSMTConfirmationBars+ratio*(InpSMTMaxPatternAgeBars+InpSMTReentryMaxBars)+20);
   MqlRates bars[];int n=CopyRates(_Symbol,InpSMTEntryTF,1,count,bars);if(n<InpSMTATRPeriod+5)return;
   for(int i=0;i<n;i++)
     {
      MqlRates b=bars[i];if(b.time<=sb_smt.last || b.time+seconds>TimeCurrent())continue;
      if(sb_smt.last>0 && b.time-sb_smt.last!=seconds)
        {
         if(SBSMTActive(sb_smt.candidate))
           {sb_smt.candidate.phase=SMT_INVALIDATED;sb_smt.candidate.reason="SMT_HISTORY_GAP";SBConsume(SB_SMT,sb_smt.candidate.trap.id);SBSMTLog(sb_smt.candidate,b.time);}
         ZeroMemory(sb_smt.structure);
        }
      // Trap snapshot is evaluated at this entry candle's OPEN, before processing its close.
      if(i>=InpSMTATRPeriod+InpSMTPivotLeft+InpSMTPivotRight)SBSMTCheckTrap(b.time);
      SBORBBreak event={};SBORBStructureStep(sb_smt.structure,bars,i,InpSMTPivotLeft,InpSMTPivotRight,seconds,InpSMTBOSClearancePoints*_Point,event);
      if(SBSMTActive(sb_smt.candidate))
        {
         int phase=sb_smt.candidate.phase;string reason=sb_smt.candidate.reason;
         bool choch=sb_smt.candidate.choch_done,bos=sb_smt.candidate.bos_done,fvg=sb_smt.candidate.fvg.present;
         bool context=SBSMTContext(b.time+seconds,true);
         SBSMTStep(sb_smt.candidate,event,bars,i,seconds,sb_smt.trend,sb_smt.context,context && SBSMTLocationAlive(sb_smt.candidate,b.time+seconds));
         if(phase!=sb_smt.candidate.phase || reason!=sb_smt.candidate.reason || fvg!=sb_smt.candidate.fvg.present)SBSMTLog(sb_smt.candidate,b.time+seconds);
         if(InpSMTDrawObjects)
           {
            if(!choch && sb_smt.candidate.choch_done)SBMarker(SB_SMT,SBSMTProfileName()+sb_smt.candidate.trap.id+".CHoCH",b.time,event.price,clrAqua);
            if(!bos && sb_smt.candidate.bos_done)SBMarker(SB_SMT,SBSMTProfileName()+sb_smt.candidate.trap.id+".BOS",b.time,event.price,clrLimeGreen);
           }
         if(sb_smt.candidate.phase==SMT_INVALIDATED || sb_smt.candidate.phase==SMT_EXPIRED)SBConsume(SB_SMT,sb_smt.candidate.trap.id);
         SBSMTFinish(sb_smt.candidate,b,!startup && i==n-1);
        }
      sb_smt.last=b.time;
     }
  }
#endif
