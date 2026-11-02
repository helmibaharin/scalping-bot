#ifndef SB_RESISTANCE
#define SB_RESISTANCE
bool SBPivotHigh(MqlRates &bars[],int index,int left,int right,int end)
  {
   if(index<left || index+right>end)return false;
   for(int j=index-left;j<=index+right;j++)if(j!=index && bars[j].high>=bars[index].high)return false;
   return true;
  }
bool SBPivotLow(MqlRates &bars[],int index,int left,int right,int end)
  {
   if(index<left || index+right>end)return false;
   for(int j=index-left;j<=index+right;j++)if(j!=index && bars[j].low<=bars[index].low)return false;
   return true;
  }
bool SBResistance(MqlRates &bars[],int end,double entry,double &stop,datetime &origin,double &zone_low,double &zone_high)
  {
   int start=MathMax(InpStructurePivotStrength,end-InpStructureLookbackBars+1),strength=InpStructurePivotStrength;
   double tolerance=InpResistanceTolerancePoints*_Point,buffer=Inp4HStopBufferPoints*_Point;
   // Deterministic rank: most recent qualifying confirmed pivot, then its prior touches.
   for(int i=end-strength;i>=start;i--)
     {
      if(!SBPivotHigh(bars,i,strength,strength,end) || bars[i].high<=entry)continue;
      int touches=0,last=-100000;double top=bars[i].high;
      for(int j=start;j<=i;j++)if(SBPivotHigh(bars,j,strength,strength,end) && MathAbs(bars[j].high-bars[i].high)<=tolerance && j-last>=strength+1)
        {touches++;last=j;top=MathMax(top,bars[j].high);}
      if(touches<InpResistanceMinTouches)continue;
      bool broken=false;for(int j=i+1;j<=end;j++)if(bars[j].close>top+tolerance)broken=true;
      if(broken)continue;
      double candidate=top+buffer;
      if(candidate<=entry || (candidate-entry)/_Point>Inp4HMaxStopPoints)continue;
      stop=candidate;origin=bars[i].time;zone_low=bars[i].high-tolerance;zone_high=top+tolerance;return true;
     }
   return false;
  }
#endif
