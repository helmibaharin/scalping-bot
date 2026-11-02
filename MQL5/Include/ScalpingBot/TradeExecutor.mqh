#ifndef SB_EXECUTOR
#define SB_EXECUTOR
int sb_execution_result=0;
string sb_execution_reason="";
bool SBDefinitiveReject(uint code)
  {
   return code==TRADE_RETCODE_REQUOTE || code==TRADE_RETCODE_REJECT || code==TRADE_RETCODE_CANCEL ||
     code==TRADE_RETCODE_INVALID || code==TRADE_RETCODE_INVALID_VOLUME || code==TRADE_RETCODE_INVALID_PRICE ||
     code==TRADE_RETCODE_INVALID_STOPS || code==TRADE_RETCODE_TRADE_DISABLED || code==TRADE_RETCODE_MARKET_CLOSED ||
     code==TRADE_RETCODE_NO_MONEY || code==TRADE_RETCODE_PRICE_CHANGED || code==TRADE_RETCODE_PRICE_OFF ||
     code==TRADE_RETCODE_INVALID_FILL || code==TRADE_RETCODE_LIMIT_ORDERS || code==TRADE_RETCODE_LIMIT_VOLUME;
  }
// Execution stays synchronous: a fresh READY signal is planned/sent in this call.
// The wrapper records timing after execution so telemetry cannot postpone sending.
long sb_execution_presend_us=-1,sb_execution_broker_us=-1;
ulong sb_execution_started_us=0;
void SBExecuteImmediate(SBSignal &signal)
  {
   sb_execution_result=-1;sb_execution_reason="DUPLICATE_SUPPRESSED";
   if(SBConsumed(signal.strategy,signal.id)){SBEvent(signal.strategy,"DUPLICATE_SUPPRESSED",signal.id);return;}
   SBPlan plan;string why="";
   // Consume a fresh confirmation even if rejected: no chasing a later quote.
   if(!SBConsume(signal.strategy,signal.id)){SBHalt("Cannot persist signal consumption");return;}
   if(!SBPlanTrade(signal,plan,why)){sb_execution_reason=why;SBLogPlan(plan,"ENTRY_REJECT",why);return;}
   SBDrawPlan(plan);
   if(InpSignalOnly || (signal.strategy==SB_SMT && InpSMTSignalOnly)){sb_execution_result=1;sb_execution_reason="SIGNAL_ONLY";SBLogPlan(plan,"SIGNAL_ONLY","No order sent");return;}
   MqlTradeRequest request={};MqlTradeCheckResult check={};MqlTradeResult result={};
   request.action=TRADE_ACTION_DEAL;request.symbol=_Symbol;request.magic=plan.magic;request.volume=plan.volume;
   request.type=signal.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;request.price=plan.entry;request.sl=plan.sl;request.tp=plan.tp;
   request.deviation=InpDeviationPoints;request.comment=SBOrderPrefix(signal.strategy,signal.orb_mode)+signal.id;
   if(!SBFilling(request.type_filling)){sb_execution_reason="UNSUPPORTED_FILLING";SBLogPlan(plan,"ENTRY_REJECT",sb_execution_reason);return;}
   if(!OrderCheck(request,check) || (check.retcode!=0 && check.retcode!=TRADE_RETCODE_DONE) ||
      check.margin_free<AccountInfoDouble(ACCOUNT_EQUITY)*InpMinFreeMarginPercent/100)
     {sb_execution_reason="ORDER_CHECK_REJECT "+check.comment;SBLogPlan(plan,"ORDER_CHECK_REJECT",IntegerToString(check.retcode)+" "+check.comment);return;}
   // WAL before send. A crash or ambiguous outcome blocks all SB entries until reconciled.
   if(signal.strategy==SB_SMT && !SBSMTRevalidatePlan(plan,why))
     {sb_execution_reason=why;SBLogPlan(plan,"ENTRY_REJECT",why);return;}
   int ledger=SBLedgerPlan(plan,"REQUEST","DURABLE_BEFORE_SEND");
   if(ledger<0){SBHalt("Cannot persist trade attribution before send");return;}
   SBPut(sb_account+"intent",(double)plan.magic);SBPut(sb_account+"intent_order",0);GlobalVariablesFlush();
   if(!sb_state_ok){SBHalt("Cannot persist order intent");return;}
   sb_execution_presend_us=(long)(GetMicrosecondCount()-sb_execution_started_us);
   ulong broker_started=GetMicrosecondCount();
   bool sent=OrderSend(request,result);
   sb_execution_broker_us=(long)(GetMicrosecondCount()-broker_started);
   if(!SBLedgerResult(ledger,result))SBHalt("Cannot persist order relation; recover broker history before reset");
   sb_execution_reason="ORDER_RESULT "+IntegerToString(result.retcode);
   SBLogPlan(plan,"ORDER_RESULT",StringFormat("send=%s retcode=%u order=%I64u deal=%I64u %s",sent?"true":"false",result.retcode,result.order,result.deal,result.comment));
   if(sent && (result.retcode==TRADE_RETCODE_DONE || result.retcode==TRADE_RETCODE_DONE_PARTIAL || result.retcode==TRADE_RETCODE_PLACED))
     {
      sb_execution_result=2;
      SBPut(sb_account+"intent_order",(double)result.order);
      SBPut(SBStrategyKey(signal.strategy,"E"+IntegerToString((long)result.order)),plan.entry);
      // IOC partial fills are not resubmitted. PositionManager reconciles protections and final order state.
     }
   else if(SBDefinitiveReject(result.retcode))SBPut(sb_account+"intent",0);
   else SBHalt("Order outcome uncertain; inspect broker orders/deals before reset");
   GlobalVariablesFlush();
  }
void SBExecute(SBSignal &signal)
  {
   sb_execution_started_us=GetMicrosecondCount();
   sb_execution_presend_us=-1;sb_execution_broker_us=-1;
   datetime attempted=TimeCurrent();
   datetime confirmed=signal.entry_confirmation>0?signal.entry_confirmation:signal.candle+SBSignalSeconds(signal.strategy);
   SBExecuteImmediate(signal);
   ulong elapsed=GetMicrosecondCount()-sb_execution_started_us;
   SBEvent(signal.strategy,"ENTRY_TIMING",StringFormat("id=%s confirmed=%s attempted=%s confirmation_age_seconds=%I64d processing_us=%I64u presend_us=%I64d broker_us=%I64d result=%d reason=%s",
     signal.id,TimeToString(confirmed,TIME_DATE|TIME_SECONDS),TimeToString(attempted,TIME_DATE|TIME_SECONDS),
     (long)(attempted-confirmed),elapsed,sb_execution_presend_us,sb_execution_broker_us,sb_execution_result,sb_execution_reason));
  }
#endif
