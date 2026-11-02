#ifndef SB_OPENING_RANGE_BREAKOUT
#define SB_OPENING_RANGE_BREAKOUT
SBORBState sb_orb;
string sb_orb_wait="";
void SBORBLog(SBORBCandidate &c,datetime stamp)
  {
   datetime utc,ny=0;if(SBServerToUTC(stamp,utc))SBNYLocal(utc,ny);
   double entry=0,sl=0,tp=0,nearest=0,room=0;string type="UNAVAILABLE";
   MqlTick q;if(SymbolInfoTick(_Symbol,q))entry=c.direction>0?q.ask:q.bid;
   double protection=c.mode==2?c.excursion:c.protective;
   if(protection>0)sl=protection-c.direction*InpORBStopBufferPoints*_Point;
   if(sl>0 && entry>0 && c.direction*(entry-sl)>0)tp=SBTarget(c.direction,entry,sl,InpORBMinimumRR);
   SBORBRoom(c.direction,entry,sl,InpORBMinimumRR,sb_orb_levels,InpORBExternalPolicy,
     InpORBExternalProximityPoints*_Point,InpORBSweepClearancePoints*_Point,stamp+300,nearest,room,type);
   SBEvent(SB_ORB,c.reason,StringFormat("broker=%s NY=%s mode=%s phase=%d id=%s rangeHigh=%.8f rangeLow=%.8f dir=%d breakout=%I64d retest=%I64d CHoCH=%s BOS=%s FVG=%s external=%s nearest=%.8f room=%.8f H1=%d H4=%d context=%d sweep=%s entry=%.8f SL=%.8f TP=%.8f RR=%.2f",
     TimeToString(stamp),TimeToString(ny),c.mode==2?"FALSE_BREAKOUT":"CONTINUATION",c.phase,c.id,sb_orb.high,sb_orb.low,c.direction,
     (long)c.breakout,(long)c.retest,c.choch_done?"CONFIRMED":(c.opposing?"REQUIRED":"NOT_REQUIRED"),c.bos_done?"CONFIRMED":"WAIT",
     c.fvg.present?(c.fvg.invalid?"INVALID":"RESPECTED"):"UNAVAILABLE",type,nearest,room,sb_orb_h1,sb_orb_h4,SBORBTrendContext(c.direction),
     SBORBHasSweep(c.direction,c.sequence_start)?"YES":"NO",entry,sl,tp,InpORBMinimumRR));
  }
void SBORBFinishCandidate(SBORBCandidate &c,MqlRates &b,bool actionable)
  {
   if(c.phase!=ORB_READY)return;
   // Historical readiness is retired during replay; never chase a stale confirmation.
   if(!actionable){SBConsume(SB_ORB,c.id);c.phase=ORB_EXECUTED;c.reason="ORB_REPLAY_RETIRED";return;}
   if(SBConsumed(SB_ORB,c.id)){c.phase=ORB_EXECUTED;c.reason="ORB_DUPLICATE_SUPPRESSED";return;}
   SBSignal signal={};signal.strategy=SB_ORB;signal.orb_mode=c.mode;signal.pattern_type=c.mode;
   signal.direction=c.direction;signal.candle=b.time;signal.id=c.id;signal.rr=InpORBMinimumRR;
   signal.orb_anchor=c.anchor;signal.orb_started=c.sequence_start;signal.max_stop_points=InpORBMaxStopPoints;
   signal.structural_sl=(c.mode==2?c.excursion:c.protective)-c.direction*InpORBStopBufferPoints*_Point;
   signal.sl_method=c.mode==2?"ORB_FALSE_EXCURSION":"ORB_CONFIRMED_RETEST_SWING";
   if(InpORBDrawSignals)SBMarker(SB_ORB,c.id+".signal",b.time,b.close,c.mode==2?clrMagenta:clrLimeGreen);
   SBExecute(signal);
   c.phase=sb_execution_result<0?ORB_BLOCKED:ORB_EXECUTED;
   c.reason=sb_execution_result<0?"ORB_TRADE_BLOCKED_RISK "+sb_execution_reason:
            (sb_execution_result==1?"ORB_SIGNAL_ONLY":"ORB_TRADE_EXECUTED");
   SBORBLog(c,b.time);
  }
void SBORBAdvance(SBORBCandidate &c,SBORBBreak &event,MqlRates &bars[],int end,bool actionable)
  {
   if(!SBORBActive(c))return;
   int previous=c.phase;bool choch=c.choch_done,bos=c.bos_done,had_fvg=c.fvg.present;
   if(InpORBUseFVGValidation)
      SBORBUpdateFVG(c,bars,end,InpORBFVGMinGapPoints*_Point,InpORBFVGMaxDistancePoints*_Point,InpORBFVGMaxAgeBars,300);
   if(SBORBActive(c))SBORBCandidateStep(c,sb_orb.structure,event,bars,end,InpORBRetestTolerancePoints*_Point,
      InpORBInvalidationPoints*_Point,InpORBRequireConditionalCHoCH,InpORBRequireBOS,InpORBMaxRetestBars,InpORBConfirmationTimeoutBars,300);
   if(c.fvg.present && !had_fvg && InpORBDrawFVG)
      SBZone(SB_ORB,c.id+".FVG",c.fvg.formed-900,c.fvg.formed+InpORBFVGMaxAgeBars*300,c.fvg.top,c.fvg.bottom,clrMediumPurple);
   if(InpORBDrawStructure && c.choch_done && !choch)SBMarker(SB_ORB,c.id+".CHoCH",bars[end].time,event.price,clrAqua);
   if(InpORBDrawStructure && c.bos_done && !bos)SBMarker(SB_ORB,c.id+".BOS",bars[end].time,event.price,clrDodgerBlue);
   if(c.phase!=previous || c.fvg.present!=had_fvg || c.choch_done!=choch || c.bos_done!=bos)SBORBLog(c,bars[end].time);
   SBORBFinishCandidate(c,bars[end],actionable);
  }
void SBORBBar(MqlRates &bars[],int end,bool actionable)
  {
   MqlRates b=bars[end];SBORBBreak event={};
   SBORBStructureStep(sb_orb.structure,bars,end,InpORBPivotLeft,InpORBPivotRight,300,InpORBBOSClearancePoints*_Point,event);
   datetime utc,ny;if(!SBServerToUTC(b.time,utc) || !SBNYLocal(utc,ny))return;
   if(utc<sb_orb.end_utc)return;
   MqlDateTime local;TimeToStruct(ny,local);
   if(local.hour*60+local.min>=InpORBTradingEndNYMinutes)
     {
      if(SBORBActive(sb_orb.continuation)){sb_orb.continuation.phase=ORB_EXPIRED;sb_orb.continuation.reason="ORB_SETUP_EXPIRED";SBORBLog(sb_orb.continuation,b.time);}
      if(SBORBActive(sb_orb.reversal)){sb_orb.reversal.phase=ORB_EXPIRED;sb_orb.reversal.reason="ORB_SETUP_EXPIRED";SBORBLog(sb_orb.reversal,b.time);}return;
     }
   SBORBContext(b.time,sb_orb.day);
   for(int i=0;i<ArraySize(sb_orb_levels);i++)
     {
      datetime swept=sb_orb_levels[i].sweep_known;
      SBORBSweepStep(sb_orb_levels[i],b,300,InpORBSweepClearancePoints*_Point,InpORBSweepConfirmationBars);
      if(sb_orb_levels[i].sweep_known>swept)
        {
         if(InpORBLogLiquiditySweeps)SBEvent(SB_ORB,"ORB_EXTERNAL_SWEEP",sb_orb_levels[i].type+" known="+TimeToString(sb_orb_levels[i].known)+" reference only");
         if(InpORBDrawSweeps)SBMarker(SB_ORB,sb_orb_levels[i].type+IntegerToString((long)b.time)+".sweep",b.time,sb_orb_levels[i].price,clrYellow);
        }
      if(InpORBDrawExternal)SBHLine(SB_ORB,sb_orb_levels[i].type,sb_orb_levels[i].price,clrSlateGray);
     }
   // Reversal observation remains active even if the continuation trading mode is disabled.
   if(sb_orb.observing)
     {
      int direction=sb_orb.continuation.direction;
      if(b.time-sb_orb.continuation.breakout>InpORBConfirmationTimeoutBars*300)
        {
         sb_orb.observing=false;
         if(SBORBActive(sb_orb.continuation)){sb_orb.continuation.phase=ORB_EXPIRED;sb_orb.continuation.reason="ORB_SETUP_EXPIRED";SBORBLog(sb_orb.continuation,b.time);}
        }
      sb_orb.continuation.excursion=direction>0?MathMax(sb_orb.continuation.excursion,b.high):MathMin(sb_orb.continuation.excursion,b.low);
      if(sb_orb.observing && b.time>sb_orb.continuation.breakout && SBORBInside(b.close,sb_orb.high,sb_orb.low))
        {
         SBORBCandidate failed=sb_orb.continuation;sb_orb.continuation.phase=ORB_INVALID;
         sb_orb.observing=false;
         sb_orb.continuation.reason="ORB_BREAKOUT_FAILURE";SBORBLog(sb_orb.continuation,b.time);
         if(InpORBEnableFalseBreakout && !SBORBActive(sb_orb.reversal))
           {
            SBORBStart(sb_orb.reversal,2,-direction,b.time,failed.anchor,failed.excursion,sb_orb.structure.trend);
            sb_orb.reversal.sequence_start=failed.sequence_start;
            sb_orb.reversal.id=SBId(_Symbol+"|ORB|F|"+IntegerToString((long)failed.breakout));
            sb_orb.reversal.reason="ORB_FALSE_BREAKOUT_CONFIRMED";SBORBLog(sb_orb.reversal,b.time);
           }
         return; // The return-inside candle cannot also confirm reversal structure.
        }
      if(direction*(b.close-sb_orb.continuation.anchor)<-InpORBInvalidationPoints*_Point)
        {sb_orb.continuation.phase=ORB_INVALID;sb_orb.continuation.reason="ORB_OPPOSITE_RANGE_BREAK";SBORBLog(sb_orb.continuation,b.time);sb_orb.observing=false;return;}
      if(b.time-sb_orb.continuation.breakout>InpORBConfirmationTimeoutBars*300)sb_orb.observing=false;
     }
   if(SBORBActive(sb_orb.reversal))
     {
      int d=sb_orb.reversal.direction;
      sb_orb.reversal.excursion=d>0?MathMin(sb_orb.reversal.excursion,b.low):MathMax(sb_orb.reversal.excursion,b.high);
      if(d*(b.close-sb_orb.reversal.anchor)<-InpORBInvalidationPoints*_Point)
        {sb_orb.reversal.phase=ORB_INVALID;sb_orb.reversal.reason="ORB_FALSE_REBREAKOUT";SBORBLog(sb_orb.reversal,b.time);return;}
      SBORBAdvance(sb_orb.reversal,event,bars,end,actionable);return;
     }
   if(SBORBActive(sb_orb.continuation))
     {
      if(InpORBEnableContinuation)SBORBAdvance(sb_orb.continuation,event,bars,end,actionable);
      if(sb_orb.continuation.phase==ORB_EXECUTED || sb_orb.continuation.phase==ORB_BLOCKED)sb_orb.observing=false;
      else if(b.time-sb_orb.continuation.breakout>InpORBConfirmationTimeoutBars*300)
        {sb_orb.continuation.phase=ORB_EXPIRED;sb_orb.continuation.reason="ORB_SETUP_EXPIRED";SBORBLog(sb_orb.continuation,b.time);}
      return;
     }
   if(end<1)return;
   int dir=SBORBBreakout(bars[end-1].close,b.close,sb_orb.high,sb_orb.low,InpORBBreakoutClearancePoints*_Point);
   if(dir==0 || (!InpORBEnableContinuation && !InpORBEnableFalseBreakout))return;
   SBORBStart(sb_orb.continuation,1,dir,b.time,dir>0?sb_orb.high:sb_orb.low,dir>0?b.high:b.low,sb_orb.structure.trend);
   sb_orb.continuation.id=SBId(_Symbol+"|ORB|C|"+IntegerToString((long)b.time));
   sb_orb.observing=true;
   sb_orb.continuation.reason="ORB_BREAKOUT_CONFIRMED";SBORBLog(sb_orb.continuation,b.time);
   if(InpORBDrawSignals)SBMarker(SB_ORB,sb_orb.continuation.id+".break",b.time,b.close,clrOrange);
   // Order blocks are diagnostic context only; no extra entry filter is introduced.
   if(InpORBLogOrderBlocks && end>0 && (b.close-b.open)*(bars[end-1].close-bars[end-1].open)<0 &&
      MathAbs(b.close-b.open)>MathAbs(bars[end-1].close-bars[end-1].open)*InpOrderBlockDisplacementFactor)
      SBEvent(SB_ORB,"ORB_ORDER_BLOCK_CONTEXT","Opposite previous candle plus displacement; diagnostic only, no entry authority");
  }
void SBEvaluateORB(datetime utc,bool startup)
  {
   if(!InpEnableORBStrategy)return;
   datetime day,midnight;if(!SBNYDay(utc,day,midnight))return;
   if(sb_orb.day!=day)
     {
      ZeroMemory(sb_orb);sb_orb.day=day;sb_orb_context_day=0;sb_orb_htf_checked=0;sb_orb_context_ok=false;
      ArrayResize(sb_orb_levels,0);sb_orb_h1=0;sb_orb_h4=0;sb_orb_wait="";
      if(InpDrawObjects)ObjectsDeleteAll(0,sb_object_prefix+"ORB.");
      if(!SBORBSessionUTC(day,sb_orb.open_utc,sb_orb.end_utc)){sb_orb.invalid=true;SBEvent(SB_ORB,"ORB_SESSION_MAPPING_INVALID","NY session cannot be mapped uniquely");return;}
      SBEvent(SB_ORB,"ORB_NY_DAY_RESET","Pending setups reset; existing positions retain their broker protections");
     }
   if(sb_orb.invalid)return;
   if(!sb_orb.ready)
     {
      string why="";
      if(!SBORBLoadRange(sb_orb.open_utc,sb_orb.end_utc,utc,sb_orb.high,sb_orb.low,why))
        {
         if(why!=sb_orb_wait){SBEvent(SB_ORB,why,"Opening range not available");sb_orb_wait=why;}
         // Allow asynchronous history loading; after a bounded 5 minute grace, skip the day.
         if(utc>sb_orb.end_utc+300)sb_orb.invalid=true;return;
        }
      sb_orb.ready=true;SBEvent(SB_ORB,"ORB_RANGE_READY",StringFormat("high=%.8f low=%.8f frozen NY=%s",sb_orb.high,sb_orb.low,TimeToString(day)));
      if(InpORBDrawRange){SBHLine(SB_ORB,"rangeHigh",sb_orb.high,clrOrangeRed);SBHLine(SB_ORB,"rangeLow",sb_orb.low,clrOrangeRed);}
     }
   datetime closed=iTime(_Symbol,InpORBSignalTF,1);if(closed<=0 || closed<=sb_orb.last)return;
   datetime from,finish;if(!SBUTCToServer(sb_orb.open_utc,from) || !SBUTCToServer(sb_orb.end_utc,finish))return;
   MqlRates bars[];int n=CopyRates(_Symbol,InpORBSignalTF,from-200*300,closed,bars);
   if(n<InpORBPivotLeft+InpORBPivotRight+5)return;
   bool first=sb_orb.last==0;
   for(int i=0;i<n;i++)
     {
      if(bars[i].time<=sb_orb.last || bars[i].time+300>TimeCurrent())continue;
      if(!SBORBValidOHLC(bars[i]) || (!first && bars[i].time>=from && bars[i].time-sb_orb.last!=300))
        {sb_orb.invalid=true;SBEvent(SB_ORB,"ORB_HISTORY_GAP","Skip NY day: chronological M5 reconstruction incomplete");return;}
      if(first && bars[i].time>=finish)
        {sb_orb.invalid=true;SBEvent(SB_ORB,"ORB_HISTORY_MISSING","Missing pre-session structural history");return;}
      if(!first && bars[i].time-sb_orb.last!=300)ZeroMemory(sb_orb.structure);
      first=false;SBORBBar(bars,i,!startup && i==n-1);sb_orb.last=bars[i].time;
     }
  }
#endif
