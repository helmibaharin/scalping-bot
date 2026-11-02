#ifndef SB_VP_SESSIONS
#define SB_VP_SESSIONS
#include "VolumeProfileMethods.mqh"
SBVPProfile sb_vp_profile;
datetime sb_vp_day=0,sb_vp_attempt=0;
string sb_vp_profile_wait="";
string SBVPParameters()
  {return StringFormat("OVERLAP_V1|%d|%.10f|%.10f|%.10f|%d|%d|%d|%d",(int)InpVPProfileTF,InpVPBinSize,InpVPValueFraction,InpVPMinimumCoverage,InpVPMaxBins,InpVPMinimumSessionMinutes,InpVPReferenceLookbackDays,InpVPAllowD1VerifiedPartial);}
string SBVPCachePrefix()
  {return "ScalpingBot\\VP."+(MQLInfoInteger(MQL_TESTER)?"TEST.":"")+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"."+SBId(_Symbol)+".";}
void SBVPClearTesterProfiles()
  {
   if(!MQLInfoInteger(MQL_TESTER))return;
   string found;long search=FileFindFirst(SBVPCachePrefix()+"*.profile",found);
   if(search==INVALID_HANDLE)return;
   do{FileDelete("ScalpingBot\\"+found);}while(FileFindNext(search,found));FileFindClose(search);
  }
// Weekday sessions are current broker declarations, not a historical exchange calendar.
// Include sessions beginning on the previous day and crossing midnight; union overlap.
void SBVPMarkWindow(int &minutes[],int start,int finish)
  {for(int m=MathMax(0,start);m<MathMin(1440,finish);m++)minutes[m]=1;}
int SBVPScheduledMinutes(datetime day,int &minutes[])
  {
   ArrayResize(minutes,1440);ArrayInitialize(minutes,0);
   for(int previous=0;previous<2;previous++)
     {
      MqlDateTime t;TimeToStruct(day-previous*86400,t);
      for(uint index=0;index<20;index++)
        {
         datetime a,z;if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)t.day_of_week,index,a,z))break;
         int start=(int)((long)a%86400)/60,finish=(int)((long)z%86400)/60;
         if(finish<=start)finish+=1440;
         SBVPMarkWindow(minutes,start-previous*1440,finish-previous*1440);
        }
     }
   int total=0;for(int i=0;i<1440;i++)total+=minutes[i];return total;
  }
bool SBVPDailyMatches(MqlRates &bars[],MqlRates &daily,double tick)
  {
   int n=ArraySize(bars);if(n==0)return false;long volume=0;double high=0,low=DBL_MAX;
   for(int i=0;i<n;i++){volume+=bars[i].tick_volume;high=MathMax(high,bars[i].high);low=MathMin(low,bars[i].low);}
   return volume==daily.tick_volume && MathAbs(bars[0].open-daily.open)<=tick*0.1 && MathAbs(bars[n-1].close-daily.close)<=tick*0.1 &&
    MathAbs(high-daily.high)<=tick*0.1 && MathAbs(low-daily.low)<=tick*0.1;
  }
string SBVPSerialize(SBVPProfile &p,datetime active)
  {return StringFormat("VP1;%I64d;%s;%I64d;%I64d;%I64d;%I64d;%s;%.12f;%.12f;%.12f;%.12f;%.4f;%.12f;%.12f;%.12f;%.12f;%d;%d;%d;%s",(long)active,SBId(SBVPParameters()),(long)p.day,(long)p.start,(long)p.end,(long)p.last,p.id,p.poc,p.vah,p.val,p.close,p.volume,p.coverage,p.center,p.bin,p.fraction,p.count,p.expected,p.ties,p.quality);}
bool SBVPReadFrozen(string file,datetime active,SBVPProfile &p)
  {
   int h=FileOpen(file,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);if(h==INVALID_HANDLE)return false;
   string payload=FileReadString(h),checksum=FileReadString(h);FileClose(h);
   if(checksum!=SBId(payload))return false;string f[];if(StringSplit(payload,';',f)!=21 || f[0]!="VP1" || StringToInteger(f[1])!=(long)active || f[2]!=SBId(SBVPParameters()))return false;
   ZeroMemory(p);p.day=(datetime)StringToInteger(f[3]);p.start=(datetime)StringToInteger(f[4]);p.end=(datetime)StringToInteger(f[5]);p.last=(datetime)StringToInteger(f[6]);p.id=f[7];
   p.poc=StringToDouble(f[8]);p.vah=StringToDouble(f[9]);p.val=StringToDouble(f[10]);p.close=StringToDouble(f[11]);p.volume=StringToDouble(f[12]);p.coverage=StringToDouble(f[13]);
   p.center=StringToDouble(f[14]);p.bin=StringToDouble(f[15]);p.fraction=StringToDouble(f[16]);p.count=(int)StringToInteger(f[17]);p.expected=(int)StringToInteger(f[18]);p.ties=(int)StringToInteger(f[19]);p.quality=f[20];
   p.valid=p.start==p.day && active-p.day<=InpVPReferenceLookbackDays*86400 && p.end==p.day+86400 && p.end<=active && p.last>=p.start && p.last+60<=p.end &&
    p.volume>0 && p.count>=InpVPMinimumSessionMinutes && p.val>0 && MathIsValidNumber(p.poc) && p.val<=p.poc && p.poc<=p.vah && p.val<p.vah &&
    MathAbs(p.bin-InpVPBinSize)<1e-10 && MathAbs(p.fraction-InpVPValueFraction)<1e-10;
   p.reason=p.valid?"VALIDATED_FROZEN_CACHE":"INVALID_FROZEN_CACHE";return p.valid;
  }
bool SBVPWriteFrozen(string file,datetime active,SBVPProfile &p)
  {
   string temporary=file+".tmp",payload=SBVPSerialize(p,active);
   int h=FileOpen(temporary,FILE_WRITE|FILE_TXT|FILE_ANSI);if(h==INVALID_HANDLE)return false;
   ResetLastError();bool ok=FileWrite(h,payload)>0 && FileWrite(h,SBId(payload))>0;FileFlush(h);if(GetLastError()!=0)ok=false;FileClose(h);
   if(!ok)return false;return FileMove(temporary,0,file,FILE_REWRITE);
  }
bool SBVPBuildReference(datetime active,SBVPProfile &p,string &why)
  {
   MqlRates daily[];int nd=CopyRates(_Symbol,PERIOD_D1,active-1,InpVPReferenceLookbackDays,daily);
   if(nd<1){why="D1_REFERENCE_HISTORY_UNAVAILABLE";return false;}
   int selected=-1;
   for(int i=nd-1;i>=0;i--)if(SBVPBrokerDay(daily[i].time)<active && daily[i].tick_volume>0){selected=i;break;}
   if(selected<0){why="NO_PREVIOUS_COMPLETED_TRADING_DAY";return false;}
   datetime day=SBVPBrokerDay(daily[selected].time);MqlRates m1[];
   if(active-day>InpVPReferenceLookbackDays*86400){why="D1_REFERENCE_TOO_OLD_WAIT_CURRENT_HISTORY";return false;}
   int n=CopyRates(_Symbol,PERIOD_M1,day,day+86400-1,m1);
   if(n<InpVPMinimumSessionMinutes){why="REFERENCE_M1_HISTORY_MISSING_OR_TOO_SHORT";return false;}
   int mask[];int scheduled=SBVPScheduledMinutes(day,mask),outside=0;
   for(int i=0;i<n;i++){int minute=(int)((m1[i].time-day)/60);if(minute<0 || minute>=1440 || mask[minute]==0)outside++;}
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   bool matches=SBVPDailyMatches(m1,daily[selected],tick);
   // Missing M1 data must not be mistaken for a holiday or silently fall back an extra day.
   if(!matches){why="M1_D1_VOLUME_OR_OHLC_MISMATCH_WAIT_HISTORY";return false;}
   bool exception=scheduled==0 || outside>0 || (double)n/MathMax(1,scheduled)<InpVPMinimumCoverage;
   if(exception && !InpVPAllowD1VerifiedPartial){why="PARTIAL_OR_HISTORICAL_SESSION_EXCEPTION_DISABLED";return false;}
   if(!SBVPBuild(m1,day,day+86400,active,exception?n:scheduled,InpVPMinimumCoverage,InpVPBinSize,InpVPValueFraction,tick,InpVPMaxBins,p))
     {why=p.reason;return false;}
   p.expected=scheduled;p.coverage=scheduled>0?(double)n/scheduled:0;
   if(exception)p.quality="D1_VERIFIED_SESSION_EXCEPTION";
   p.id=SBId(_Symbol+"|"+IntegerToString((long)day)+"|"+SBVPParameters()+"|"+DoubleToString(p.volume,0)+"|"+DoubleToString(p.poc,10)+"|"+DoubleToString(p.val,10)+"|"+DoubleToString(p.vah,10));
   why=p.reason;return true;
  }
bool SBVPEnsureProfile(datetime decision)
  {
   datetime active=SBVPBrokerDay(decision);
   if(sb_vp_day==active && sb_vp_profile.valid)return true;
   if(sb_vp_day==active && sb_vp_attempt>0 && decision-sb_vp_attempt<InpVPProfileRetrySeconds)return false;
   sb_vp_day=active;sb_vp_attempt=decision;sb_vp_profile.valid=false;
   string file=SBVPCachePrefix()+IntegerToString((long)active)+".profile",why="";
   bool cached=FileIsExist(file),ok=false;
   if(cached){ok=SBVPReadFrozen(file,active,sb_vp_profile);why=ok?"VALIDATED_FROZEN_CACHE":"FROZEN_CACHE_OR_PARAMETERS_INVALID_MANUAL_REVIEW";}
   else
     {
      ok=SBVPBuildReference(active,sb_vp_profile,why);
      if(ok && !SBVPWriteFrozen(file,active,sb_vp_profile)){ok=false;why="FROZEN_PROFILE_PERSISTENCE_FAILED";}
     }
   if(!ok)sb_vp_profile.valid=false;
   if(ok || why!=sb_vp_profile_wait)
     {
      SBEvent(SB_VP_POC,ok?"VP_PROFILE_FROZEN":"VP_PROFILE_WAIT",StringFormat("active=%I64d reference=%I64d start=%I64d end=%I64d profile=%s status=%s reason=%s POC=%.10f VAH=%.10f VAL=%.10f close=%.10f M1=%d scheduled=%d coverage=%.6f volume=%.0f ties=%d",
        (long)active,(long)sb_vp_profile.day,(long)sb_vp_profile.start,(long)sb_vp_profile.end,sb_vp_profile.id,sb_vp_profile.quality,why,sb_vp_profile.poc,sb_vp_profile.vah,sb_vp_profile.val,sb_vp_profile.close,sb_vp_profile.count,sb_vp_profile.expected,sb_vp_profile.coverage,sb_vp_profile.volume,sb_vp_profile.ties));
      sb_vp_profile_wait=why;
     }
   return ok;
  }
#endif
