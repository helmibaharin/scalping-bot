#ifndef SB_FOUR_HOUR
#define SB_FOUR_HOUR
SB4HState sb_four;
datetime sb_four_last=0;
SBSessionRange sb_four_range;
string sb_four_wait="";
datetime sb_four_replay_retry=0;
bool SBLoad4HRange(datetime utc)
  {
   datetime day,midnight;if(!SBNYDay(utc,day,midnight))return false;
   if(sb_four.day!=day)
     {
      if(sb_four.side!=0)SBEvent(SB_4H,"DAY_EXPIRED","Pending breakout expired at NY midnight; open positions retained");
      ZeroMemory(sb_four);sb_four.day=day;sb_four_last=0;sb_four_replay_retry=0;sb_four_wait="";
      SBEvent(SB_4H,"NY_DAY_RESET",TimeToString(day,TIME_DATE));
     }
   if(sb_four.invalid)return false;
   if(!SBRecoverSessionRange(SB_4H,utc,0,240,sb_four_range))
     {sb_four.high=sb_four_range.high;sb_four.low=sb_four_range.low;return false;}
   if(!sb_four.ready)
     {
      sb_four.high=sb_four_range.high;sb_four.low=sb_four_range.low;sb_four.ready=true;
      string id=TimeToString(day,TIME_DATE);
      SBHLine(SB_4H,id+".rangeHigh",sb_four.high,clrOrange);SBHLine(SB_4H,id+".rangeLow",sb_four.low,clrOrange);
      SBZone(SB_4H,id+".range",sb_four_range.from,sb_four_range.to,sb_four.high,sb_four.low,clrOrange);
     }
   return true;
  }
void SB4HBar(MqlRates &bars[],int end,bool actionable)
  {
   MqlRates b=bars[end];datetime utc,day,midnight;
   if(!SBServerToUTC(b.time,utc) || !SBNYDay(utc,day,midnight) || day!=sb_four.day || utc<midnight+4*3600)return;
   if(sb_four.invalid)return;
   if(sb_four_last>0 && b.time-sb_four_last!=300)
     {sb_four_wait="RANGE_HISTORY_INCOMPLETE M5_HISTORY_GAP";SBEvent(SB_4H,"SETUP_HISTORY_RETRY","Cannot reconstruct excursion safely; retry required history");return;}
   sb_four_last=b.time;
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   int event=SB4HStep(sb_four.side,sb_four.extreme,b.open,b.high,b.low,b.close,sb_four.low,sb_four.high,tick);
   if(event==1 || event==2)
     {
      sb_four.breakout=b.time;
      SBEvent(SB_4H,event==1?"UPPER_BREAKOUT":"LOWER_BREAKOUT","Waiting for completed close inside until NY day ends");
      SBMarker(SB_4H,IntegerToString((long)b.time)+".break",b.time,b.close,clrOrange);return;
     }
   if(event==4)
     {
      // No silent reversal: entire range is retired for this NY day.
      sb_four.invalid=true;SBEvent(SB_4H,"OPPOSITE_BOUNDARY_INVALIDATION","Closed beyond opposite boundary; no reverse entry; range retired for day");return;
     }
   if(event!=3)return;
   SBSignal signal={};signal.strategy=SB_4H;signal.direction=-sb_four.side;signal.candle=b.time;
   signal.id=SBId(_Symbol+"|4H|"+IntegerToString((long)sb_four.day)+"|"+IntegerToString((long)sb_four.breakout));
   signal.sl_method="BREAKOUT_EXTREME";
   signal.structural_sl=sb_four.extreme+sb_four.side*Inp4HStopBufferPoints*_Point;
   signal.rr=Inp4HRewardRiskRatio;signal.max_stop_points=Inp4HMaxStopPoints;
   // Freeze excursion through the return candle, then release pending setup.
   sb_four.side=0;
   SBEvent(SB_4H,"RETURN_INSIDE",StringFormat("id=%s frozenExtreme=%.8f actionable=%s",signal.id,sb_four.extreme,actionable?"true":"false"));
   SBMarker(SB_4H,signal.id+".return",b.time,b.close,clrAqua);
   if(!actionable || SBConsumed(SB_4H,signal.id))return;
   MqlTick q;if(!SymbolInfoTick(_Symbol,q))return;
   double entry=signal.direction>0?q.ask:q.bid;
   if(MathAbs(entry-signal.structural_sl)/_Point>Inp4HMaxStopPoints)
     {
      datetime origin=0;double zl=0,zh=0;bool found=false;
      if(signal.direction<0)
        {found=SBResistance(bars,end,entry,signal.structural_sl,origin,zl,zh);signal.sl_method="RESISTANCE";}
      else
        {found=SBBullishOrderBlock(bars,end,entry,signal.structural_sl,origin,zl,zh);signal.sl_method="ORDER_BLOCK";}
      if(!found){SBConsume(SB_4H,signal.id);SBEvent(SB_4H,"ENTRY_REJECT","OVERSIZED_EXTREME_NO_VALID_DIRECTIONAL_FALLBACK");return;}
      SBZone(SB_4H,signal.id+".fallback",origin,b.time,zh,zl,clrMediumPurple);
      SBEvent(SB_4H,signal.sl_method+"_SL_SELECTED",StringFormat("stop=%.8f",signal.structural_sl));
     }
   SBExecute(signal);
  }
void SBEvaluate4H(datetime utc,bool startup)
  {
   if(!InpEnable4HBreakout || !SBLoad4HRange(utc))return;
   datetime closed=iTime(_Symbol,PERIOD_M5,1);if(closed<=0 || closed<=sb_four_last || utc<sb_four_replay_retry)return;
   datetime from=sb_four_range.to,required=sb_four_last>0?sb_four_last+300:from;
   if(closed<required)return;
   MqlRates bars[];int n=CopyRates(_Symbol,PERIOD_M5,from-InpStructureLookbackBars*300,closed,bars);
   string why="";
   if(n<1 || !SBReplayCoverage(bars,required,closed,300,why))
     {
      sb_four_replay_retry=utc+30;sb_four_wait="RANGE_HISTORY_INCOMPLETE "+why;
      SBEvent(SB_4H,"SETUP_HISTORY_RETRY",sb_four_wait);return;
     }
   sb_four_wait="";
   for(int i=0;i<n;i++)
     {
      if(bars[i].time<required || bars[i].time>closed)continue;
      SB4HBar(bars,i,!startup && i==n-1 && SBFreshSessionConfirmation(bars[i].time,sb_signal_after,TimeCurrent()));
      if(sb_four_wait!=""){sb_four_replay_retry=utc+30;break;}
      if(sb_four.invalid)break;
     }
  }
#endif
