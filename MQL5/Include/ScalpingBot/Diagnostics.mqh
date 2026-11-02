#ifndef SB_DIAGNOSTICS
#define SB_DIAGNOSTICS
int sb_log=INVALID_HANDLE;
int SBLedgerPlan(SBPlan &p,string event,string reason);
string sb_status="Starting",sb_object_prefix;
bool SBInitLog()
  {
   sb_object_prefix="SB."+IntegerToString((long)ChartID())+".";
   if(!InpCSVLogging)return true;
   string name="ScalpingBot\\"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+
               IntegerToString((long)Inp4HMagicNumber)+"_"+IntegerToString((long)InpTriangleMagicNumber)+"_"+IntegerToString((long)InpORBMagicNumber)+".csv";
   if(InpEnableSMTStrategy)StringReplace(name,".csv","_"+IntegerToString((long)InpSMTMagicNumber)+".csv");
   if(MQLInfoInteger(MQL_TESTER) && FileIsExist(name) && !FileDelete(name))return false;
   sb_log=FileOpen(name,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(sb_log==INVALID_HANDLE)return false;
   if(FileSize(sb_log)==0)FileWrite(sb_log,"server_time","symbol","strategy","event","direction","setup_id","candle","entry","sl","tp","sl_method","rr","spread_points","volume","estimated_risk","detail");
   FileSeek(sb_log,0,SEEK_END);return true;
  }
void SBEvent(int strategy,string event,string detail)
  {
   sb_status=SBName(strategy)+" | "+event+" | "+detail;
   Print("SCALPING BOT | ",SBStableName(strategy)," | ",event," | symbol=",_Symbol," | ",detail);
   if(sb_log!=INVALID_HANDLE){FileWrite(sb_log,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),_Symbol,SBName(strategy),event,0,"",0,0,0,0,"",0,0,0,0,detail);FileFlush(sb_log);}
  }
void SBLogPlan(SBPlan &p,string event,string detail)
  {
   if(event=="ENTRY_REJECT" || event=="ORDER_CHECK_REJECT" || event=="SIGNAL_ONLY")
     if(SBLedgerPlan(p,event,detail)<0)Print("LIFECYCLE_WRITE_FAILED | ",event);
   SBEvent(p.signal.strategy,event,StringFormat("dir=%d id=%s candle=%s entry=%.8f SL=%.8f TP=%.8f method=%s RR=%.3f spread=%.2f volume=%.4f risk=%.2f pattern=%d | %s",
      p.signal.direction,p.signal.id,TimeToString(p.signal.candle),p.entry,p.sl,p.tp,p.signal.sl_method,p.signal.rr,p.spread,p.volume,p.risk,p.signal.pattern_type,detail));
   if(sb_log!=INVALID_HANDLE){FileWrite(sb_log,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),_Symbol,SBName(p.signal.strategy),event,p.signal.direction,p.signal.id,(long)p.signal.candle,p.entry,p.sl,p.tp,p.signal.sl_method,p.signal.rr,p.spread,p.volume,p.risk,detail);FileFlush(sb_log);}
  }
string SBRangeLineCaption(int strategy,string id)
  {
   if(strategy==SB_4H)
     {
      if(StringFind(id,".rangeHigh")>=0)return "S1 4H RANGE HIGH";
      if(StringFind(id,".rangeLow")>=0)return "S1 4H RANGE LOW";
     }
   if(strategy==SB_ORB)
     {
      if(id=="rangeHigh")return "S3 ORB RANGE HIGH";
      if(id=="rangeLow")return "S3 ORB RANGE LOW";
      if(id=="H1_SWING_H")return "ORB REFERENCE - H1 SWING HIGH";
      if(id=="H1_SWING_L")return "ORB REFERENCE - H1 SWING LOW";
      if(id=="H4_SWING_H")return "ORB REFERENCE - H4 SWING HIGH";
      if(id=="H4_SWING_L")return "ORB REFERENCE - H4 SWING LOW";
     }
   return "";
  }
void SBHLine(int strategy,string id,double price,color col)
  {
   if(!InpDrawObjects)return;string name=sb_object_prefix+SBName(strategy)+"."+id;
   if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   string caption=SBRangeLineCaption(strategy,id);if(caption=="")return;
   string text=caption+" "+DoubleToString(price,_Digits);
   string tooltip=text;
   if(strategy==SB_4H)tooltip+=" | NY "+StringSubstr(id,0,10)+" 00:00-04:00";
   ObjectSetString(0,name,OBJPROP_TEXT,text);ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip);
   // Only the strategy ranges get persistent labels. ORB swing references keep
   // descriptive tooltips so an overlapping grey reference cannot masquerade as S1.
   if(strategy!=SB_4H && id!="rangeHigh" && id!="rangeLow")return;
   string label=name+".label";datetime anchor=iTime(_Symbol,PERIOD_CURRENT,0);if(anchor==0)anchor=TimeCurrent();
   if(ObjectFind(0,label)<0)ObjectCreate(0,label,OBJ_TEXT,0,anchor,price);
   ObjectMove(0,label,0,anchor,price);ObjectSetString(0,label,OBJPROP_TEXT,text);
   ObjectSetString(0,label,OBJPROP_TOOLTIP,tooltip);ObjectSetInteger(0,label,OBJPROP_COLOR,col);
   ObjectSetInteger(0,label,OBJPROP_FONTSIZE,9);ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,label,OBJPROP_ANCHOR,strategy==SB_4H?ANCHOR_RIGHT_LOWER:ANCHOR_RIGHT_UPPER);
  }
void SBMarker(int strategy,string id,datetime stamp,double price,color col)
  {
   if(!InpDrawObjects)return;string name=sb_object_prefix+SBName(strategy)+"."+id;
   if(ObjectFind(0,name)>=0)return;
   ObjectCreate(0,name,OBJ_ARROW,0,stamp,price);ObjectSetInteger(0,name,OBJPROP_ARROWCODE,159);ObjectSetInteger(0,name,OBJPROP_COLOR,col);
  }
void SBTrend(string id,datetime t1,double p1,datetime t2,double p2,color col)
  {
   if(!InpDrawObjects)return;string name=sb_object_prefix+"TRIANGLE."+id;
   if(ObjectFind(0,name)>=0)return;
   ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2);ObjectSetInteger(0,name,OBJPROP_COLOR,col);ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,true);
  }
void SBZone(int strategy,string id,datetime start,datetime end,double high,double low,color col)
  {
   if(!InpDrawObjects)return;string name=sb_object_prefix+SBName(strategy)+"."+id;
   if(ObjectFind(0,name)>=0)return;
   ObjectCreate(0,name,OBJ_RECTANGLE,0,start,high,end,low);ObjectSetInteger(0,name,OBJPROP_COLOR,col);ObjectSetInteger(0,name,OBJPROP_FILL,false);
  }
void SBDrawPlan(SBPlan &p)
  {
   if(p.signal.strategy==SB_SMT && !InpSMTDrawObjects)return;
   if(p.signal.strategy==SB_TRIANGLE && StringLen(p.signal.method)>0 && !InpShapeDraw)return;
   string id=p.signal.id;
   SBMarker(p.signal.strategy,id+".entry",p.signal.candle,p.entry,clrWhite);
   SBHLine(p.signal.strategy,id+".SL",p.sl,clrRed);SBHLine(p.signal.strategy,id+".TP",p.tp,clrLimeGreen);
   if(p.signal.strategy==SB_TRIANGLE && StringLen(p.signal.method)>0)
     {
      string name=sb_object_prefix+"TRIANGLE."+id+".label";
      ObjectCreate(0,name,OBJ_TEXT,0,p.signal.candle,p.entry);
      ObjectSetString(0,name,OBJPROP_TEXT,"S2_SHAPE_PATTERN "+p.signal.subtype+" "+p.signal.method+" RR="+DoubleToString(p.signal.rr,2));
     }
  }
#endif
