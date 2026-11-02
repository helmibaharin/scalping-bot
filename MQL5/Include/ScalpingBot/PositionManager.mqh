#ifndef SB_POSITIONS
#define SB_POSITIONS
bool SBOwnSelected(int &strategy)
  {
   if(PositionGetString(POSITION_SYMBOL)!=_Symbol)return false;
   ulong magic=(ulong)PositionGetInteger(POSITION_MAGIC);
   if(magic==Inp4HMagicNumber){strategy=SB_4H;return true;}
   if(magic==InpTriangleMagicNumber){strategy=SB_TRIANGLE;return true;}
   if(magic==InpORBMagicNumber){strategy=SB_ORB;return true;}
   if(magic==InpSMTMagicNumber){strategy=SB_SMT;return true;}
   int vp=SBStrategyFromMagic(magic);if(SBIsVP(vp)){strategy=vp;return true;}
   return false;
  }
bool SBOrderFillReconciled(ulong order)
  {
   long position=HistoryOrderGetInteger(order,ORDER_POSITION_ID);
   if(position<=0)return false;
   for(int i=0;i<PositionsTotal();i++)
      if(PositionGetTicket(i)>0 && PositionGetInteger(POSITION_IDENTIFIER)==position)
        {int strategy=0;return SBOwnSelected(strategy) && PositionGetDouble(POSITION_SL)>0 && PositionGetDouble(POSITION_TP)>0;}
   // If the position already closed, prove balanced entry/exit volumes from broker history.
   if(!HistorySelectByPosition((ulong)position))return false;
   double opened=0,closed=0;
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong deal=HistoryDealGetTicket(i);long entry=HistoryDealGetInteger(deal,DEAL_ENTRY),type=HistoryDealGetInteger(deal,DEAL_TYPE);
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL)continue;
      if(entry==DEAL_ENTRY_IN)opened+=HistoryDealGetDouble(deal,DEAL_VOLUME);
      if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)closed+=HistoryDealGetDouble(deal,DEAL_VOLUME);
      if(entry==DEAL_ENTRY_INOUT)return false;
     }
   return opened>0 && closed>=opened-1e-9;
  }
void SBEmergencyClose(ulong ticket,int strategy,int direction,string reason)
  {
   SBHalt(reason);string key=SBStrategyKey(strategy,"C"+IntegerToString((long)ticket));
   if(InpSignalOnly || (strategy==SB_SMT && InpSMTSignalOnly) || GlobalVariableCheck(key))return;
   MqlTick q;datetime utc;string why;
   if(!SBFreshQuote(q,utc,why) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))return;
   if(!PositionSelectByTicket(ticket))return;
   int owner=0;if(!SBOwnSelected(owner) || owner!=strategy)return;
   MqlTradeRequest r={};MqlTradeResult result={};MqlTradeCheckResult check={};
   r.action=TRADE_ACTION_DEAL;r.position=ticket;r.symbol=_Symbol;r.magic=SBMagic(strategy);r.volume=PositionGetDouble(POSITION_VOLUME);
   r.type=direction>0?ORDER_TYPE_SELL:ORDER_TYPE_BUY;r.price=direction>0?q.bid:q.ask;r.deviation=InpDeviationPoints;r.comment="SB safety close";
   if(!SBFilling(r.type_filling) || !OrderCheck(r,check))return;
   if(!SBPut(key,(double)TimeCurrent()))return;GlobalVariablesFlush();
   bool sent=OrderSend(r,result);SBEvent(strategy,"SAFETY_CLOSE",StringFormat("ticket=%I64u sent=%s retcode=%u %s; inspect any remainder manually",ticket,sent?"true":"false",result.retcode,result.comment));
  }
void SBManagePositions()
  {
   bool protected_all=true;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);int strategy=0;if(ticket==0 || !SBOwnSelected(strategy))continue;
      int direction=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
      double volume=PositionGetDouble(POSITION_VOLUME),rr=strategy==SB_ORB?InpORBMinimumRR:(strategy==SB_4H?Inp4HRewardRiskRatio:InpTriangleRewardRiskRatio);
      if(SBIsVP(strategy))
        {
         int metadata=SBLedgerRelation(0,(ulong)PositionGetInteger(POSITION_IDENTIFIER));
         if(metadata<0){protected_all=false;SBHalt("Volume Profile position lacks original request metadata");continue;}
         rr=sb_ledger_meta[metadata].plan.signal.rr;
        }
      double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),loss=0;
      if(tick<=0 || sl<=0 || tp<=0 || direction*(entry-sl)<=0 || !OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,entry,sl,loss))
        {protected_all=false;SBEmergencyClose(ticket,strategy,direction,"Own position lacks valid SL/TP; broker reconciliation required");continue;}
      double risk=MathMax(0,-loss)+volume*InpRoundTripCommissionPerLot;
      bool setup_exits=false;int exit_metadata=-1;
      if(strategy==SB_SMT || strategy==SB_TRIANGLE)
        {
         exit_metadata=SBLedgerRelation(0,(ulong)PositionGetInteger(POSITION_IDENTIFIER));
         if(exit_metadata>=0)setup_exits=SBRecordedSetupExits(strategy,sb_ledger_meta[exit_metadata].profile,sb_ledger_meta[exit_metadata].plan.signal.max_stop_points);
         else if(SBSetupBasedExits(strategy,strategy==SB_TRIANGLE?"BREAKOUT_CONTINUATION":""))
           {protected_all=false;SBHalt("Setup-based position metadata unavailable; inspect journal/history before reset");continue;}
        }
      double max_stop=strategy==SB_SMT?InpSMTMaxStopPoints:(strategy==SB_ORB?InpORBMaxStopPoints:(strategy==SB_4H?Inp4HMaxStopPoints:InpTriangleMaxStopPoints));
      if(SBIsVP(strategy))max_stop=InpVPMaxStopPoints;
      if(risk>AccountInfoDouble(ACCOUNT_EQUITY)*InpMaxTradeRiskPercent/100+1e-8 || (!setup_exits && MathAbs(entry-sl)/_Point>max_stop+0.1))
        {protected_all=false;SBEmergencyClose(ticket,strategy,direction,"Actual-fill risk/stop limit exceeded");continue;}
      if(SBIsVP(strategy) && risk>AccountInfoDouble(ACCOUNT_EQUITY)*InpVPMaxRiskPercent/100+1e-8)
        {protected_all=false;SBEmergencyClose(ticket,strategy,direction,"Volume Profile actual-fill risk cap exceeded");continue;}
      if(strategy==SB_SMT)
        {
         double reward=0;
         bool reward_ok=OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,entry,tp,reward);
         double net_reward=reward-volume*InpRoundTripCommissionPerLot;
         if(!reward_ok || risk>AccountInfoDouble(ACCOUNT_EQUITY)*InpSMTMaxTradeRiskPercent/100+1e-8 ||
            !SBSMTFilledRRValid(entry,sl,tp,direction,net_reward,risk,InpSMTUseMinimumRR && !setup_exits,InpSMTMinimumRR))
           {protected_all=false;SBEmergencyClose(ticket,strategy,direction,"SMT actual-fill RR/risk invalid; dynamic target must not be moved farther");}
         continue; // SMT never enters the legacy fixed-R TP repair path.
        }
      if(strategy==SB_TRIANGLE)
        {
         int metadata=SBLedgerRelation(0,(ulong)PositionGetInteger(POSITION_IDENTIFIER));
         if(metadata<0 && !InpShapeLegacyTriangle)
           {protected_all=false;SBHalt("Shape position metadata unavailable; inspect journal/history before reset");continue;}
         if(metadata>=0 && StringLen(sb_ledger_meta[metadata].plan.signal.method)>0 && sb_ledger_meta[metadata].profile!="LEGACY_TRIANGLE" &&
            (setup_exits || sb_ledger_meta[metadata].plan.signal.method=="TRAP_REVERSAL" || sb_ledger_meta[metadata].plan.signal.family!="TRIANGLE"))
           {
            SBPlan original=sb_ledger_meta[metadata].plan;
            double actual_rr=direction*(tp-entry)/(direction*(entry-sl));
            double minimum=SBShapeMinimumRR(original.signal.method,setup_exits);
            double reward=0;bool reward_ok=OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,entry,tp,reward);
            if(!reward_ok || reward-volume*InpRoundTripCommissionPerLot<=0 || (risk>0 && (reward-volume*InpRoundTripCommissionPerLot)/risk<minimum) || actual_rr<=0 || actual_rr<minimum || MathAbs(tp-original.tp)>tick*0.1)
              {protected_all=false;SBEmergencyClose(ticket,strategy,direction,"Shape actual-fill structural target/RR invalid; no outward TP repair");}
            continue;
           }
        }
      double required=SBRoundPrice(SBTarget(direction,entry,sl,rr),tick,direction);
      if(direction*(tp-required)<-tick*0.1)
        {
         if(InpSignalOnly){protected_all=false;SBHalt("Actual-fill RR below configured minimum; signal-only prevents repair");continue;}
         MqlTick q;datetime utc;string why;
         if(!SBFreshQuote(q,utc,why) || !SBStops(direction,sl,required,q,true))
           {protected_all=false;SBEmergencyClose(ticket,strategy,direction,"Fill RR cannot be repaired within broker constraints");continue;}
         MqlTradeRequest r={};MqlTradeResult result={};r.action=TRADE_ACTION_SLTP;r.position=ticket;r.symbol=_Symbol;r.magic=SBMagic(strategy);r.sl=sl;r.tp=required;
         bool sent=OrderSend(r,result);SBEvent(strategy,"FILL_RR_REPAIR",StringFormat("ticket=%I64u TP=%.8f retcode=%u",ticket,required,result.retcode));
         if(!sent || (result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_NO_CHANGES))
           {protected_all=false;SBEmergencyClose(ticket,strategy,direction,"TP repair failed; inspect position");}
        }
     }
   ulong intent_magic=(ulong)SBGet(sb_account+"intent");
   // Another chart owns that strategy/symbol's fill reconciliation. Do not clear its WAL.
   if(intent_magic!=Inp4HMagicNumber && intent_magic!=InpTriangleMagicNumber && intent_magic!=InpORBMagicNumber && intent_magic!=InpSMTMagicNumber && !SBIsVP(SBStrategyFromMagic(intent_magic)))return;
   ulong order=(ulong)SBGet(sb_account+"intent_order");
   if(order==0 || OrderSelect(order) || !protected_all)return;
   if(HistoryOrderSelect(order))
     {
      if(HistoryOrderGetString(order,ORDER_SYMBOL)!=_Symbol)return;
      long state=HistoryOrderGetInteger(order,ORDER_STATE);
      double filled=HistoryOrderGetDouble(order,ORDER_VOLUME_INITIAL)-HistoryOrderGetDouble(order,ORDER_VOLUME_CURRENT);
      if((state==ORDER_STATE_FILLED || filled>1e-9) && !SBOrderFillReconciled(order))return;
      if(state==ORDER_STATE_FILLED || state==ORDER_STATE_CANCELED || state==ORDER_STATE_REJECTED || state==ORDER_STATE_EXPIRED)
        {SBPut(sb_account+"intent",0);GlobalVariablesFlush();}
     }
  }
bool SBRecoverConsumedHistory()
  {
   if(!HistorySelect(TimeCurrent()-32*86400,TimeCurrent()))return false;
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong deal=HistoryDealGetTicket(i);if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol)continue;
      ulong magic=(ulong)HistoryDealGetInteger(deal,DEAL_MAGIC);int strategy=SBStrategyFromMagic(magic);
      if(strategy==0 || HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
      string comment=HistoryDealGetString(deal,DEAL_COMMENT),prefix=SBOrderPrefix(strategy);
      if(strategy==SB_ORB && StringFind(comment,"SBOF.")==0)prefix="SBOF.";
      if(strategy==SB_SMT && StringFind(comment,"SBS.")==0)prefix="SBS.";
      if(StringFind(comment,prefix)!=0)continue;
      string id=StringSubstr(comment,StringLen(prefix));if(StringLen(id)>0 && StringLen(id)<=10)if(!SBConsume(strategy,id))return false;
      SBPut(SBStrategyKey(strategy,"F"+IntegerToString(HistoryDealGetInteger(deal,DEAL_ORDER))),1);
     }
   return true;
  }
#endif
