#ifndef SB_FOUR_HOUR
#define SB_FOUR_HOUR
SB4HState sb_four;
datetime sb_four_last=0;
bool SBLoad4HRange(datetime utc)
  {
   datetime day,midnight;if(!SBNYDay(utc,day,midnight))return false;
   if(sb_four.day!=day)
     {
      if(sb_four.side!=0)SBEvent(SB_4H,"DAY_EXPIRED","Pending breakout expired at NY midnight; open positions retained");
      ZeroMemory(sb_four);sb_four.day=day;sb_four_last=0;
      SBEvent(SB_4H,"NY_DAY_RESET",TimeToString(day,TIME_DATE));
     }
   if(sb_four.ready || sb_four.invalid)return sb_four.ready;
   datetime local_end;if(!SBNYLocal(midnight+4*3600,local_end) || local_end!=day+4*3600)
     {sb_four.invalid=true;SBEvent(SB_4H,"RANGE_SKIP_DST_DAY","00-04 local does not contain exactly four H1 hours");return false;}
   if(utc<midnight+4*3600)return false;
   double high=-DBL_MAX,low=DBL_MAX;
   for(int i=0;i<4;i++)
     {
      datetime start,end;if(!SBUTCToServer(midnight+i*3600,start) || !SBUTCToServer(midnight+(i+1)*3600,end) || end-start!=3600)
        {sb_four.invalid=true;SBEvent(SB_4H,"RANGE_SKIP_MAPPING","Broker H1 interval is ambiguous/discontinuous");return false;}
      MqlRates bar[];if(CopyRates(_Symbol,PERIOD_H1,start,start,bar)!=1 || bar[0].time!=start)return false;
      if(start+3600>TimeCurrent())return false;
      high=MathMax(high,bar[0].high);low=MathMin(low,bar[0].low);
     }
   if(high<=low || low<=0)return false;
   sb_four.high=high;sb_four.low=low;sb_four.ready=true;
   string id=TimeToString(day,TIME_DATE);
   SBHLine(SB_4H,id+".rangeHigh",high,clrOrange);SBHLine(SB_4H,id+".rangeLow",low,clrOrange);
   datetime from,to;SBUTCToServer(midnight,from);SBUTCToServer(midnight+4*3600,to);
   SBZone(SB_4H,id+".range",from,to,high,low,clrOrange);
   SBEvent(SB_4H,"RANGE_READY",StringFormat("NYday=%s high=%.8f low=%.8f",id,high,low));return true;
  }
void SB4HBar(MqlRates &bars[],int end,bool actionable)
  {
   MqlRates b=bars[end];datetime utc,day,midnight;
   if(!SBServerToUTC(b.time,utc) || !SBNYDay(utc,day,midnight) || day!=sb_four.day || utc<midnight+4*3600)return;
   if(sb_four.invalid)return;
   if(sb_four_last>0 && b.time-sb_four_last!=300)
     {sb_four.invalid=true;SBEvent(SB_4H,"M5_HISTORY_GAP","Cannot reconstruct excursion safely; skip remainder of NY day");return;}
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
   datetime day,midnight;SBNYDay(utc,day,midnight);
   datetime from;if(!SBUTCToServer(midnight+4*3600,from))return;
   datetime closed=iTime(_Symbol,PERIOD_M5,1);if(closed<=0 || (!startup && closed<=sb_four_last))return;
   // Include structural lookback preceding the range; process only post-range bars.
   MqlRates bars[];int n=CopyRates(_Symbol,PERIOD_M5,from-InpStructureLookbackBars*300,closed,bars);
   if(n<1)return;
   bool first_replay=sb_four_last==0;
   for(int i=0;i<n;i++)
     {
      if(bars[i].time<from || bars[i].time<=sb_four_last || bars[i].time>closed)continue;
      if(first_replay && bars[i].time!=from){sb_four.invalid=true;SBEvent(SB_4H,"HISTORY_MISSING","Missing first post-range M5 candle");return;}
      first_replay=false;
      // Restart replay never submits an order, even on the newest historical close.
      SB4HBar(bars,i,!startup && i==n-1);
     }
  }
#endif
