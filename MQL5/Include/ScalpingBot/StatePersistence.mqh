#ifndef SB_PERSISTENCE
#define SB_PERSISTENCE
string sb_account,sb_instance;
int sb_owner4=INVALID_HANDLE,sb_owner_triangle=INVALID_HANDLE,sb_owner_orb=INVALID_HANDLE,sb_owner_smt=INVALID_HANDLE;
int sb_owner_vp[4]={INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE};
bool sb_state_ok=true;
datetime sb_signal_after=0;
string SBStrategyKey(int strategy,string suffix)
  { return sb_instance+IntegerToString((long)SBMagic(strategy))+"."+suffix; }
bool SBPut(string key,double value)
  {
   if(GlobalVariableSet(key,value)==0 && !GlobalVariableCheck(key)){sb_state_ok=false;Print("SCALPING BOT | STATE_WRITE_FAILED | ",key);return false;}
   return true;
  }
double SBGet(string key){return GlobalVariableGet(key);}
bool SBConsumed(int strategy,string id)
  { return GlobalVariableCheck(SBStrategyKey(strategy,"P"+id)); }
bool SBConsume(int strategy,string id)
  { bool ok=SBPut(SBStrategyKey(strategy,"P"+id),(double)TimeCurrent());GlobalVariablesFlush();return ok; }
void SBHalt(string why)
  {
   if(!GlobalVariableCheck(sb_account+"halt") || SBGet(sb_account+"halt")==0)SBEvent(SB_4H,"ACCOUNT_HALT",why);
   SBPut(sb_account+"halt",1);GlobalVariablesFlush();
  }
bool SBInitPersistence()
  {
   string account=IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string mode=MQLInfoInteger(MQL_TESTER)?"SB.TEST.":"SB.";
   sb_account=mode+account+".R.";
   sb_instance=mode+account+"."+SBId(_Symbol)+".";
   if(MQLInfoInteger(MQL_TESTER))
     { GlobalVariablesDeleteAll(sb_account);GlobalVariablesDeleteAll(SBStrategyKey(SB_4H,""));GlobalVariablesDeleteAll(SBStrategyKey(SB_TRIANGLE,""));GlobalVariablesDeleteAll(SBStrategyKey(SB_ORB,""));GlobalVariablesDeleteAll(SBStrategyKey(SB_SMT,""));GlobalVariablesDeleteAll(sb_instance+"SMT.X."); }
   if(MQLInfoInteger(MQL_TESTER) && InpEnableVolumeProfile)for(int strategy=5;strategy<=7;strategy++)GlobalVariablesDeleteAll(SBStrategyKey(strategy,""));
   string file=mode+account+"."+SBId(_Symbol)+".";
   sb_owner4=FileOpen("ScalpingBot\\"+file+IntegerToString((long)Inp4HMagicNumber)+".owner",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(sb_owner4==INVALID_HANDLE)return false;
   sb_owner_triangle=FileOpen("ScalpingBot\\"+file+IntegerToString((long)InpTriangleMagicNumber)+".owner",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(sb_owner_triangle==INVALID_HANDLE)return false;
   sb_owner_orb=FileOpen("ScalpingBot\\"+file+IntegerToString((long)InpORBMagicNumber)+".owner",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(sb_owner_orb==INVALID_HANDLE)return false;
   if(InpEnableSMTStrategy)
     {sb_owner_smt=FileOpen("ScalpingBot\\"+file+IntegerToString((long)InpSMTMagicNumber)+".owner",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);if(sb_owner_smt==INVALID_HANDLE)return false;}
   if(InpEnableVolumeProfile)
     {
      // One S5 controller per account/symbol, even if somebody changes its magic namespace.
      sb_owner_vp[0]=FileOpen("ScalpingBot\\"+file+"VP.owner",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);if(sb_owner_vp[0]==INVALID_HANDLE)return false;
      for(int i=1;i<=3;i++){sb_owner_vp[i]=FileOpen("ScalpingBot\\"+file+IntegerToString((long)SBMagic(4+i))+".owner",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);if(sb_owner_vp[i]==INVALID_HANDLE)return false;}
     }
   return true;
  }
int SBAccountMutex()
  { return FileOpen("ScalpingBot\\"+sb_account+"mutex",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON); }
uint SBRiskBaseSignature()
  {
   uint signature=SBHash(StringFormat("%.8f|%.8f|%.8f|%.8f|%d|%.8f|%d|%d|%d|%I64d|%I64d",
     InpDailyLossPercent,InpMaxDrawdownPercent,InpMaxTradeRiskPercent,InpMaxCombinedOpenRiskPercent,
     InpMaxTotalOpenPositions,InpMinFreeMarginPercent,(int)InpBrokerDSTRule,InpBrokerWinterUTCMinutes,
     InpBrokerSummerUTCMinutes,(long)InpBrokerMappingFromUTC,(long)InpBrokerMappingUntilUTC));
   if(InpBrokerDSTRule==SB_UTC_TABLE)signature=SBHash(IntegerToString(signature)+"|UTC_TABLE_V1|"+InpBrokerUTCTransitions);
   return InpRiskBrokerDay?SBHash("BROKER_RISK_V1|"+IntegerToString(signature)):signature;
  }
uint SBDailyDisabledSignature(uint signature)
  {return SBHash("DAILY_LOCK_DISABLED_V1|"+IntegerToString(signature));}
uint SBRiskSignature()
  {uint base=SBRiskBaseSignature();return InpEnableDailyRiskLock?base:SBDailyDisabledSignature(base);}
void SBMigrateDailyPolicy()
  {
   if(!GlobalVariableCheck(sb_account+"valid") || SBGet(sb_account+"valid")!=1)return;
   uint base=SBRiskBaseSignature();double stored=SBGet(sb_account+"signature");
   if(!InpEnableDailyRiskLock && stored==(double)base)
     {
      // Explicit opt-out changes only this policy; never reset peak, halt, intent or equity.
      SBPut(sb_account+"signature",(double)SBRiskSignature());GlobalVariablesFlush();
      SBEvent(SB_4H,"DAILY_RISK_LOCK_DISABLED","Daily baseline/loss entry gate disabled by input; emergency, drawdown and open-risk checks retained");
     }
   else if(InpEnableDailyRiskLock && stored==(double)SBDailyDisabledSignature(base) &&
           InpResetToken>(int)SBGet(sb_account+"reset") && PositionsTotal()==0 && OrdersTotal()==0 && SBGet(sb_account+"intent")==0)
     {
      // An old enabled chart cannot silently flip an opted-out shared account back.
      SBPut(sb_account+"signature",(double)base);SBPut(sb_account+"daily_lock",1);GlobalVariablesFlush();
      SBEvent(SB_4H,"DAILY_RISK_LOCK_REENABLED","Explicit flat-account reset accepted; wait for a known daily baseline");
     }
  }
bool SBBrokerFundingOrActivity(datetime start,datetime end,bool only_funding)
  {
   if(!HistorySelect(start,end))return true;
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong deal=HistoryDealGetTicket(i);if((datetime)HistoryDealGetInteger(deal,DEAL_TIME)<start)continue;
      long type=HistoryDealGetInteger(deal,DEAL_TYPE);
      if(!only_funding)return true;
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL &&
         (MathAbs(HistoryDealGetDouble(deal,DEAL_PROFIT))+MathAbs(HistoryDealGetDouble(deal,DEAL_COMMISSION))+MathAbs(HistoryDealGetDouble(deal,DEAL_FEE)))>0)return true;
     }
   return false;
  }
bool SBBrokerDailyLossBreached(double equity,double baseline,double percent)
  {return baseline<=0 || equity<=0 || !MathIsValidNumber(equity) || 100*(baseline-equity)/baseline>=percent;}
bool SBUpdateBrokerAccount()
  {
   datetime now=TimeCurrent(),day=(datetime)((long)now/86400*86400);
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);if(equity<=0 || !MathIsValidNumber(equity))return false;
   bool exists=GlobalVariableCheck(sb_account+"valid");
   if(exists && SBGet(sb_account+"signature")!=(double)SBRiskSignature())
     {
      if(InpResetToken>(int)SBGet(sb_account+"reset") && PositionsTotal()==0 && OrdersTotal()==0 && SBGet(sb_account+"intent")==0)exists=false;
      else return false;
     }
   if(exists)
     {
      string required[]={"day","daily_equity","peak","seen","daily_lock","halt","intent","reset","last_equity","last_positions"};
      if(SBGet(sb_account+"valid")!=1)return false;
      for(int i=0;i<ArraySize(required);i++)if(!GlobalVariableCheck(sb_account+required[i]))return false;
      if(SBGet(sb_account+"daily_equity")<=0 || SBGet(sb_account+"peak")<=0)return false;
     }
   SBPut(sb_account+"valid",0);
   if(!exists)
     {
      SBPut(sb_account+"day",(double)day);SBPut(sb_account+"daily_equity",equity);SBPut(sb_account+"peak",equity);SBPut(sb_account+"seen",(double)now);
      SBPut(sb_account+"daily_lock",1);SBPut(sb_account+"halt",0);SBPut(sb_account+"intent",0);SBPut(sb_account+"reset",InpResetToken);
      SBPut(sb_account+"signature",(double)SBRiskSignature());SBPut(sb_account+"last_equity",equity);SBPut(sb_account+"last_positions",PositionsTotal());
      if(InpEnableDailyRiskLock)SBEvent(SB_4H,"BROKER_BASELINE_WAIT","New broker-day risk policy: wait for an observed boundary or provable flat-account carry");
     }
   datetime seen=(datetime)SBGet(sb_account+"seen");
   if(now<seen)SBHalt("Broker risk clock moved backwards");
   if((datetime)SBGet(sb_account+"day")!=day)
     {
      bool observed=seen>=day-60 && now<=day+60;
      // Across a market closure, flat equity is exactly recoverable when no deal/funding
      // occurred since the last observation. Open-position unobserved boundaries fail closed.
      bool flat=SBGet(sb_account+"last_positions")==0 && now-seen<=InpBrokerRiskMaximumFlatGapHours*3600 &&
        !SBBrokerFundingOrActivity(seen+1,day-1,false);
      double baseline=flat?SBGet(sb_account+"last_equity"):equity;
      SBPut(sb_account+"day",(double)day);SBPut(sb_account+"daily_equity",baseline);SBPut(sb_account+"daily_lock",observed || flat?0:1);
      SBEvent(SB_4H,"BROKER_RISK_DAY",observed?"OBSERVED_BROKER_BOUNDARY":(flat?"FLAT_ACCOUNT_BASELINE_PROVEN_ACROSS_CLOSURE":"UNKNOWN_OVERNIGHT_EQUITY_BASELINE_LOCKED"));
     }
   if(SBBrokerFundingOrActivity(day,now,true))
     {if(InpEnableDailyRiskLock && SBGet(sb_account+"daily_lock")==0)SBEvent(SB_4H,"BROKER_RISK_FUNDING_LOCK","Funding/nontrade cash adjustment: daily baseline review required; no loss masking");SBPut(sb_account+"daily_lock",1);}
   if(InpResetToken>(int)SBGet(sb_account+"reset") && !InpEmergency && OrdersTotal()==0 && SBGet(sb_account+"intent")==0)
     {SBPut(sb_account+"halt",0);SBPut(sb_account+"peak",equity);SBPut(sb_account+"reset",InpResetToken);}
   double peak=MathMax(equity,SBGet(sb_account+"peak"));SBPut(sb_account+"peak",peak);
   if(SBBrokerDailyLossBreached(equity,SBGet(sb_account+"daily_equity"),InpDailyLossPercent))SBPut(sb_account+"daily_lock",1);
   if(100*(peak-equity)/peak>=InpMaxDrawdownPercent || InpEmergency)SBHalt("Drawdown limit or emergency input");
   SBPut(sb_account+"seen",(double)now);SBPut(sb_account+"last_equity",equity);SBPut(sb_account+"last_positions",PositionsTotal());
   if(sb_state_ok)SBPut(sb_account+"valid",1);GlobalVariablesFlush();return sb_state_ok;
  }
bool SBUpdateAccount(datetime utc)
  {
   SBMigrateDailyPolicy();
   if(InpRiskBrokerDay)return SBUpdateBrokerAccount();
   datetime day,midnight;if(!SBNYDay(utc,day,midnight))return false;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);if(equity<=0 || !MathIsValidNumber(equity))return false;
   bool exists=GlobalVariableCheck(sb_account+"valid");
   if(exists)
     {
      string required[]={"day","daily_equity","peak","seen","daily_lock","halt","intent","reset","signature"};
      if(SBGet(sb_account+"valid")!=1)return false;
      for(int i=0;i<ArraySize(required);i++)if(!GlobalVariableCheck(sb_account+required[i]))return false;
      if(SBGet(sb_account+"signature")!=(double)SBRiskSignature())return false;
      if(SBGet(sb_account+"daily_equity")<=0 || SBGet(sb_account+"peak")<=0)return false;
     }
   SBPut(sb_account+"valid",0);
   if(!exists)
     {
      SBPut(sb_account+"day",(double)day);SBPut(sb_account+"daily_equity",equity);SBPut(sb_account+"peak",equity);
      SBPut(sb_account+"seen",(double)utc);SBPut(sb_account+"daily_lock",1);SBPut(sb_account+"halt",0);
      SBPut(sb_account+"intent",0);SBPut(sb_account+"reset",InpResetToken);SBPut(sb_account+"signature",(double)SBRiskSignature());
      if(InpEnableDailyRiskLock)SBEvent(SB_4H,"DAILY_BASELINE_WAIT","First attachment: new entries locked until an observed NY midnight");
     }
   datetime seen=(datetime)SBGet(sb_account+"seen");
   if(InpResetToken>(int)SBGet(sb_account+"reset") && !InpEmergency && OrdersTotal()==0)
     {
      // Caller has already checked fresh coherent broker/UTC/quote clocks.
      SBPut(sb_account+"halt",0);SBPut(sb_account+"intent",0);SBPut(sb_account+"peak",equity);
      if(seen>utc){SBPut(sb_account+"day",(double)day);SBPut(sb_account+"daily_equity",equity);SBPut(sb_account+"daily_lock",1);}
      seen=utc;SBPut(sb_account+"reset",InpResetToken);SBEvent(SB_4H,"MANUAL_RESET","Risk reset acknowledged; daily lock retained");
     }
   if(utc<seen)SBHalt("UTC clock moved backwards; inspect broker mapping and history");
   if((datetime)SBGet(sb_account+"day")!=day)
     {
      bool observed=seen>=midnight-60 && utc<=midnight+60;
      SBPut(sb_account+"day",(double)day);SBPut(sb_account+"daily_equity",equity);SBPut(sb_account+"daily_lock",observed?0:1);
      SBEvent(SB_4H,"NY_RISK_DAY",observed?"Observed midnight: daily baseline established":"Boundary missed: daily lock retained");
     }
   double peak=MathMax(equity,SBGet(sb_account+"peak"));SBPut(sb_account+"peak",peak);
   if(100*(SBGet(sb_account+"daily_equity")-equity)/SBGet(sb_account+"daily_equity")>=InpDailyLossPercent)SBPut(sb_account+"daily_lock",1);
   if(100*(peak-equity)/peak>=InpMaxDrawdownPercent || InpEmergency)SBHalt("Drawdown limit or emergency input");
   if(utc>=seen)SBPut(sb_account+"seen",(double)utc);
   if(sb_state_ok)SBPut(sb_account+"valid",1);
   GlobalVariablesFlush();return sb_state_ok;
  }
// Count entry ORDERS, not individual partial-fill deals; both strategies have their own magic.
int SBTradesTodayChecked(int strategy,datetime midnight_utc,datetime server_now,datetime &last_fill,string &why)
  {
   last_fill=0;why="";datetime from;
   if(!SBUTCToServerChecked(midnight_utc,from,why))return -1;
   if(from>server_now){why="TRADE_HISTORY_INTERVAL_INVALID";return -1;}
   // Include any supported historical offset, not just a one-hour seasonal change.
   datetime earliest=(datetime)MathMin((long)from-10800,(long)midnight_utc-14*3600);
   if(!HistorySelect(earliest,server_now)){why="DEAL_HISTORY_UNAVAILABLE";return -1;}
   ulong orders[];
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol || (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=SBMagic(strategy))continue;
      long entry=HistoryDealGetInteger(deal,DEAL_ENTRY),type=HistoryDealGetInteger(deal,DEAL_TYPE);
      if((entry!=DEAL_ENTRY_IN && entry!=DEAL_ENTRY_INOUT) || (type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL))continue;
      datetime stamp=(datetime)HistoryDealGetInteger(deal,DEAL_TIME),utc;if(!SBServerToUTCChecked(stamp,utc,why))return -1;
      if(utc<midnight_utc)continue;
      last_fill=(datetime)MathMax((double)last_fill,(double)stamp);
      ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);bool found=false;
      for(int j=0;j<ArraySize(orders);j++)if(orders[j]==order)found=true;
      if(!found){int n=ArraySize(orders);ArrayResize(orders,n+1);orders[n]=order;}
     }
   return ArraySize(orders);
  }
int SBTradesToday(int strategy,datetime midnight_utc,datetime server_now,datetime &last_fill)
  {string why;return SBTradesTodayChecked(strategy,midnight_utc,server_now,last_fill,why);}
#endif
