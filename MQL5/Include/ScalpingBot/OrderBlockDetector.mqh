#ifndef SB_ORDER_BLOCK
#define SB_ORDER_BLOCK
bool SBBullishOrderBlock(MqlRates &bars[],int end,double entry,double &stop,datetime &origin,double &zone_low,double &zone_high)
  {
   int count=InpOrderBlockDisplacementBars,start=MathMax(0,end-InpStructureLookbackBars+1);
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   // Most recent bearish candle immediately followed by a completed bullish displacement.
   for(int i=end-count;i>=start;i--)
     {
      if(bars[i].close>=bars[i].open)continue;
      double low=InpOrderBlockUseWicks?bars[i].low:bars[i].close,high=InpOrderBlockUseWicks?bars[i].high:bars[i].open;
      double base_range=MathMax(tick,bars[i].high-bars[i].low);
      int confirmation=-1;
      for(int j=i+1;j<=i+count;j++)if(bars[j].close>bars[j].open && bars[j].close>bars[i].high && bars[j].close-bars[i].open>=base_range*InpOrderBlockDisplacementFactor)
        {confirmation=j;break;}
      if(confirmation<0 || high>=entry)continue;
      bool invalid=false;
      // A wick through the lower boundary invalidates the zone, including during displacement.
      for(int j=i+1;j<=end;j++)if(bars[j].low<low-tick*0.1)invalid=true;
      if(invalid)continue;
      double candidate=low-Inp4HStopBufferPoints*_Point;
      if(candidate<=0 || candidate>=entry || (entry-candidate)/_Point>Inp4HMaxStopPoints)continue;
      stop=candidate;origin=bars[i].time;zone_low=low;zone_high=high;return true;
     }
   return false;
  }
#endif
