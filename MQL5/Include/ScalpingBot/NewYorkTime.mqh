#ifndef SB_NEW_YORK_TIME
#define SB_NEW_YORK_TIME
#include "BrokerTimeConfig.mqh"
datetime SBDate(int year,int month,int day,int hour=0)
  { MqlDateTime t={};t.year=year;t.mon=month;t.day=day;t.hour=hour;return StructToTime(t); }
int SBSunday(int year,int month,int occurrence)
  { MqlDateTime t;TimeToStruct(SBDate(year,month,1),t);return 1+(7-t.day_of_week)%7+(occurrence-1)*7; }
int SBLastSunday(int year,int month)
  { datetime next=month==12?SBDate(year+1,1,1):SBDate(year,month+1,1);MqlDateTime t;TimeToStruct(next-86400,t);return t.day-t.day_of_week; }
bool SBUSDST(datetime utc)
  {
   MqlDateTime t;TimeToStruct(utc,t);
   datetime start=t.year>=2007?SBDate(t.year,3,SBSunday(t.year,3,2),7):SBDate(t.year,4,SBSunday(t.year,4,1),7);
   datetime end=t.year>=2007?SBDate(t.year,11,SBSunday(t.year,11,1),6):SBDate(t.year,10,SBLastSunday(t.year,10),6);
   return utc>=start && utc<end;
  }
bool SBNYLocal(datetime utc,datetime &local)
  {
   MqlDateTime t;if(!TimeToStruct(utc,t) || t.year<1987 || t.year>2099)return false;
   local=utc+(SBUSDST(utc)?-4:-5)*3600;return true;
  }
bool SBNYDay(datetime utc,datetime &day,datetime &midnight_utc)
  {
   datetime local;if(!SBNYLocal(utc,local))return false;
   MqlDateTime t;TimeToStruct(local,t);day=SBDate(t.year,t.mon,t.day);
   datetime check;
   midnight_utc=day+5*3600;
   if(SBNYLocal(midnight_utc,check) && check==day)return true;
   midnight_utc=day+4*3600;return SBNYLocal(midnight_utc,check) && check==day;
  }
int SBBrokerOffset(datetime utc)
  {
   if(InpBrokerDSTRule==SB_UTC_TABLE)return SBTableOffset(utc);
   bool summer=false;MqlDateTime t;TimeToStruct(utc,t);
   if(InpBrokerDSTRule==SB_EU)
      summer=utc>=SBDate(t.year,3,SBLastSunday(t.year,3),1) && utc<SBDate(t.year,10,SBLastSunday(t.year,10),1);
   if(InpBrokerDSTRule==SB_US)summer=SBUSDST(utc);
   return summer?InpBrokerSummerUTCMinutes:InpBrokerWinterUTCMinutes;
  }
bool SBUTCToServerChecked(datetime utc,datetime &server,string &why)
  {
   server=0;why="";
   if(!InpBrokerTimeVerified){why="BROKER_MAPPING_NOT_VERIFIED";return false;}
   string error;if(!SBMappingConfigValid(error)){why="BROKER_MAPPING_CONFIG_INVALID:"+error;return false;}
   if(utc<InpBrokerMappingFromUTC || utc>=InpBrokerMappingUntilUTC){why="BROKER_MAPPING_OUTSIDE_UTC_COVERAGE";return false;}
   server=utc+SBBrokerOffset(utc)*60;return true;
  }
bool SBUTCToServer(datetime utc,datetime &server)
  {string why;return SBUTCToServerChecked(utc,server,why);}
bool SBServerToUTCChecked(datetime server,datetime &utc,string &why)
  {
   utc=0;why="";
   if(!InpBrokerTimeVerified){why="BROKER_MAPPING_NOT_VERIFIED";return false;}
   string error;if(!SBMappingConfigValid(error)){why="BROKER_MAPPING_CONFIG_INVALID:"+error;return false;}
   int offsets[];
   if(InpBrokerDSTRule==SB_UTC_TABLE)ArrayCopy(offsets,sb_mapping_offsets);
   else {ArrayResize(offsets,InpBrokerDSTRule==SB_FIXED?1:2);offsets[0]=InpBrokerWinterUTCMinutes;if(ArraySize(offsets)>1)offsets[1]=InpBrokerSummerUTCMinutes;}
   int matches=0,covered=0;datetime found=0;
   for(int i=0;i<ArraySize(offsets);i++)
     {
      if(i==1 && offsets[1]==offsets[0])continue;
      datetime trial=server-offsets[i]*60,back;
      if(trial>=InpBrokerMappingFromUTC && trial<InpBrokerMappingUntilUTC)covered++;
      if(SBUTCToServer(trial,back) && back==server){matches++;found=trial;}
     }
   if(matches!=1){why=matches>1?"BROKER_MAPPING_SERVER_FOLD_AMBIGUOUS":(covered>0?"BROKER_MAPPING_SERVER_GAP":"BROKER_MAPPING_OUTSIDE_UTC_COVERAGE");return false;}
   utc=found;return true;
  }
bool SBServerToUTC(datetime server,datetime &utc)
  {string why;return SBServerToUTCChecked(server,utc,why);}
string SBTradeCountText(int count,int maximum,string reason)
  {return (count<0?"UNKNOWN ("+reason+")":IntegerToString(count))+"/"+IntegerToString(maximum);}
string SBBrokerClockText(datetime server)
  {
   datetime utc=0,ny=0;string why;
   if(!SBServerToUTCChecked(server,utc,why))return why;
   if(!SBNYLocal(utc,ny))return "NY_TIME_UNSUPPORTED";
   return "server="+TimeToString(server,TIME_DATE|TIME_SECONDS)+" UTC="+TimeToString(utc,TIME_DATE|TIME_SECONDS)+
    " NY="+TimeToString(ny,TIME_DATE|TIME_SECONDS)+" broker_UTC_minutes="+IntegerToString(SBBrokerOffset(utc))+
    " NY_UTC_minutes="+IntegerToString(SBUSDST(utc)?-240:-300);
  }
#endif
