#ifndef SB_BROKER_TIME_CONFIG
#define SB_BROKER_TIME_CONFIG
// No terminal, PC-clock or present-day offset inference. UTC intervals are [start,end).
string sb_mapping_key="",sb_mapping_error="";
datetime sb_mapping_starts[];
int sb_mapping_minutes[],sb_mapping_offsets[];
bool sb_mapping_cached=false;
bool SBMappingConfigValid(string &why)
  {
   string key=IntegerToString((int)InpBrokerDSTRule)+"|"+IntegerToString(InpBrokerWinterUTCMinutes)+"|"+
    IntegerToString(InpBrokerSummerUTCMinutes)+"|"+IntegerToString((long)InpBrokerMappingFromUTC)+"|"+
    IntegerToString((long)InpBrokerMappingUntilUTC)+"|"+InpBrokerUTCTransitions;
   if(sb_mapping_cached && key==sb_mapping_key){why=sb_mapping_error;return why=="";}
   sb_mapping_cached=true;sb_mapping_key=key;sb_mapping_error="";
   ArrayResize(sb_mapping_starts,0);ArrayResize(sb_mapping_minutes,0);ArrayResize(sb_mapping_offsets,0);
   if(InpBrokerMappingFromUTC<D'1987.01.01' || InpBrokerMappingUntilUTC>D'2100.01.01' || InpBrokerMappingFromUTC>=InpBrokerMappingUntilUTC)
      sb_mapping_error="INVALID_COVERAGE_SUPPORTED_NY_YEARS_1987_2099";
   else if((int)InpBrokerDSTRule<0 || (int)InpBrokerDSTRule>3)sb_mapping_error="UNKNOWN_RULE";
   else if(MathAbs(InpBrokerWinterUTCMinutes)>840 || MathAbs(InpBrokerSummerUTCMinutes)>840)sb_mapping_error="OFFSET_OUT_OF_RANGE";
   else if(InpBrokerDSTRule==SB_EU && InpBrokerMappingFromUTC<D'1996.01.01')sb_mapping_error="EU_RULE_REQUIRES_1996_OR_LATER_USE_UTC_TABLE";
   else if(InpBrokerDSTRule==SB_UTC_TABLE)
     {
      string rows[];int n=StringSplit(InpBrokerUTCTransitions,';',rows);
      if(n<1 || n>512 || StringSubstr(InpBrokerUTCTransitions,StringLen(InpBrokerUTCTransitions)-1)==";")sb_mapping_error="TABLE_EMPTY_OR_TOO_LARGE_OR_TRAILING_SEPARATOR";
      for(int i=0;i<n && sb_mapping_error=="";i++)
        {
         string pair[];int parts=StringSplit(rows[i],'=',pair);
         if(parts!=2){sb_mapping_error="TABLE_EXPECTS_UTC_DATE_EQUALS_OFFSET";break;}
         datetime start=StringToTime(pair[0]);
         // StringToTime can normalize invalid dates or infer omitted components: disallow both.
         if(StringLen(pair[0])!=16 || TimeToString(start,TIME_DATE|TIME_MINUTES)!=pair[0]){sb_mapping_error="TABLE_REQUIRES_EXACT_YYYY_MM_DD_HH_MM_UTC";break;}
         int offset=(int)StringToInteger(pair[1]);
         if(IntegerToString(offset)!=pair[1] || MathAbs(offset)>840){sb_mapping_error="TABLE_INVALID_SIGNED_INTEGER_OFFSET";break;}
         if((i==0 && start!=InpBrokerMappingFromUTC) || start<InpBrokerMappingFromUTC || start>=InpBrokerMappingUntilUTC || (i>0 && start<=sb_mapping_starts[i-1]))
            {sb_mapping_error="TABLE_FIRST_ROW_OR_ORDER_OR_COVERAGE_INVALID";break;}
         ArrayResize(sb_mapping_starts,i+1);ArrayResize(sb_mapping_minutes,i+1);sb_mapping_starts[i]=start;sb_mapping_minutes[i]=offset;
         bool seen=false;for(int j=0;j<ArraySize(sb_mapping_offsets);j++)if(sb_mapping_offsets[j]==offset)seen=true;
         if(!seen){int k=ArraySize(sb_mapping_offsets);ArrayResize(sb_mapping_offsets,k+1);sb_mapping_offsets[k]=offset;}
        }
     }
   why=sb_mapping_error;return why=="";
  }
int SBTableOffset(datetime utc)
  {
   int lo=0,hi=ArraySize(sb_mapping_starts)-1;
   while(lo<hi){int mid=(lo+hi+1)/2;if(sb_mapping_starts[mid]<=utc)lo=mid;else hi=mid-1;}
   return sb_mapping_minutes[lo];
  }
#endif
