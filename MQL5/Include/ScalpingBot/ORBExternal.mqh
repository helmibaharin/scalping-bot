#ifndef SB_ORB_EXTERNAL
#define SB_ORB_EXTERNAL
#include "ORBEngine.mqh"
SBORBLevel sb_orb_levels[];
int sb_orb_h1=0,sb_orb_h4=0;
bool sb_orb_context_ok=false;
datetime sb_orb_context_day=0,sb_orb_htf_checked=0;
// Local wall-clock conversion is accepted only if it round-trips uniquely.
bool SBORBNYToUTC(datetime local,datetime &utc)
  {
   datetime a=local+4*3600,b=local+5*3600,back;int count=0;
   if(SBNYLocal(a,back) && back==local){utc=a;count++;}
   if(SBNYLocal(b,back) && back==local){utc=b;count++;}
   return count==1;
  }
bool SBORBSessionUTC(datetime day,datetime &start,datetime &finish)
  {
   return SBORBNYToUTC(day+570*60,start) && SBORBNYToUTC(day+(570+InpORBOpeningRangeMinutes)*60,finish) &&
          finish-start==InpORBOpeningRangeMinutes*60;
  }
bool SBORBValidOHLC(MqlRates &b)
  {return b.low>0 && b.high>=b.low && b.open>=b.low && b.open<=b.high && b.close>=b.low && b.close<=b.high && MathIsValidNumber(b.high);}
bool SBORBExactRange(MqlRates &bars[],datetime start,datetime finish,int seconds,double &high,double &low)
  {
   int n=ArraySize(bars);if(n<=0 || finish<=start || finish-start!=n*seconds)return false;
   high=-DBL_MAX;low=DBL_MAX;
   for(int i=0;i<n;i++)
     {
      if(bars[i].time!=start+i*seconds || !SBORBValidOHLC(bars[i]))return false;
      high=MathMax(high,bars[i].high);low=MathMin(low,bars[i].low);
     }
   return high>low;
  }
bool SBORBLoadRange(datetime start_utc,datetime finish_utc,datetime decision,double &high,double &low,string &why)
  {
   datetime start,finish;
   if(decision<finish_utc){why="ORB_WAIT_RANGE";return false;}
   if(!SBUTCToServer(start_utc,start) || !SBUTCToServer(finish_utc,finish) || finish-start!=finish_utc-start_utc)
     {why="ORB_RANGE_MAPPING_INCONSISTENT";return false;}
   MqlRates bars[];
   if(InpORBOpeningRangeMinutes==15 && CopyRates(_Symbol,PERIOD_M15,start,finish-1,bars)==1 &&
      SBORBExactRange(bars,start,finish,900,high,low))return true;
   int n=CopyRates(_Symbol,PERIOD_M1,start,finish-1,bars);
   if(n<0){why="ORB_RANGE_HISTORY_PENDING";return false;}
   if(!SBORBExactRange(bars,start,finish,60,high,low)){why="ORB_RANGE_MISSING_OR_INCONSISTENT";return false;}
   return true;
  }
void SBORBAddLevel(string type,string source,double price,int side,datetime known)
  {
   if(price<=0)return;
   for(int i=0;i<ArraySize(sb_orb_levels);i++)
      if(sb_orb_levels[i].type==type && sb_orb_levels[i].source==source)
        {
         if(sb_orb_levels[i].price==price && sb_orb_levels[i].known==known)return;
         SBORBLevel fresh={};fresh.type=type;fresh.source=source;fresh.price=price;fresh.side=side;fresh.known=known;
         sb_orb_levels[i]=fresh;return;
        }
   int n=ArraySize(sb_orb_levels);ArrayResize(sb_orb_levels,n+1);
   SBORBLevel level={};level.type=type;level.source=source;level.price=price;level.side=side;level.known=known;sb_orb_levels[n]=level;
  }
// External calendar windows use complete M1 records inside exact boundaries.
// Coverage threshold permits documented exchange closures; never extrapolate a missing extreme.
bool SBORBPeriodLevels(string name,datetime from_utc,datetime to_utc,datetime decision,int expected_minutes)
  {
   datetime from,to,known;if(to_utc>decision || !SBUTCToServer(from_utc,from) || !SBUTCToServer(to_utc,to))return false;
   if(!SBUTCToServer(to_utc,known))return false;
   MqlRates bars[];int n=CopyRates(_Symbol,PERIOD_M1,from,to-1,bars);
   if(n<1 || n<expected_minutes*InpORBMinimumPeriodCoverage)return false;
   double high=-DBL_MAX,low=DBL_MAX;datetime previous=0;
   for(int i=0;i<n;i++)
     {
      datetime utc;
      if(!SBServerToUTC(bars[i].time,utc) || utc<from_utc || utc+60>to_utc ||
         (previous>0 && bars[i].time<=previous) || !SBORBValidOHLC(bars[i]))return false;
      previous=bars[i].time;high=MathMax(high,bars[i].high);low=MathMin(low,bars[i].low);
     }
   SBORBAddLevel(name+"H","M1_CALENDAR",high,1,known);SBORBAddLevel(name+"L","M1_CALENDAR",low,-1,known);return true;
  }
bool SBORBCalendarUTC(datetime day,datetime &utc)
  {if(InpORBExternalCalendarNY)return SBORBNYToUTC(day,utc);utc=day;return true;}
bool SBORBPreviousPeriods(datetime utc,datetime nyday,datetime &pdfrom,datetime &pdto,datetime &pwfrom,datetime &pwto)
  {
   datetime calendar_day=nyday;
   if(!InpORBExternalCalendarNY)
     {MqlDateTime t;TimeToStruct(utc,t);calendar_day=SBDate(t.year,t.mon,t.day);}
   datetime previous=calendar_day-86400;MqlDateTime t;TimeToStruct(previous,t);
   while(t.day_of_week==0 || t.day_of_week==6){previous-=86400;TimeToStruct(previous,t);}
   TimeToStruct(calendar_day,t);datetime monday=calendar_day-((t.day_of_week+6)%7)*86400;
   return SBORBCalendarUTC(previous,pdfrom) && SBORBCalendarUTC(previous+86400,pdto) &&
          SBORBCalendarUTC(monday-7*86400,pwfrom) && SBORBCalendarUTC(monday,pwto) && pdto<=utc && pwto<=utc;
  }
bool SBORBLoadCalendar(datetime utc,datetime nyday)
  {
   datetime pdfrom,pdto,pwfrom,pwto;
   if(!SBORBPreviousPeriods(utc,nyday,pdfrom,pdto,pwfrom,pwto) || !SBORBPeriodLevels("PD",pdfrom,pdto,utc,1440))return false;
   if(InpORBUsePreviousWeek && !SBORBPeriodLevels("PW",pwfrom,pwto,utc,5*1440))return false;
   MqlDateTime d;TimeToStruct(utc,d);datetime utcday=SBDate(d.year,d.mon,d.day);
   if(InpORBUseAsianSession && !SBORBPeriodLevels("ASIA",utcday+InpORBAsianStartUTCMinutes*60,
      utcday+InpORBAsianEndUTCMinutes*60,utc,InpORBAsianEndUTCMinutes-InpORBAsianStartUTCMinutes))return false;
   if(InpORBUseLondonSession && !SBORBPeriodLevels("LONDON",utcday+InpORBLondonStartUTCMinutes*60,
      utcday+InpORBLondonEndUTCMinutes*60,utc,InpORBLondonEndUTCMinutes-InpORBLondonStartUTCMinutes))return false;
   return true;
  }
bool SBORBHTF(ENUM_TIMEFRAMES tf,datetime decision,int &trend)
  {
   MqlRates bars[];int seconds=PeriodSeconds(tf);
   int n=CopyRates(_Symbol,tf,decision-1,InpORBHTFLookbackBars,bars);
   if(n<InpORBPivotLeft+InpORBPivotRight+5)return false;
   SBORBStructure structure={};SBORBBreak event={};
   for(int i=0;i<n;i++)
     {
      if(bars[i].time+seconds>decision)break;
      SBORBStructureStep(structure,bars,i,InpORBPivotLeft,InpORBPivotRight,seconds,InpORBBOSClearancePoints*_Point,event);
     }
   trend=structure.trend;string source=tf==PERIOD_H1?"H1":"H4";
   if(structure.high.time>0)SBORBAddLevel(source+"_SWING_H",source,structure.high.price,1,structure.high.known);
   if(structure.low.time>0)SBORBAddLevel(source+"_SWING_L",source,structure.low.price,-1,structure.low.known);
   return structure.high.time>0 && structure.low.time>0;
  }
bool SBORBContext(datetime decision,datetime nyday)
  {
   datetime utc;if(!SBServerToUTC(decision,utc))return false;
   bool calendar=true;
   if(InpORBUseExternalLevels && sb_orb_context_day!=nyday)
     {
      calendar=SBORBLoadCalendar(utc,nyday);
      if(calendar)sb_orb_context_day=nyday;
     }
   bool higher=true;
   if((InpORBUseExternalLevels || InpORBUseHigherTFStructure) && sb_orb_htf_checked!=decision)
     {
      bool h1=SBORBHTF(PERIOD_H1,decision,sb_orb_h1),h4=SBORBHTF(PERIOD_H4,decision,sb_orb_h4);
      higher=h1 && h4;if(higher)sb_orb_htf_checked=decision;
     }
   sb_orb_context_ok=calendar && higher;return sb_orb_context_ok;
  }
int SBORBTrendContext(int direction)
  {
   if(!InpORBUseHigherTFStructure)return 0;
   if(sb_orb_h1==direction && sb_orb_h4==direction)return 1;
   if(sb_orb_h1==-direction && sb_orb_h4==-direction)return -1;
   return 0;
  }
bool SBORBHasSweep(int direction,datetime since)
  {
   for(int i=0;i<ArraySize(sb_orb_levels);i++)
      if(sb_orb_levels[i].side==-direction && sb_orb_levels[i].swept && sb_orb_levels[i].sweep_origin>=since)return true;
   return false;
  }
bool SBORBExecutionGuard(SBSignal &signal,double entry,double sl,double tp,string &why)
  {
   if(signal.strategy!=SB_ORB)return true;
   if(MathAbs(entry-signal.orb_anchor)>InpORBMaxEntryExtensionPoints*_Point)
     {why="ORB_ENTRY_TOO_EXTENDED";return false;}
   if((InpORBUseExternalLevels || InpORBUseHigherTFStructure) && !sb_orb_context_ok)
     {why="ORB_EXTERNAL_HISTORY_UNAVAILABLE";return false;}
   if(SBORBTrendContext(signal.direction)<0)
     {
      if(InpORBCountertrendPolicy==1 || (InpORBCountertrendPolicy==2 && !SBORBHasSweep(signal.direction,signal.orb_started)))
        {why="ORB_HTF_COUNTERTREND";return false;}
     }
   double nearest,room;string type;
   double actual_rr=signal.direction*(tp-entry)/(signal.direction*(entry-sl));
   for(int i=0;i<ArraySize(sb_orb_levels);i++)
     {
      sb_orb_levels[i].relative_to_entry=sb_orb_levels[i].price>entry?1:(sb_orb_levels[i].price<entry?-1:0);
      SBEvent(SB_ORB,"ORB_EXTERNAL_CONSIDERED",StringFormat("type=%s source=%s price=%.8f known=%s sideOfEntry=%d touched=%s swept=%s closeBeyond=%s",
       sb_orb_levels[i].type,sb_orb_levels[i].source,sb_orb_levels[i].price,TimeToString(sb_orb_levels[i].known),sb_orb_levels[i].relative_to_entry,
       sb_orb_levels[i].touched?"true":"false",sb_orb_levels[i].swept?"true":"false",sb_orb_levels[i].closed_beyond?"true":"false"));
     }
   if(InpORBUseExternalLevels && InpORBExternalPolicy==ORB_WARNING && !SBORBRoom(signal.direction,entry,sl,actual_rr,sb_orb_levels,ORB_STRICT,
      InpORBExternalProximityPoints*_Point,InpORBSweepClearancePoints*_Point,TimeCurrent(),nearest,room,type))
      SBEvent(SB_ORB,"ORB_EXTERNAL_LEVEL_WARNING",type+" obstruction allowed by configured warning policy");
   if(InpORBUseExternalLevels && !SBORBRoom(signal.direction,entry,sl,actual_rr,sb_orb_levels,InpORBExternalPolicy,
      InpORBExternalProximityPoints*_Point,InpORBSweepClearancePoints*_Point,TimeCurrent(),nearest,room,type))
     {why="ORB_EXTERNAL_LEVEL_TOO_CLOSE "+type;return false;}
   return true;
  }
#endif
