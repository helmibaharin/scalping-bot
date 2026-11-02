#ifndef SB_VP_DRAWING
#define SB_VP_DRAWING
string sb_vp_drawn="",sb_vp_draw_status="";
datetime sb_vp_draw_check=0;
string SBVPObjectPrefix(){return sb_object_prefix+"S5.VP.";}
bool SBVPLevelObject(string level,double price,color col,ENUM_LINE_STYLE style,datetime anchor)
  {
   string name=SBVPObjectPrefix()+level,label=name+".label";bool ok=true;
   if(ObjectFind(0,name)<0)ok=ObjectCreate(0,name,OBJ_HLINE,0,0,price) && ok;
   ok=ObjectSetDouble(0,name,OBJPROP_PRICE,price) && ok;
   ok=ObjectSetInteger(0,name,OBJPROP_COLOR,col) && ok;
   ok=ObjectSetInteger(0,name,OBJPROP_STYLE,style) && ok;
   ok=ObjectSetInteger(0,name,OBJPROP_WIDTH,1) && ok;
   ok=ObjectSetInteger(0,name,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS) && ok;
   ok=ObjectSetInteger(0,name,OBJPROP_BACK,false) && ok;
   ok=ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false) && ok;
   ok=ObjectSetString(0,name,OBJPROP_TEXT,"S5 "+level+" "+DoubleToString(price,_Digits)) && ok;
   if(ObjectFind(0,label)<0)ok=ObjectCreate(0,label,OBJ_TEXT,0,anchor,price) && ok;
   ok=ObjectMove(0,label,0,anchor,price) && ok;
   ok=ObjectSetString(0,label,OBJPROP_TEXT,"S5 "+level+" "+DoubleToString(price,_Digits)) && ok;
   ok=ObjectSetInteger(0,label,OBJPROP_COLOR,col) && ok;
   ok=ObjectSetInteger(0,label,OBJPROP_FONTSIZE,10) && ok;
   ok=ObjectSetInteger(0,label,OBJPROP_ANCHOR,level=="VAL"?ANCHOR_RIGHT_UPPER:ANCHOR_RIGHT_LOWER) && ok;
   ok=ObjectSetInteger(0,label,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS) && ok;
   ok=ObjectSetInteger(0,label,OBJPROP_BACK,false) && ok;
   ok=ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false) && ok;
   return ok;
  }
bool SBVPObjectsPresent()
  {
   string levels[]={"POC","VAH","VAL"};
   for(int i=0;i<3;i++)if(ObjectFind(0,SBVPObjectPrefix()+levels[i])<0 || ObjectFind(0,SBVPObjectPrefix()+levels[i]+".label")<0)return false;
   return true;
  }
void SBVPDrawProfile(bool force=false)
  {
   datetime now=TimeCurrent();if(!force && now<sb_vp_draw_check)return;sb_vp_draw_check=now+30;
   string status="";
   bool valid=sb_vp_profile.valid && sb_vp_day==SBVPBrokerDay(now) && sb_vp_profile.end<=sb_vp_day;
   if(!InpEnableVolumeProfile || !InpDrawObjects || !InpVPDrawObjects || !valid)
     {
      if(sb_vp_drawn!=""){ObjectsDeleteAll(0,SBVPObjectPrefix());sb_vp_drawn="";ChartRedraw();}
      status=!InpDrawObjects?"GLOBAL_DRAW_DISABLED":(!InpVPDrawObjects?"VP_DRAW_DISABLED":"NO_VALID_FROZEN_CURRENT_PROFILE");
     }
   else
     {
      if(!force && sb_vp_drawn==sb_vp_profile.id && SBVPObjectsPresent())return;
      ResetLastError();datetime anchor=iTime(_Symbol,PERIOD_CURRENT,0);if(anchor==0)anchor=now;
      bool a=SBVPLevelObject("POC",sb_vp_profile.poc,clrYellow,STYLE_SOLID,anchor);
      bool b=SBVPLevelObject("VAH",sb_vp_profile.vah,clrLimeGreen,STYLE_DASH,anchor);
      bool c=SBVPLevelObject("VAL",sb_vp_profile.val,clrLimeGreen,STYLE_DASH,anchor);
      ChartRedraw();bool ok=a && b && c && SBVPObjectsPresent();
      status=ok?"OBJECTS_CREATED_OR_UPDATED":"OBJECT_UPDATE_FAILED_ERROR_"+IntegerToString(GetLastError());
      sb_vp_drawn=ok?sb_vp_profile.id:"";
     }
   if(force || status!=sb_vp_draw_status)
      SBEvent(SB_VP_POC,"VP_CHART_LEVELS",StringFormat("reference=%s profile=%s POC=%.8f VAH=%.8f VAL=%.8f validated_frozen=%s result=%s",
       TimeToString(sb_vp_profile.day,TIME_DATE),sb_vp_profile.id,sb_vp_profile.poc,sb_vp_profile.vah,sb_vp_profile.val,valid?"true":"false",status));
   sb_vp_draw_status=status;
  }
#endif
