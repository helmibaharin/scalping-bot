#ifndef SB_RISK
#define SB_RISK
bool SBFreshQuote(MqlTick &q,datetime &utc,string &why)
  {
   if(!SymbolIsSynchronized(_Symbol) || !SymbolInfoTick(_Symbol,q)){why="QUOTE_UNAVAILABLE";return false;}
   datetime server=TimeCurrent();
   if(!MathIsValidNumber(q.bid) || !MathIsValidNumber(q.ask) || q.bid<=0 || q.ask<q.bid){why="INVALID_PRICE";return false;}
   long stamp=q.time_msc>0?q.time_msc:(long)q.time*1000,age=(long)server*1000-stamp;
   if(stamp<=0 || age< -2000 || age>(long)InpMaxQuoteAgeSeconds*1000){why="STALE_OR_FUTURE_QUOTE";return false;}
   if(!SBServerToUTCChecked(server,utc,why))return false;
   if(!MQLInfoInteger(MQL_TESTER))
     {
      if(!TerminalInfoInteger(TERMINAL_CONNECTED)){why="DISCONNECTED";return false;}
      if(MathAbs((double)(TimeTradeServer()-server))>InpMaxQuoteAgeSeconds || MathAbs((double)(utc-TimeGMT()))>120)
        {why="CLOCKS_DISAGREE_CHECK_BROKER_OFFSET";return false;}
     }
   return true;
  }
bool SBSession(datetime server)
  {
   MqlDateTime t;TimeToStruct(server,t);int seconds=t.hour*3600+t.min*60+t.sec;
   for(int previous=0;previous<2;previous++)for(uint i=0;i<20;i++)
     {
      datetime a,b;if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)((t.day_of_week+7-previous)%7),i,a,b))break;
      int start=(int)((long)a%86400),end=(int)((long)b%86400);
      if(previous==0 && (start==end || (start<end && seconds>=start && seconds<end) || (start>end && seconds>=start)))return true;
      if(previous==1 && start>end && seconds<end)return true;
     }
   return false;
  }
int SBOwnPositions(int strategy)
  {
   int n=0;for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)>0 && PositionGetString(POSITION_SYMBOL)==_Symbol &&
      (ulong)PositionGetInteger(POSITION_MAGIC)==SBMagic(strategy))n++;
   return n;
  }
bool SBOpenRisk(double &risk)
  {
   risk=0;
   // Whole-account exposure, including other EAs/manual trades. Never modify them.
   for(int i=0;i<PositionsTotal();i++)
     {
      if(PositionGetTicket(i)==0)return false;
      string symbol=PositionGetString(POSITION_SYMBOL);double stop=PositionGetDouble(POSITION_SL);
      if(stop<=0)return false;
      double pnl=0,volume=PositionGetDouble(POSITION_VOLUME);
      ENUM_ORDER_TYPE side=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
      if(!OrderCalcProfit(side,symbol,volume,PositionGetDouble(POSITION_PRICE_OPEN),stop,pnl))return false;
      risk+=MathMax(0,-pnl)+volume*InpRoundTripCommissionPerLot;
     }
   return MathIsValidNumber(risk);
  }
bool SBFilling(ENUM_ORDER_TYPE_FILLING &fill)
  {
   long modes=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((modes&SYMBOL_FILLING_FOK)!=0){fill=ORDER_FILLING_FOK;return true;}
   if((modes&SYMBOL_FILLING_IOC)!=0){fill=ORDER_FILLING_IOC;return true;}
   if(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE)!=SYMBOL_TRADE_EXECUTION_MARKET){fill=ORDER_FILLING_RETURN;return true;}
   return false;
  }
bool SBStops(int direction,double sl,double tp,MqlTick &q,bool modification=false)
  {
   long points=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(modification)points=(long)MathMax((double)points,(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
   double distance=points*_Point,tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(sl<=0 || tp<=0)return false;
   return direction>0?(sl<q.bid-tick*0.1 && sl<=q.bid-distance && tp>=q.bid+distance && tp>q.bid):
                      (sl>q.ask+tick*0.1 && sl>=q.ask+distance && tp<=q.ask-distance && tp<q.ask);
  }
bool SBPlanTrade(SBSignal &signal,SBPlan &plan,string &why)
  {
   ZeroMemory(plan);plan.signal=signal;plan.magic=SBMagic(signal.strategy);
   bool setup_exits=SBSetupBasedExits(signal.strategy,signal.method);
   if(setup_exits)plan.signal.max_stop_points=0; // Durable mode marker for actual-fill/restart reconciliation.
   MqlTick q;datetime utc;
   if(!SBFreshQuote(q,utc,why))return false;
   if(!sb_state_ok || SBGet(sb_account+"halt")!=0 || SBGet(sb_account+"intent")!=0 || InpEmergency){why="EMERGENCY_OR_UNRESOLVED_INTENT";return false;}
   if(InpEnableDailyRiskLock && SBGet(sb_account+"daily_lock")!=0){why="DAILY_RISK_BASELINE_OR_LOSS_LOCK";return false;}
   if(!InpTradingEnabled){why="TRADING_DISABLED";return false;}
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL && !InpAllowRealAccount){why="REAL_ACCOUNT_BLOCKED";return false;}
   if(!SBSession(TimeCurrent())){why="SESSION_CLOSED_OR_UNAVAILABLE";return false;}
   if(signal.candle+SBSignalSeconds(signal.strategy)<=sb_signal_after)
     {why="PRE_STARTUP_SIGNAL";return false;}
   if(TimeCurrent()-(signal.candle+SBSignalSeconds(signal.strategy))<0 ||
      TimeCurrent()-(signal.candle+SBSignalSeconds(signal.strategy))>InpMaxSignalAgeSeconds)
     {why="STALE_SIGNAL";return false;}
   long mode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(mode==SYMBOL_TRADE_MODE_DISABLED || mode==SYMBOL_TRADE_MODE_CLOSEONLY ||
     (signal.direction>0 && mode==SYMBOL_TRADE_MODE_SHORTONLY) || (signal.direction<0 && mode==SYMBOL_TRADE_MODE_LONGONLY))
     {why="SYMBOL_DIRECTION_PERMISSION";return false;}
   if(!InpSignalOnly && !(signal.strategy==SB_SMT && InpSMTSignalOnly) && (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))){why="TRADE_PERMISSION_DENIED";return false;}
   bool occupied=false;double direction_volume=0;
   for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)>0 && PositionGetString(POSITION_SYMBOL)==_Symbol)
     {
      occupied=true;
      if((PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)==(signal.direction>0))direction_volume+=PositionGetDouble(POSITION_VOLUME);
     }
   bool hedge=AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   if(SBIsVP(signal.strategy) && !SBVPEntryGuard(signal,hedge,occupied,why))return false;
   if(!SBIsVP(signal.strategy) && !SBAccountingAllows(hedge,occupied,PositionsTotal(),InpMaxTotalOpenPositions)){why="ACCOUNT_POSITION_LIMIT_OR_NETTING_COLLISION";return false;}
   if(OrdersTotal()>0){why="OUTSTANDING_ACCOUNT_ORDERS_EXPOSURE_UNKNOWN";return false;}
   if(!SBIsVP(signal.strategy))
     {
   int maximum=signal.strategy==SB_SMT?InpSMTMaxOpenPositions:(signal.strategy==SB_ORB?InpORBMaxOpenPositions:(signal.strategy==SB_4H?Inp4HMaxOpenPositions:InpTriangleMaxOpenPositions));
   if(SBOwnPositions(signal.strategy)>=maximum){why="STRATEGY_POSITION_LIMIT";return false;}
   datetime day,midnight,last_fill=0;if(!SBNYDay(utc,day,midnight)){why="NY_DATE_UNAVAILABLE";return false;}
   string count_reason="";int trades=SBTradesTodayChecked(signal.strategy,midnight,TimeCurrent(),last_fill,count_reason);
   if(trades<0){why="HISTORY_RECONSTRUCTION_FAILED:"+count_reason;return false;}
   int daily_max=signal.strategy==SB_SMT?InpSMTMaxTradesPerNYDay:(signal.strategy==SB_ORB?InpORBMaxTradesPerNYDay:(signal.strategy==SB_4H?Inp4HMaxTradesPerNYDay:InpTriangleMaxTradesPerDay));
   if(trades>=daily_max){why="STRATEGY_DAILY_LIMIT";return false;}
   if(signal.strategy==SB_TRIANGLE && last_fill>0 && TimeCurrent()-last_fill<InpTriangleCooldownMinutes*60){why="TRIANGLE_COOLDOWN";return false;}
   if(signal.strategy==SB_SMT && last_fill>0 && TimeCurrent()-last_fill<InpSMTCooldownMinutes*60){why="SMT_COOLDOWN";return false;}
     }
   plan.entry=signal.direction>0?q.ask:q.bid;plan.spread=(q.ask-q.bid)/_Point;
   if(plan.spread>InpMaxSpreadPoints){why="SPREAD_LIMIT";return false;}
   if(signal.strategy==SB_SMT && plan.spread>InpSMTMaxSpreadPoints){why="SMT_SPREAD_TOO_HIGH";return false;}
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0){why="INVALID_TICK_SIZE";return false;}
   plan.sl=SBRoundPrice(signal.structural_sl,tick,-signal.direction);
   double distance=signal.direction*(plan.entry-plan.sl);
   if(!MathIsValidNumber(distance) || distance<tick || (!setup_exits && distance/_Point>signal.max_stop_points) || (signal.strategy!=SB_SMT && !SBIsVP(signal.strategy) && !SBShapeDynamic(signal) && signal.rr<2) || (SBIsVP(signal.strategy) && signal.rr<=0)){why="STOP_DISTANCE_OR_RR_INVALID";return false;}
   if(signal.strategy==SB_SMT)
     {
      if(!SBSMTPlanGeometry(signal,plan.entry,plan.sl,plan.tp,why))return false;
      plan.signal.rr=signal.direction*(plan.tp-plan.entry)/distance;
     }
   else if(SBShapeDynamic(signal))
     {if(!SBShapePlanGeometry(signal,plan.entry,plan.sl,plan.tp,why))return false;plan.signal.rr=signal.direction*(plan.tp-plan.entry)/distance;}
   else plan.tp=SBRoundPrice(SBTarget(signal.direction,plan.entry,plan.sl,signal.rr),tick,signal.direction);
   if(signal.strategy==SB_TRIANGLE && StringLen(signal.method)>0 && plan.signal.rr<SBShapeMinimumRR(signal.method,setup_exits)){why="SHAPE_RR_BELOW_MINIMUM";return false;}
   if(!SBStops(signal.direction,plan.sl,plan.tp,q)){why="BROKER_STOP_LEVEL";return false;}
   if(SBIsVP(signal.strategy) && !SBStops(signal.direction,plan.sl,plan.tp,q,true)){why="VP_BROKER_FREEZE_LEVEL";return false;}
   if(signal.strategy==SB_SMT && !SBStops(signal.direction,plan.sl,plan.tp,q,true)){why="SMT_BROKER_FREEZE_LEVEL";return false;}
   if(signal.strategy==SB_ORB && (!SBStops(signal.direction,plan.sl,plan.tp,q,true) ||
      !SBORBExecutionGuard(signal,plan.entry,plan.sl,plan.tp,why)))
     {if(why=="")why="ORB_BROKER_FREEZE_LEVEL";return false;}
   ENUM_ORDER_TYPE type=signal.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double one_lot=0,worst_entry=plan.entry+signal.direction*InpDeviationPoints*_Point;
   if(!OrderCalcProfit(type,_Symbol,1,worst_entry,plan.sl,one_lot) || one_lot>=0){why="RISK_CALCULATION_FAILED";return false;}
   double loss=-one_lot+InpRoundTripCommissionPerLot,equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(SBShapeDynamic(signal))
     {
      double reward=0,shape_minimum=SBShapeMinimumRR(signal.method,setup_exits);
      if(!OrderCalcProfit(type,_Symbol,1,worst_entry,plan.tp,reward) || reward-InpRoundTripCommissionPerLot<=0 || (reward-InpRoundTripCommissionPerLot)/loss<shape_minimum)
        {why="SHAPE_COST_ADJUSTED_RR_INVALID";return false;}
     }
   if(signal.strategy==SB_SMT)
     {
      double reward=0;
      if(!OrderCalcProfit(type,_Symbol,1,worst_entry,plan.tp,reward) || reward-InpRoundTripCommissionPerLot<=0 ||
         (InpSMTUseMinimumRR && !setup_exits && (reward-InpRoundTripCommissionPerLot)/loss<InpSMTMinimumRR))
        {why="SMT_COST_ADJUSTED_RR_INVALID";return false;}
     }
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),maximum_volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double risk_percent=signal.strategy==SB_SMT?MathMin(InpRiskPercent,InpSMTMaxTradeRiskPercent):(SBIsVP(signal.strategy)?MathMin(InpRiskPercent,InpVPMaxRiskPercent):InpRiskPercent);
   plan.volume=SBVolumeFloor(InpUseFixedVolume?InpFixedVolume:equity*risk_percent/100/loss,step);
   double limit=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT);
   if(plan.volume<minimum-1e-9 || plan.volume>maximum_volume+1e-9 || (limit>0 && plan.volume+direction_volume>limit+1e-9))
     {why="VOLUME_MIN_MAX_STEP_OR_DIRECTION_LIMIT";return false;}
   plan.risk=plan.volume*loss;
   if(plan.risk>equity*InpMaxTradeRiskPercent/100+1e-8){why="PER_TRADE_RISK_LIMIT";return false;}
   if(signal.strategy==SB_SMT && plan.risk>equity*InpSMTMaxTradeRiskPercent/100+1e-8){why="SMT_PER_TRADE_RISK_LIMIT";return false;}
   if(SBIsVP(signal.strategy) && plan.risk>equity*InpVPMaxRiskPercent/100+1e-8){why="VP_PER_TRADE_RISK_LIMIT";return false;}
   double open_risk;if(!SBOpenRisk(open_risk)){why="ACCOUNT_HAS_UNKNOWN_OR_UNPROTECTED_RISK";return false;}
   if(open_risk+plan.risk>equity*InpMaxCombinedOpenRiskPercent/100+1e-8){why="COMBINED_RISK_LIMIT";return false;}
   double margin;
   if(!OrderCalcMargin(type,_Symbol,plan.volume,plan.entry,margin) || AccountInfoDouble(ACCOUNT_MARGIN_FREE)-margin<equity*InpMinFreeMarginPercent/100)
     {why="MARGIN_RESERVE";return false;}
   if(setup_exits)SBEvent(signal.strategy,"SETUP_BASED_EXIT_PLAN",StringFormat("entry=%.8f structuralSL=%.8f structuralTP=%.8f actual_price_RR=%.6f volume=%.4f estimatedRisk=%.2f minimumRR=OFF pointStopCap=OFF journalStopCap=0",plan.entry,plan.sl,plan.tp,plan.signal.rr,plan.volume,plan.risk));
   return true;
  }
#endif

