#ifndef SB_VP_POLICY
#define SB_VP_POLICY
// Pure accounting predicate: other strategies' hedged positions do not consume S5's slot.
bool SBVPAccountingAllows(bool hedging,bool symbol_occupied,int vp_positions,int total,int maximum,string &why)
  {
   if(!hedging && symbol_occupied){why="ACCOUNT_MODE_INCOMPATIBLE";return false;}
   if(vp_positions>0){why="VP_INTERNAL_POSITION_SLOT_OCCUPIED";return false;}
   if(total>=maximum){why="ACCOUNT_POSITION_LIMIT";return false;}return true;
  }
int SBVPPositions()
  {
   int total=0;for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)>0 && PositionGetString(POSITION_SYMBOL)==_Symbol &&
     SBIsVP(SBStrategyFromMagic((ulong)PositionGetInteger(POSITION_MAGIC))))total++;return total;
  }
int SBVPBrokerEntries(int strategy,datetime day,datetime now,datetime &last_completed)
  {
   if(!HistorySelect(day-InpVPCooldownMinutes*60,now))return -1;
   ulong orders[],exited[];last_completed=0;
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong deal=HistoryDealGetTicket(i);if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol)continue;
      long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);datetime time=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
      if(entry==DEAL_ENTRY_IN && time>=day && (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)==SBMagic(strategy))
        {ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);bool seen=false;for(int j=0;j<ArraySize(orders);j++)if(orders[j]==order)seen=true;if(!seen){int n=ArraySize(orders);ArrayResize(orders,n+1);orders[n]=order;}}
      if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
        {ulong pos=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);bool seen=false;for(int j=0;j<ArraySize(exited);j++)if(exited[j]==pos)seen=true;if(!seen){int n=ArraySize(exited);ArrayResize(exited,n+1);exited[n]=pos;}}
     }
   for(int i=0;i<ArraySize(exited);i++)
     {
      if(!HistorySelectByPosition(exited[i]))return -1;
      double opened=0,closed=0;bool own=true;datetime exit_time=0;
      for(int j=0;j<HistoryDealsTotal();j++)
        {
         ulong deal=HistoryDealGetTicket(j);long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
         if(entry==DEAL_ENTRY_IN){if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=SBMagic(strategy))own=false;opened+=HistoryDealGetDouble(deal,DEAL_VOLUME);}
         if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY){closed+=HistoryDealGetDouble(deal,DEAL_VOLUME);exit_time=MathMax(exit_time,(datetime)HistoryDealGetInteger(deal,DEAL_TIME));}
         if(entry==DEAL_ENTRY_INOUT)own=false;
        }
      if(own && opened>0 && closed>=opened-1e-9)last_completed=MathMax(last_completed,exit_time);
     }
   return ArraySize(orders);
  }
bool SBVPEntryGuard(SBSignal &s,bool hedge,bool occupied,string &why)
  {
   if(!SBVPAccountingAllows(hedge,occupied,SBVPPositions(),PositionsTotal(),InpMaxTotalOpenPositions,why))return false;
   datetime last=0;int entries=SBVPBrokerEntries(s.strategy,(datetime)((long)TimeCurrent()/86400*86400),TimeCurrent(),last);
   if(entries<0){why="VP_BROKER_HISTORY_UNAVAILABLE";return false;}
   if(entries>=InpVPMaxEntriesPerBrokerDay){why="VP_METHOD_BROKER_DAY_ENTRY_LIMIT";return false;}
   if(last>0 && TimeCurrent()-last<InpVPCooldownMinutes*60){why="VP_METHOD_COMPLETED_TRADE_COOLDOWN";return false;}
   if(s.vp_atr<=0 || !MathIsValidNumber(s.vp_atr)){why="VP_ATR_UNAVAILABLE";return false;}
   MqlTick q;if(!SymbolInfoTick(_Symbol,q)){why="VP_QUOTE_UNAVAILABLE";return false;}
   double entry=s.direction>0?q.ask:q.bid;
   double anchor=s.strategy==SB_VP_POC?s.vp_poc:(s.strategy==SB_VP_REVERSAL?(s.direction>0?s.vp_val:s.vp_vah):(s.direction>0?s.vp_vah:s.vp_val));
   if(MathAbs(entry-anchor)>InpVPMaxEntryExtensionATR*s.vp_atr){why="VP_MAX_ENTRY_EXTENSION";return false;}
   return true;
  }
#endif
