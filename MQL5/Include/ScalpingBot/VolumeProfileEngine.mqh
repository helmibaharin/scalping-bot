#ifndef SB_VOLUME_PROFILE_ENGINE
#define SB_VOLUME_PROFILE_ENGINE
struct SBVPProfile
  {
   datetime day,start,end,last;string id,quality,reason;
   double poc,vah,val,close,volume,coverage,center,bin,fraction;
   int count,expected,ties;bool valid;
  };
long SBVPBin(double price,double bin)
  {return (long)MathFloor(price/bin+1e-9);}
bool SBVPBinCompatible(double bin,double tick)
  {return bin>0 && tick>0 && MathAbs(bin/tick-MathRound(bin/tick))<1e-7;}
// Histogram intervals are [index*bin,(index+1)*bin). Positive-range bars allocate
// by overlap length; an exact high edge contributes zero to the following bin.
bool SBVPBuild(MqlRates &bars[],datetime start,datetime end,datetime decision,int expected,double minimum_coverage,
               double bin,double fraction,double tick,int max_bins,SBVPProfile &p)
  {
   ZeroMemory(p);p.start=start;p.end=end;p.day=start;p.bin=bin;p.fraction=fraction;p.expected=expected;p.count=ArraySize(bars);
   if(start>=end || end>decision || expected<1 || !SBVPBinCompatible(bin,tick) || fraction<=0 || fraction>1 || max_bins<1)
     {p.reason="INVALID_SESSION_OR_PARAMETERS";return false;}
   int n=ArraySize(bars);if(n<1){p.reason="M1_HISTORY_MISSING";return false;}
   double low=DBL_MAX,high=0,total=0;
   for(int i=0;i<n;i++)
     {
      MqlRates b=bars[i];
      if(b.time<start || b.time+60>end || b.time+60>decision || (i>0 && b.time<=bars[i-1].time) || (long)b.time%60!=0)
        {p.reason="M1_TIMESTAMP_ORDER_DUPLICATE_OR_FUTURE";return false;}
      if(!MathIsValidNumber(b.open) || !MathIsValidNumber(b.high) || !MathIsValidNumber(b.low) || !MathIsValidNumber(b.close) ||
         b.low<=0 || b.high<b.low || b.open<b.low || b.open>b.high || b.close<b.low || b.close>b.high || b.tick_volume<0)
        {p.reason="INVALID_M1_OHLC_OR_VOLUME";return false;}
      low=MathMin(low,b.low);high=MathMax(high,b.high);total+=(double)b.tick_volume;
     }
   p.coverage=(double)n/expected;
   if(n>expected || p.coverage<minimum_coverage){p.reason="M1_SESSION_COVERAGE_INSUFFICIENT";return false;}
   if(total<=0){p.reason="ZERO_TICK_VOLUME";return false;}
   long first=SBVPBin(low,bin),last=SBVPBin(high,bin);
   if(last-first+1>max_bins || last<first){p.reason="PROFILE_BIN_CAPACITY";return false;}
   int size=(int)(last-first+1);double histogram[];ArrayResize(histogram,size);ArrayInitialize(histogram,0);
   for(int i=0;i<n;i++)
     {
      MqlRates b=bars[i];long a=SBVPBin(b.low,bin),z=SBVPBin(b.high,bin);
      if(b.high==b.low){histogram[(int)(a-first)]+=(double)b.tick_volume;continue;}
      for(long k=a;k<=z;k++)
        {
         double overlap=MathMax(0,MathMin(b.high,(k+1)*bin)-MathMax(b.low,k*bin));
         histogram[(int)(k-first)]+=(double)b.tick_volume*overlap/(b.high-b.low);
        }
     }
   double allocated=0,weighted=0,maximum=0;
   for(int i=0;i<size;i++){allocated+=histogram[i];weighted+=histogram[i]*(first+i+0.5)*bin;maximum=MathMax(maximum,histogram[i]);}
   if(!MathIsValidNumber(allocated) || MathAbs(allocated-total)>MathMax(1e-6,total*1e-8)){p.reason="VOLUME_CONSERVATION_FAILED";return false;}
   p.volume=allocated;p.center=weighted/allocated;
   double epsilon=MathMax(1e-10,allocated*1e-12),nearest=DBL_MAX;int poc=-1;
   for(int i=0;i<size;i++)if(MathAbs(histogram[i]-maximum)<=epsilon)
     {
      double distance=MathAbs((first+i+0.5)*bin-p.center);p.ties++;
      if(poc<0 || distance<nearest-bin*1e-10){poc=i;nearest=distance;}
     }
   int left=poc,right=poc;double included=histogram[poc];
   while(included+epsilon<allocated*fraction && (left>0 || right<size-1))
     {
      bool take_lower=right==size-1;
      if(left==0)take_lower=false;
      else if(right<size-1)
        {
         double l=histogram[left-1],r=histogram[right+1];
         if(MathAbs(l-r)<=epsilon)
           take_lower=MathAbs((first+left-0.5)*bin-p.center)<=MathAbs((first+right+1.5)*bin-p.center)+bin*1e-10;
         else take_lower=l>r;
        }
      if(take_lower)included+=histogram[--left];else included+=histogram[++right];
     }
   p.poc=(first+poc+0.5)*bin;p.val=(first+left)*bin;p.vah=(first+right+1)*bin;
   p.close=bars[n-1].close;p.last=bars[n-1].time;
   p.valid=MathIsValidNumber(p.poc) && p.val<=p.poc && p.poc<=p.vah && p.val<p.vah;
   p.quality=n==expected?"COMPLETE_SCHEDULE":"PARTIAL_WITHIN_COVERAGE";p.reason=p.valid?"FROZEN_PREVIOUS_BROKER_DAY":"INVALID_LEVELS";
   return p.valid;
  }
int SBVPCloseLocation(SBVPProfile &p)
  {return p.close>p.vah?1:(p.close<p.val?-1:0);}
#endif
