#ifndef SB_TRADE_LEDGER
#define SB_TRADE_LEDGER
// Append-only snapshots are flushed BEFORE OrderSend; broker order/position relations,
// never comments, recover attribution. Unknown historical trades remain explicitly unknown.
struct SBLedgerMeta {SBPlan plan;string uid,stable,profile;datetime requested;ulong order,position;bool pending;double opened,closed,net;};
SBLedgerMeta sb_ledger_meta[];
ulong sb_ledger_seen[];
int sb_ledger=INVALID_HANDLE;
int SBLedgerFind(string uid)
  {for(int i=0;i<ArraySize(sb_ledger_meta);i++)if(sb_ledger_meta[i].uid==uid)return i;return -1;}
int SBLedgerRelation(ulong order,ulong position)
  {for(int i=ArraySize(sb_ledger_meta)-1;i>=0;i--)if((order>0 && sb_ledger_meta[i].order==order) || (position>0 && sb_ledger_meta[i].position==position))return i;return -1;}
bool SBLedgerSeen(ulong deal)
  {for(int i=0;i<ArraySize(sb_ledger_seen);i++)if(sb_ledger_seen[i]==deal)return true;return false;}
void SBLedgerRemember(ulong deal)
  {if(deal==0 || SBLedgerSeen(deal))return;int n=ArraySize(sb_ledger_seen);ArrayResize(sb_ledger_seen,n+1);sb_ledger_seen[n]=deal;}
bool SBLedgerWrite(int index,string event,ulong deal=0,uint retcode=0,string reason="")
  {
   if(sb_ledger==INVALID_HANDLE)return false;SBLedgerMeta m=sb_ledger_meta[index];SBPlan p=m.plan;
   long stamp=0,entry=-1,exit_stamp=0;double price=0,volume=0,profit=0,commission=0,swap=0,fee=0,slippage=0;
   string exit_reason="",realized="";
   if(deal>0)
     {
      stamp=HistoryDealGetInteger(deal,DEAL_TIME);entry=HistoryDealGetInteger(deal,DEAL_ENTRY);price=HistoryDealGetDouble(deal,DEAL_PRICE);volume=HistoryDealGetDouble(deal,DEAL_VOLUME);
      profit=HistoryDealGetDouble(deal,DEAL_PROFIT);commission=HistoryDealGetDouble(deal,DEAL_COMMISSION);swap=HistoryDealGetDouble(deal,DEAL_SWAP);fee=HistoryDealGetDouble(deal,DEAL_FEE);
      if(entry==DEAL_ENTRY_IN)slippage=p.signal.direction*(price-p.entry)/_Point;
      else {exit_stamp=stamp;exit_reason=EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(deal,DEAL_REASON));}
      if(entry!=DEAL_ENTRY_IN && m.opened>0 && MathAbs(m.closed-m.opened)<1e-9 && p.risk>0)realized=DoubleToString(m.net/p.risk,10);
     }
   ResetLastError();
   ulong actual_order=deal>0?(ulong)HistoryDealGetInteger(deal,DEAL_ORDER):m.order;
   uint written=FileWrite(sb_ledger,"2",event,m.uid,m.stable,m.profile,p.signal.family,p.signal.subtype,p.signal.method,p.signal.pattern_id,p.signal.id,_Symbol,p.signal.direction,p.magic,actual_order,deal,m.position,
    (long)p.signal.candle,(long)m.requested,stamp,p.entry,price,p.sl,p.tp,p.risk,p.signal.rr,p.spread,slippage,p.volume,volume,retcode,exit_stamp,exit_reason,profit,commission,swap,fee,profit+commission+swap+fee,realized,entry,
    p.signal.boundary,p.signal.sweep_extreme,p.signal.liquidity,(long)p.signal.trap_time,p.signal.choch_status,p.signal.bos_status,(long)p.signal.entry_confirmation,reason,p.signal.pivots,p.signal.max_stop_points,p.signal.liquidity_reference,m.order);
   FileFlush(sb_ledger);return written>0 && GetLastError()==0;
  }
bool SBLedgerInit(bool fresh_test=true)
  {
   string file=StringFormat("ScalpingBot\\%I64d_%s_%I64u_%I64u_%I64u_%I64u_lifecycle.csv",AccountInfoInteger(ACCOUNT_LOGIN),_Symbol,Inp4HMagicNumber,InpTriangleMagicNumber,InpORBMagicNumber,InpSMTMagicNumber);
   if(fresh_test && MQLInfoInteger(MQL_TESTER) && FileIsExist(file) && !FileDelete(file))return false;
   sb_ledger=FileOpen(file,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');if(sb_ledger==INVALID_HANDLE)return false;
   ArrayResize(sb_ledger_meta,0);ArrayResize(sb_ledger_seen,0);
   if(FileSize(sb_ledger)==0)
     FileWrite(sb_ledger,"schema","event","uid","strategy_id","profile_id","family","subtype","method","pattern_id","signal_id","symbol","direction","magic","order","deal","position_id","signal_time","request_time","deal_time","requested_entry","fill_price","sl","tp","planned_risk","planned_rr","spread_points","slippage_points","requested_volume","deal_volume","retcode","exit_time","exit_reason","gross_profit","commission","swap","fee","net_profit","realized_rr","entry_type","boundary","sweep_extreme","liquidity","trap_time","choch","bos","entry_confirmation","reason","pivots","max_stop_points","liquidity_reference","request_order");
   else
     {
      // Fixed versioned schema; a torn/incompatible row fails closed rather than losing attribution.
      int row=0;
      while(!FileIsEnding(sb_ledger))
        {
         string f[51];int columns=0;
         while(!FileIsEnding(sb_ledger) && columns<51){f[columns++]=FileReadString(sb_ledger);if(FileIsLineEnding(sb_ledger))break;}
         if(columns==1 && f[0]=="")break;
         if(columns!=51 || (row>0 && f[0]!="2"))return false;row++;if(row==1)continue;
         int k=SBLedgerFind(f[2]);if(k<0){k=ArraySize(sb_ledger_meta);ArrayResize(sb_ledger_meta,k+1);ZeroMemory(sb_ledger_meta[k]);}
         sb_ledger_meta[k].uid=f[2];sb_ledger_meta[k].stable=f[3];sb_ledger_meta[k].profile=f[4];sb_ledger_meta[k].requested=(datetime)StringToInteger(f[17]);
         sb_ledger_meta[k].order=(ulong)StringToInteger(f[50]);sb_ledger_meta[k].position=(ulong)StringToInteger(f[15]);
         sb_ledger_meta[k].pending=f[1]=="REQUEST" || (f[1]=="RESULT" && sb_ledger_meta[k].order==0 && !SBDefinitiveReject((uint)StringToInteger(f[29])));
         SBPlan p={};p.signal.strategy=SBStrategyFromMagic((ulong)StringToInteger(f[12]));p.magic=(ulong)StringToInteger(f[12]);
         p.signal.family=f[5];p.signal.subtype=f[6];p.signal.method=f[7];p.signal.pattern_id=f[8];p.signal.id=f[9];p.signal.direction=(int)StringToInteger(f[11]);p.signal.candle=(datetime)StringToInteger(f[16]);
         p.entry=StringToDouble(f[19]);p.sl=StringToDouble(f[21]);p.tp=StringToDouble(f[22]);p.risk=StringToDouble(f[23]);p.signal.rr=StringToDouble(f[24]);p.spread=StringToDouble(f[25]);p.volume=StringToDouble(f[27]);
         p.signal.boundary=StringToDouble(f[39]);p.signal.sweep_extreme=StringToDouble(f[40]);p.signal.liquidity=f[41];p.signal.trap_time=(datetime)StringToInteger(f[42]);p.signal.choch_status=f[43];p.signal.bos_status=f[44];p.signal.entry_confirmation=(datetime)StringToInteger(f[45]);p.signal.pivots=f[47];p.signal.max_stop_points=StringToDouble(f[48]);
         p.signal.liquidity_reference=f[49];sb_ledger_meta[k].plan=p;
         ulong deal=(ulong)StringToInteger(f[14]);
         if(deal>0 && !SBLedgerSeen(deal))
           {int entry=(int)StringToInteger(f[38]);if(entry==DEAL_ENTRY_IN)sb_ledger_meta[k].opened+=StringToDouble(f[28]);else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)sb_ledger_meta[k].closed+=StringToDouble(f[28]);sb_ledger_meta[k].net+=StringToDouble(f[36]);}
         SBLedgerRemember(deal);
        }
     }
   FileSeek(sb_ledger,0,SEEK_END);FileFlush(sb_ledger);return true;
  }
int SBLedgerPlan(SBPlan &p,string event,string reason)
  {
   string uid=StringFormat("%I64d:%s:%I64u:%s:%I64d",AccountInfoInteger(ACCOUNT_LOGIN),_Symbol,p.magic,p.signal.id,(long)p.signal.candle);
   int k=SBLedgerFind(uid);if(k<0){k=ArraySize(sb_ledger_meta);ArrayResize(sb_ledger_meta,k+1);ZeroMemory(sb_ledger_meta[k]);}
   sb_ledger_meta[k].uid=uid;sb_ledger_meta[k].plan=p;sb_ledger_meta[k].stable=SBStableName(p.signal.strategy);
   sb_ledger_meta[k].profile=p.signal.strategy==SB_SMT?(InpSMTProfile==0?"SMT_MTF":"SMT_M1"):(p.signal.strategy==SB_TRIANGLE?(StringLen(p.signal.method)==0?"LEGACY_TRIANGLE":"SHAPE_M15_M5"):"DEFAULT");
   if(p.signal.strategy==SB_TRIANGLE && StringLen(p.signal.method)==0)
     {sb_ledger_meta[k].plan.signal.family="TRIANGLE";sb_ledger_meta[k].plan.signal.subtype=SBShapeSubtype(p.signal.pattern_type);sb_ledger_meta[k].plan.signal.method="BREAKOUT_CONTINUATION";sb_ledger_meta[k].plan.signal.pattern_id=p.signal.id;}
   // Decorate only the journal copy; never mutate another strategy's decision signal.
   if(p.signal.strategy==SB_4H)
     {sb_ledger_meta[k].plan.signal.family="4H_RANGE";sb_ledger_meta[k].plan.signal.subtype=p.signal.sl_method;sb_ledger_meta[k].plan.signal.method="FALSE_BREAKOUT_REVERSAL";sb_ledger_meta[k].plan.signal.pattern_id=p.signal.id;}
   if(p.signal.strategy==SB_ORB)
     {sb_ledger_meta[k].plan.signal.family="OPENING_RANGE";sb_ledger_meta[k].plan.signal.subtype=p.signal.orb_mode==2?"FALSE_BREAKOUT":"CONTINUATION";sb_ledger_meta[k].plan.signal.method=p.signal.orb_mode==2?"TRAP_REVERSAL":"BREAKOUT_CONTINUATION";sb_ledger_meta[k].plan.signal.pattern_id=p.signal.id;}
   if(p.signal.strategy==SB_SMT)
     {sb_ledger_meta[k].plan.signal.family="SMART_MONEY_TRAP";sb_ledger_meta[k].plan.signal.subtype=p.signal.pattern_type==1?"CLASSIC":(p.signal.pattern_type==2?"MULTIPLE_BABY":"RANGE_TRAP");sb_ledger_meta[k].plan.signal.method="TRAP_REVERSAL";sb_ledger_meta[k].plan.signal.pattern_id=p.signal.id;}
   if(SBIsVP(p.signal.strategy))sb_ledger_meta[k].profile=p.signal.vp_profile;
   sb_ledger_meta[k].requested=event=="REQUEST"?TimeCurrent():0;sb_ledger_meta[k].pending=event=="REQUEST";
   if(!SBLedgerWrite(k,event,0,0,reason))return -1;return k;
  }
bool SBLedgerResult(int k,MqlTradeResult &r)
  {if(k<0)return false;sb_ledger_meta[k].order=r.order;sb_ledger_meta[k].pending=r.order==0 && !SBDefinitiveReject(r.retcode);return SBLedgerWrite(k,"RESULT",0,r.retcode,r.comment);}
bool SBLedgerDeal(ulong deal)
  {
   if(SBLedgerSeen(deal))return true;
   ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER),pos=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   int k=SBLedgerRelation(order,pos);if(k<0)return false;
   sb_ledger_meta[k].position=pos;sb_ledger_meta[k].pending=false;
   int entry=(int)HistoryDealGetInteger(deal,DEAL_ENTRY);double volume=HistoryDealGetDouble(deal,DEAL_VOLUME);
   if(entry==DEAL_ENTRY_IN)sb_ledger_meta[k].opened+=volume;else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)sb_ledger_meta[k].closed+=volume;
   sb_ledger_meta[k].net+=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_COMMISSION)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_FEE);
   if(!SBLedgerWrite(k,"DEAL",deal))return false;SBLedgerRemember(deal);return true;
  }
bool SBLedgerReconcile()
  {
   datetime from=TimeCurrent()-32*86400;
   for(int i=0;i<ArraySize(sb_ledger_meta);i++)if(sb_ledger_meta[i].requested>0)from=MathMin(from,sb_ledger_meta[i].requested-60);
   if(!HistorySelect(from,TimeCurrent()))return false;
   for(int i=0;i<ArraySize(sb_ledger_meta);i++)
     {
      if(!SBConsume(sb_ledger_meta[i].plan.signal.strategy,sb_ledger_meta[i].plan.signal.id))return false;
      if(sb_ledger_meta[i].order>0 || !sb_ledger_meta[i].pending)continue;
      int matches=0;ulong match=0;SBPlan p=sb_ledger_meta[i].plan;
      for(int j=0;j<HistoryOrdersTotal();j++)
        {
         ulong o=HistoryOrderGetTicket(j);datetime t=(datetime)HistoryOrderGetInteger(o,ORDER_TIME_SETUP);
         if(HistoryOrderGetString(o,ORDER_SYMBOL)!=_Symbol || (ulong)HistoryOrderGetInteger(o,ORDER_MAGIC)!=p.magic || t<sb_ledger_meta[i].requested || t>sb_ledger_meta[i].requested+10)continue;
         if(HistoryOrderGetInteger(o,ORDER_TYPE)!=(p.signal.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL) || MathAbs(HistoryOrderGetDouble(o,ORDER_VOLUME_INITIAL)-p.volume)>1e-9)continue;
         matches++;match=o;
        }
      if(matches!=1){SBHalt("Unresolved durable request; order identity needs manual broker review");return false;}
      sb_ledger_meta[i].order=match;sb_ledger_meta[i].pending=false;if(!SBLedgerWrite(i,"RECOVERED_ORDER"))return false;
     }
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong deal=HistoryDealGetTicket(i);if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol)continue;
      ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER),pos=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if(SBLedgerRelation(order,pos)>=0 && !SBLedgerDeal(deal))return false;
     }
   return true;
  }
#endif

