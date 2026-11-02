#ifndef SB_SESSION_RANGE
#define SB_SESSION_RANGE
// Exact NY wall-clock windows, M1 only. No broker-aligned higher-TF fallback.
struct SBSessionRange
  {
   datetime day,start_utc,end_utc,from,to,cutoff,next_attempt;
   int expected,actual,valid;
   double high,low;
   bool ready;
   string state,reason;
  };
bool SBNYToUTC(datetime local,datetime &utc)
  {
   int matches=0;datetime back;utc=0;
   for(int hours=4;hours<=5;hours++)
      if(SBNYLocal(local+hours*3600,back) && back==local){utc=local+hours*3600;matches++;}
   return matches==1;
  }
bool SBRangeWindow(datetime day,int start_minutes,int end_minutes,SBSessionRange &r)
  {
   r.day=day;r.ready=false;r.reason="";
   MqlDateTime t;TimeToStruct(day,t);
   if(t.day_of_week==0 || t.day_of_week==6){r.state="DAY_INVALID";r.reason="NY_WEEKEND";return false;}
   if(!SBNYToUTC(day+start_minutes*60,r.start_utc) || !SBNYToUTC(day+end_minutes*60,r.end_utc) || r.end_utc<=r.start_utc)
     {r.state="TIMEZONE_MAPPING_UNVERIFIED";r.reason="NY_SESSION_BOUNDARY_AMBIGUOUS_OR_UNSUPPORTED";return false;}
   return true;
  }
bool SBRangeOHLC(MqlRates &b)
  {
   return MathIsValidNumber(b.open) && MathIsValidNumber(b.high) && MathIsValidNumber(b.low) && MathIsValidNumber(b.close) &&
    b.low>0 && b.high>=b.low && b.open>=b.low && b.open<=b.high && b.close>=b.low && b.close<=b.high;
  }
// Also used by the native deterministic fixture. Values are usable only when true.
bool SBValidateRangeBars(MqlRates &bars[],datetime decision,SBSessionRange &r)
  {
   r.actual=ArraySize(bars);r.valid=0;r.high=0;r.low=0;r.ready=false;
   double high=-DBL_MAX,low=DBL_MAX;
   for(int i=0;i<r.actual;i++)
     {
      datetime utc=0;string why;
      if(!SBServerToUTCChecked(bars[i].time,utc,why))
        {r.state="TIMEZONE_MAPPING_UNVERIFIED";r.reason=why;return false;}
      string invalid="";
      if(utc<r.start_utc || utc>=r.end_utc)invalid="M1_OUTSIDE_SESSION";
      else if(i>0 && bars[i].time<=bars[i-1].time)invalid="M1_DUPLICATE_OR_REVERSED_TIMESTAMP";
      else if(utc!=r.start_utc+i*60)invalid="M1_TIMESTAMP_GAP";
      else if(utc+60>r.cutoff || utc+60>decision)invalid="M1_FUTURE_OR_FORMING_CANDLE";
      else if(!SBRangeOHLC(bars[i]))invalid="M1_INVALID_OHLC";
      if(invalid!="")
        {r.state="RANGE_HISTORY_INCOMPLETE";r.reason=invalid+" index="+IntegerToString(i)+" UTC="+TimeToString(utc,TIME_DATE|TIME_SECONDS);return false;}
      r.valid++;high=MathMax(high,bars[i].high);low=MathMin(low,bars[i].low);
     }
   if(r.actual!=r.expected)
     {r.state="RANGE_HISTORY_INCOMPLETE";r.reason="M1_COVERAGE_INCOMPLETE missing="+IntegerToString(r.expected-r.actual)+" NO_HISTORICAL_CLOSURE_ASSUMED";return false;}
   if(r.actual>0){r.high=high;r.low=low;}
   if(decision<r.end_utc){r.state="RANGE_FORMING";r.reason="COMPLETED_M1_PARTIAL_RANGE";return true;}
   if(high<=low || low<=0){r.state="RANGE_HISTORY_INCOMPLETE";r.reason="DEGENERATE_RANGE";return false;}
   r.ready=true;r.state="RANGE_READY";r.reason="VALIDATED_EXACT_M1_HISTORY";return true;
  }
bool SBRangeMapping(SBSessionRange &r)
  {
   string why;datetime previous=0;
   // Validate every minute and round-trip: do not accept folded broker labels.
   for(datetime u=r.start_utc;u<=r.end_utc;u+=60)
     {
      datetime server=0,back=0;
      if(!SBUTCToServerChecked(u,server,why) || !SBServerToUTCChecked(server,back,why) || back!=u)
        {r.state="TIMEZONE_MAPPING_UNVERIFIED";r.reason=why==""?"BROKER_MAPPING_ROUNDTRIP_FAILED":why;return false;}
      if(previous>0 && server-previous!=60)
        {r.state="TIMEZONE_MAPPING_UNVERIFIED";r.reason="BROKER_MAPPING_DISCONTINUOUS_SESSION";return false;}
      if(u==r.start_utc)r.from=server;
      if(u==r.end_utc)r.to=server;
      previous=server;
     }
   return true;
  }
void SBRangeLog(int strategy,datetime decision,SBSessionRange &r)
  {
   datetime ny=0,server=TimeCurrent();SBNYLocal(decision,ny);
   string why,start_offset="UNAVAILABLE",end_offset="UNAVAILABLE";datetime mapped;
   if(r.start_utc>0 && SBUTCToServerChecked(r.start_utc,mapped,why))start_offset=IntegerToString(SBBrokerOffset(r.start_utc));
   if(r.end_utc>0 && SBUTCToServerChecked(r.end_utc,mapped,why))end_offset=IntegerToString(SBBrokerOffset(r.end_utc));
   SBEvent(strategy,r.ready?"RANGE_RECOVERED":r.state,StringFormat(
    "broker=%s UTC=%s NY=%s nyDate=%s nyWindow=[%s,%s) brokerWindow=[%s,%s) offsets_minutes=%s/%s verified=%s M1=%d/%d actual=%d high=%.8f low=%.8f status=%s reason=%s retry=%s",
    TimeToString(server,TIME_DATE|TIME_SECONDS),TimeToString(decision,TIME_DATE|TIME_SECONDS),TimeToString(ny,TIME_DATE|TIME_SECONDS),TimeToString(r.day,TIME_DATE),
    TimeToString(r.day+(strategy==SB_4H?0:570*60)),TimeToString(r.day+(strategy==SB_4H?240:570+InpORBOpeningRangeMinutes)*60),
    TimeToString(r.from),TimeToString(r.to),start_offset,end_offset,InpBrokerTimeVerified?"true":"false",
    r.valid,r.expected,r.actual,r.high,r.low,r.state,r.reason,(!r.ready && r.state!="DAY_INVALID")?"true":"false"));
  }
bool SBRecoverSessionRange(int strategy,datetime utc,int start_minutes,int end_minutes,SBSessionRange &r)
  {
   datetime day,midnight;if(!SBNYDay(utc,day,midnight))return false;
   if(r.day!=day){ZeroMemory(r);r.day=day;}
   if(r.ready)return true;
   if(utc<r.next_attempt)return false;
   r.next_attempt=utc+30;r.expected=0;r.actual=0;r.valid=0;r.high=0;r.low=0;
   if(!SBRangeWindow(day,start_minutes,end_minutes,r) || !SBRangeMapping(r))
     {if(r.state=="DAY_INVALID")r.next_attempt=utc+3600;SBRangeLog(strategy,utc,r);return false;}
   if(utc<r.start_utc){r.state="WAITING_FOR_SESSION";r.reason="NY_SESSION_NOT_STARTED";r.next_attempt=r.start_utc;SBRangeLog(strategy,utc,r);return false;}
   r.cutoff=(datetime)((long)MathMin((double)utc,(double)r.end_utc)/60*60);
   r.expected=(int)((r.cutoff-r.start_utc)/60);
   r.state="RANGE_RECOVERING";
   MqlRates bars[];datetime stop;
   string why;
   if(r.expected==0){r.state="RANGE_FORMING";r.reason="NO_COMPLETED_M1_YET";SBRangeLog(strategy,utc,r);return false;}
   if(!SBUTCToServerChecked(r.cutoff,stop,why)){r.state="TIMEZONE_MAPPING_UNVERIFIED";r.reason=why;SBRangeLog(strategy,utc,r);return false;}
   ResetLastError();int n=CopyRates(_Symbol,PERIOD_M1,r.from,stop-1,bars);int error=GetLastError();
   if(n<0){r.state="RANGE_HISTORY_INCOMPLETE";r.reason="M1_HISTORY_PENDING_ERROR_"+IntegerToString(error);}
   else SBValidateRangeBars(bars,utc,r);
   if(r.state=="RANGE_FORMING")r.next_attempt=r.cutoff+60;
   SBRangeLog(strategy,utc,r);return r.ready;
  }
// Preflight the entire replay batch before mutating setup state. Missing data retries.
bool SBReplayCoverage(MqlRates &bars[],datetime from,datetime closed,int seconds,string &why)
  {
   datetime expected=from;int n=ArraySize(bars);
   for(int i=0;i<n;i++)
     {
      if(bars[i].time<from)continue;
      if(bars[i].time>closed)break;
      if(bars[i].time!=expected || !SBRangeOHLC(bars[i])){why="M5_GAP_DUPLICATE_OR_INVALID_OHLC";return false;}
      expected+=seconds;
     }
   if(expected!=closed+seconds){why="M5_FIRST_OR_LAST_CANDLE_MISSING";return false;}
   return true;
  }
bool SBFreshSessionConfirmation(datetime candle,datetime initialized,datetime now)
  {return candle+300>initialized && candle+300<=now;}
#endif
