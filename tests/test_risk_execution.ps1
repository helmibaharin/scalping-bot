$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$inc=Join-Path $root 'MQL5/Include/ScalpingBot'
$risk=Get-Content "$inc/RiskManager.mqh" -Raw
$risk=$risk.Substring($risk.IndexOf('bool SBOpenRisk'))
$execution=Get-Content "$inc/TradeExecutor.mqh" -Raw
$rules=Get-Content "$inc/Rules.mqh" -Raw
$vp=Get-Content "$inc/VolumeProfilePolicy.mqh" -Raw
$vp=$vp.Substring($vp.IndexOf('bool SBVPAccountingAllows'),$vp.IndexOf('int SBVPPositions')-$vp.IndexOf('bool SBVPAccountingAllows'))+$vp.Substring($vp.IndexOf('bool SBVPEntryGuard'))
$policy=Get-Content "$inc/SetupExitPolicy.mqh" -Raw
$code=($policy+$rules+$vp+$risk+$execution) -replace '(?m)^#.*$',''
$code=$code -replace '\bdatetime\b','long' -replace '(?m)^(bool|int|double|void|string) ','public static $1 '
$code=$code -replace 'double &risk','ref double risk' -replace 'int &side','ref int side' -replace 'double &extreme','ref double extreme'
$code=$code -replace 'SBTradesTodayChecked\(signal.strategy,midnight,TimeCurrent\(\),last_fill,count_reason\)','SBTradesTodayChecked(signal.strategy,midnight,TimeCurrent(),ref last_fill,ref count_reason)'
$code=$code -replace 'ENUM_ORDER_TYPE_FILLING &fill','ref int fill' -replace '\bENUM_ORDER_TYPE\b','int'
$code=$code -replace '(SBSignal|SBPlan|MqlTick) &(\w+)','$1 $2' -replace 'string &why','ref string why'
$code=$code -replace 'SBPlan plan;','SBPlan plan=new SBPlan();' -replace 'MqlTick q;long utc;','MqlTick q=new MqlTick();long utc=0;'
$code=$code -replace 'long day,midnight,last_fill=0;','long day=0,midnight=0,last_fill=0;'
$code=$code -replace 'double open_risk;','double open_risk=0;' -replace 'double margin;','double margin=0;'
$code=$code -replace '(MqlTradeRequest|MqlTradeCheckResult|MqlTradeResult) (\w+)=\{\};','$1 $2=new $1();'
$code=$code -replace 'ZeroMemory\(plan\)','ResetPlan(plan)'
$code=$code -replace 'SBFreshQuote\(q,utc,why\)','SBFreshQuote(q,ref utc,ref why)' -replace 'SBOpenRisk\(open_risk\)','SBOpenRisk(ref open_risk)'
$code=$code -replace 'OrderCalcProfit\(([^;]+?),one_lot\)','OrderCalcProfit($1,ref one_lot)' -replace 'OrderCalcProfit\(([^;]+?),pnl\)','OrderCalcProfit($1,ref pnl)'
$code=$code -replace 'OrderCalcMargin\(([^;]+?),margin\)','OrderCalcMargin($1,ref margin)'
$code=$code -replace 'SBNYDay\(utc,day,midnight\)','SBNYDay(utc,ref day,ref midnight)' -replace 'TimeCurrent\(\),last_fill\)','TimeCurrent(),ref last_fill)'
$code=$code -replace 'SBFilling\(request.type_filling\)','SBFilling(ref request.type_filling)' -replace 'SBPlanTrade\(signal,plan,why\)','SBPlanTrade(signal,plan,ref why)'
$code=$code -replace 'SBORBExecutionGuard\(signal,plan.entry,plan.sl,plan.tp,why\)','SBORBExecutionGuard(signal,plan.entry,plan.sl,plan.tp,ref why)'
$code=$code -replace 'SBSMTPlanGeometry\(signal,plan.entry,plan.sl,plan.tp,why\)','SBSMTPlanGeometry(signal,plan.entry,plan.sl,ref plan.tp,ref why)'
$code=$code -replace 'SBSMTRevalidatePlan\(plan,why\)','SBSMTRevalidatePlan(plan,ref why)'
$code=$code -replace 'SBShapePlanGeometry\(signal,plan.entry,plan.sl,plan.tp,why\)','SBShapePlanGeometry(signal,plan.entry,plan.sl,ref plan.tp,ref why)'
$code=$code -replace 'double reward=0;','double reward=0;' -replace 'plan.tp,reward\)','plan.tp,ref reward)'
$code=$code -replace '!AccountInfoInteger\((\w+)\)','(AccountInfoInteger($1)==0)'
$code=$code -replace 'SBVPEntryGuard\(signal,hedge,occupied,why\)','SBVPEntryGuard(signal,hedge,occupied,ref why)'
$code=$code -replace 'SBVPAccountingAllows\(hedge,occupied,SBVPPositions\(\),PositionsTotal\(\),InpMaxTotalOpenPositions,why\)','SBVPAccountingAllows(hedge,occupied,SBVPPositions(),PositionsTotal(),InpMaxTotalOpenPositions,ref why)'
$code=$code -replace 'long last=0;','long last=0;'
$code=$code -replace 'TimeCurrent\(\),last\)','TimeCurrent(),ref last)'
$code=$code -replace 'MqlTick q;if','MqlTick q=new MqlTick();if'
$mock=@'
public const int SB_SMT=4,SB_VP_POC=5,SB_VP_REVERSAL=6,SB_VP_BREAKOUT=7;
public static double InpVPMaxRiskPercent=.25,InpVPMaxEntryExtensionATR=1;
public static int InpVPCooldownMinutes=15,InpVPMaxEntriesPerBrokerDay=5,vpEntries=0;
public static long vpLastExit=0;
public static bool SBIsVP(int s){return s>=5&&s<=7;}
public static int SBVPPositions(){int n=0;foreach(var p in positions)if(SBIsVP(p.strategy)&&p.symbol==_Symbol)n++;return n;}
public static int SBVPBrokerEntries(int s,long day,long now,ref long last){last=vpLastExit;return history?vpEntries:-1;}
public static bool SymbolInfoTick(string symbol,MqlTick q){q.bid=100;q.ask=100+spread;return fresh;}
public static bool InpShapeReversalMinRREnabled=true,InpShapeSetupBasedExits=false,InpSMTSetupBasedExits=false,InpShapeLegacyTriangle=false;
public static double InpShapeReversalMinRR=1,InpShapeContinuationMinRR=2;
public static bool SBShapeDynamic(SBSignal s){return s.strategy==2 && !string.IsNullOrEmpty(s.method) && (SBSetupBasedExits(s.strategy,s.method) || s.method=="TRAP_REVERSAL" || s.pattern_type>3);}
public static bool SBShapePlanGeometry(SBSignal s,double e,double sl,ref double tp,ref string why){tp=s.target;return tp>e;}
public static int SBLedgerPlan(SBPlan p,string e,string why){return persist?0:-1;}
public static bool SBLedgerResult(int k,MqlTradeResult r){return persist;}
public static int InpSMTMaxOpenPositions=1,InpSMTMaxTradesPerNYDay=3,InpSMTCooldownMinutes=15;
public static bool InpSMTUseMinimumRR=true,InpSMTSignalOnly=false;
public static double InpSMTMinimumRR=1,InpSMTMaxSpreadPoints=50,InpSMTMaxTradeRiskPercent=.25,smtTarget=108;
public static bool smtRevalidate=true;
public static bool SBSMTPlanGeometry(SBSignal s,double entry,double sl,ref double tp,ref string why){tp=smtTarget;double rr=s.direction*(tp-entry)/(s.direction*(entry-sl));if(s.direction*(tp-entry)<=0 || (InpSMTUseMinimumRR&&!InpSMTSetupBasedExits&&rr<InpSMTMinimumRR)){why="SMT_RR_BELOW_MINIMUM";return false;}return true;}
public static bool SBSMTRevalidatePlan(SBPlan p,ref string why){return smtRevalidate;}
public const int SB_4H=1,SB_TRIANGLE=2,PERIOD_M5=5,ACCOUNT_TRADE_MODE=1,ACCOUNT_TRADE_MODE_REAL=2,ACCOUNT_MARGIN_MODE=3,ACCOUNT_MARGIN_MODE_RETAIL_HEDGING=4;
public const int SB_ORB=3;public static int InpORBMaxOpenPositions=1,InpORBMaxTradesPerNYDay=2,orbTrades=0;
public static int SBSignalSeconds(int s){return 300;}
public static string SBOrderPrefix(int s,int mode=0){return s==3?(mode==2?"SBOF.":"SBOC."):(s==1?"SB4.":"SBT.");}
public static bool SBORBExecutionGuard(SBSignal s,double e,double sl,double tp,ref string why){return true;} // Real context tested by native ORB fixture.
public const int ACCOUNT_TRADE_ALLOWED=5,ACCOUNT_TRADE_EXPERT=6,TERMINAL_TRADE_ALLOWED=7,MQL_TRADE_ALLOWED=8,ACCOUNT_EQUITY=9,ACCOUNT_MARGIN_FREE=10;
public const int SYMBOL_TRADE_MODE=11,SYMBOL_TRADE_MODE_DISABLED=0,SYMBOL_TRADE_MODE_CLOSEONLY=1,SYMBOL_TRADE_MODE_SHORTONLY=2,SYMBOL_TRADE_MODE_LONGONLY=3;
public const int SYMBOL_TRADE_STOPS_LEVEL=12,SYMBOL_TRADE_FREEZE_LEVEL=13,SYMBOL_TRADE_TICK_SIZE=14,SYMBOL_VOLUME_STEP=15,SYMBOL_VOLUME_MIN=16,SYMBOL_VOLUME_MAX=17,SYMBOL_VOLUME_LIMIT=18;
public const int SYMBOL_FILLING_MODE=19,SYMBOL_FILLING_FOK=1,SYMBOL_FILLING_IOC=2,SYMBOL_TRADE_EXEMODE=20,SYMBOL_TRADE_EXECUTION_MARKET=2;
public const int ORDER_FILLING_FOK=0,ORDER_FILLING_IOC=1,ORDER_FILLING_RETURN=2,ORDER_TYPE_BUY=0,ORDER_TYPE_SELL=1,POSITION_TYPE_BUY=0;
public const int POSITION_SYMBOL=21,POSITION_SL=22,POSITION_VOLUME=23,POSITION_TYPE=24,POSITION_PRICE_OPEN=25,TRADE_ACTION_DEAL=1;
public const uint TRADE_RETCODE_DONE=10009,TRADE_RETCODE_DONE_PARTIAL=10010,TRADE_RETCODE_PLACED=10008,TRADE_RETCODE_REQUOTE=10004,TRADE_RETCODE_REJECT=10006,TRADE_RETCODE_CANCEL=10007;
public const uint TRADE_RETCODE_INVALID=10013,TRADE_RETCODE_INVALID_VOLUME=10014,TRADE_RETCODE_INVALID_PRICE=10015,TRADE_RETCODE_INVALID_STOPS=10016,TRADE_RETCODE_TRADE_DISABLED=10017,TRADE_RETCODE_MARKET_CLOSED=10018;
public const uint TRADE_RETCODE_NO_MONEY=10019,TRADE_RETCODE_PRICE_CHANGED=10020,TRADE_RETCODE_PRICE_OFF=10021,TRADE_RETCODE_INVALID_FILL=10030,TRADE_RETCODE_LIMIT_ORDERS=10033,TRADE_RETCODE_LIMIT_VOLUME=10034;
public static string _Symbol="EURUSD.suffix",sb_account="account.";public static double _Point=.01;
public static long sb_signal_after=0;
public static bool sb_state_ok=true,InpEmergency=false,InpTradingEnabled=true,InpSignalOnly=false,InpAllowRealAccount=false,InpUseFixedVolume=true;
public static bool InpEnableDailyRiskLock=true;
public static double InpFixedVolume=.01,InpRiskPercent=.25,InpMaxTradeRiskPercent=.25,InpMaxCombinedOpenRiskPercent=.5,InpMinFreeMarginPercent=25,InpMaxSpreadPoints=50,InpRoundTripCommissionPerLot=0;
public static int InpMaxTotalOpenPositions=2,Inp4HMaxOpenPositions=1,InpTriangleMaxOpenPositions=1,Inp4HMaxTradesPerNYDay=1,InpTriangleMaxTradesPerDay=3,InpTriangleCooldownMinutes=15,InpTriangleTimeframe=5,InpMaxSignalAgeSeconds=90,InpDeviationPoints=10;
public static bool hedge=true,real=false,permissions=true,session=true,fresh=true,history=true,checkOK=true,persist=true,sendOK=true,calcOK=true;
public static long tradeMode=4,fillMode=1,executionMode=2;public static double equity=10000,free=9000,spread=.2,minVolume=.01,maxVolume=100,step=.01,volumeLimit=0,stops=0,freeze=0;
public static int fourTrades=0,triangleTrades=0,sends=0,riskChecks=0,checks=0;public static long lastFill=0;public static uint sendCode=TRADE_RETCODE_DONE;
public class MqlTick {public double bid=100,ask=100.2;}
public class SBSignal {public double vp_atr=10,vp_poc=100,vp_vah=110,vp_val=90;public int pattern_type=0;public string method="";public double target=0;public int strategy=1,direction=1,orb_mode=0;public long candle=9700;public string id="setup1",sl_method="BREAKOUT_EXTREME";public double structural_sl=95,rr=2,max_stop_points=1000;}
public class SBPlan {public SBSignal signal;public ulong magic;public double entry,sl,tp,volume,risk,spread;}
public class MqlTradeRequest {public int action,type,type_filling,deviation;public string symbol,comment;public ulong magic;public double volume,price,sl,tp;}
public class MqlTradeCheckResult {public uint retcode=0;public double margin_free=9000;public string comment="";}
public class MqlTradeResult {public uint retcode;public ulong order=123,deal=456;public string comment="";}
public class Pos {public string symbol="EURUSD.suffix";public int side=0,strategy=1;public double sl=95,entry=100,volume=.01;}
public static System.Collections.Generic.List<Pos> positions=new System.Collections.Generic.List<Pos>();public static Pos selected;
public static System.Collections.Generic.Dictionary<string,double> disk=new System.Collections.Generic.Dictionary<string,double>();
public static System.Collections.Generic.HashSet<string> consumed=new System.Collections.Generic.HashSet<string>();
public static int PositionsTotal(){return positions.Count;}public static ulong PositionGetTicket(int i){selected=positions[i];return (ulong)(i+1);}
public static string PositionGetString(int p){return selected.symbol;}public static long PositionGetInteger(int p){return selected.side;}
public static double PositionGetDouble(int p){return p==POSITION_SL?selected.sl:(p==POSITION_VOLUME?selected.volume:selected.entry);}
public static long SymbolInfoInteger(string s,int p){return p==SYMBOL_TRADE_MODE?tradeMode:(p==SYMBOL_TRADE_STOPS_LEVEL?(long)stops:(p==SYMBOL_TRADE_FREEZE_LEVEL?(long)freeze:(p==SYMBOL_FILLING_MODE?fillMode:executionMode)));}
public static double SymbolInfoDouble(string s,int p){return p==SYMBOL_TRADE_TICK_SIZE?.01:(p==SYMBOL_VOLUME_MIN?minVolume:(p==SYMBOL_VOLUME_MAX?maxVolume:(p==SYMBOL_VOLUME_STEP?step:volumeLimit)));}
public static bool OrderCalcProfit(int type,string s,double volume,double entry,double sl,ref double pnl){pnl=(type==ORDER_TYPE_BUY?1:-1)*(sl-entry)*100*volume;return calcOK;}
public static bool OrderCalcMargin(int t,string s,double v,double e,ref double m){m=v*1000;return calcOK;}
public static long AccountInfoInteger(int p){return p==ACCOUNT_TRADE_MODE?(real?ACCOUNT_TRADE_MODE_REAL:0):(p==ACCOUNT_MARGIN_MODE?(hedge?ACCOUNT_MARGIN_MODE_RETAIL_HEDGING:0):(permissions?1:0));}
public static double AccountInfoDouble(int p){return p==ACCOUNT_EQUITY?equity:free;}
public static bool TerminalInfoInteger(int p){return permissions;}public static bool MQLInfoInteger(int p){return permissions;}
public static bool SBFreshQuote(MqlTick q,ref long utc,ref string why){q.bid=100;q.ask=100+spread;utc=10000;if(!fresh)why="STALE_QUOTE";return fresh;}
public static bool SBSession(long t){return session;}public static long TimeCurrent(){return 10000;}
public static int PeriodSeconds(int p){return p*60;}public static int OrdersTotal(){return 0;}
public static int SBOwnPositions(int s){int n=0;foreach(var p in positions)if(p.strategy==s&&p.symbol==_Symbol)n++;return n;}
public static bool SBNYDay(long t,ref long day,ref long midnight){day=0;midnight=0;return true;}
public static int SBTradesToday(int s,long m,long now,ref long last){last=lastFill;return history?(s==3?orbTrades:(s==1?fourTrades:triangleTrades)):-1;}
public static int SBTradesTodayChecked(int s,long m,long now,ref long last,ref string why){why=history?"":"DEAL_HISTORY_UNAVAILABLE";return SBTradesToday(s,m,now,ref last);}
public static double SBGet(string k){return disk.ContainsKey(k)?disk[k]:0;}public static bool SBPut(string k,double v){if(!persist){sb_state_ok=false;return false;}disk[k]=v;return true;}
public static bool SBConsumed(int s,string id){return consumed.Contains(s+"/"+id);}public static bool SBConsume(int s,string id){if(!persist)return false;consumed.Add(s+"/"+id);return true;}
public static string SBStrategyKey(int s,string id){return s+"/"+id;}public static void GlobalVariablesFlush(){}
public static void SBHalt(string w){disk[sb_account+"halt"]=1;}public static ulong SBMagic(int s){return (ulong)(s==3?26103122:(s==1?26103120:26103121));}
public static void SBLogPlan(SBPlan p,string e,string d){}public static void SBEvent(int s,string e,string d){}public static void SBDrawPlan(SBPlan p){}
public static void ResetPlan(SBPlan p){p.entry=p.sl=p.tp=p.risk=p.volume=0;}
public static bool OrderCheck(MqlTradeRequest r,MqlTradeCheckResult c){return checkOK;}public static bool OrderSend(MqlTradeRequest r,MqlTradeResult result){sends++;result.retcode=sendCode;return sendOK;}
public static double MathMax(double a,double b){return System.Math.Max(a,b);}public static double MathAbs(double x){return System.Math.Abs(x);}public static double MathFloor(double x){return System.Math.Floor(x);}public static double MathCeil(double x){return System.Math.Ceiling(x);}
public static double MathMin(double a,double b){return System.Math.Min(a,b);}
public static string IntegerToString(long x){return x.ToString();}public static bool MathIsValidNumber(double x){return !double.IsNaN(x)&&!double.IsInfinity(x);}
public static int StringLen(string s){return s==null?0:s.Length;}
public static string StringFormat(string s,params object[] args){return s;}
public static void Assert(bool ok,string msg){checks++;if(!ok)throw new System.Exception("FAIL: "+msg);}
public static void Fixture(){InpRoundTripCommissionPerLot=0;InpShapeSetupBasedExits=InpSMTSetupBasedExits=false;InpShapeLegacyTriangle=false;InpEnableDailyRiskLock=true;vpEntries=0;vpLastExit=0;positions.Clear();disk.Clear();consumed.Clear();sb_state_ok=true;InpEmergency=false;InpTradingEnabled=true;InpSignalOnly=false;InpAllowRealAccount=false;InpUseFixedVolume=true;InpFixedVolume=.01;InpMaxTotalOpenPositions=2;InpMaxTradeRiskPercent=.25;InpMaxCombinedOpenRiskPercent=.5;hedge=true;real=false;permissions=true;session=true;fresh=true;history=true;checkOK=true;persist=true;sendOK=true;calcOK=true;equity=10000;free=9000;spread=.2;minVolume=.01;maxVolume=100;step=.01;volumeLimit=0;stops=freeze=0;fourTrades=triangleTrades=0;sends=0;lastFill=0;sendCode=TRADE_RETCODE_DONE;tradeMode=4;fillMode=1;executionMode=2;}
public static bool Plan(SBSignal s){riskChecks++;var plan=new SBPlan();string why="";return SBPlanTrade(s,plan,ref why);}
'@
$tests=@'
public static int Run(){
 Fixture();Assert(Plan(new SBSignal()),"valid fixed-volume BUY");
 var sell=new SBSignal();sell.direction=-1;sell.structural_sl=105;Assert(Plan(sell),"valid SELL");
 Fixture();real=true;Assert(!Plan(new SBSignal()),"real accounts denied by default");InpAllowRealAccount=true;Assert(Plan(new SBSignal()),"explicit real permission gating");
 Fixture();permissions=false;Assert(!Plan(new SBSignal()),"broker/terminal permission gate");
 Fixture();InpSignalOnly=true;SBExecute(new SBSignal());Assert(sends==0,"signal only cannot send");
 Fixture();InpTradingEnabled=false;Assert(!Plan(new SBSignal()),"trading disabled");
 Fixture();fresh=false;Assert(!Plan(new SBSignal()),"stale quote rejected");
 Fixture();session=false;Assert(!Plan(new SBSignal()),"session closed");
 Fixture();history=false;Assert(!Plan(new SBSignal()),"unavailable history cannot bypass counters");
 Fixture();disk[sb_account+"daily_lock"]=1;Assert(!Plan(new SBSignal()),"daily limit lock");
 Fixture();disk[sb_account+"halt"]=1;Assert(!Plan(new SBSignal()),"emergency latch");
 Fixture();disk[sb_account+"intent"]=26103120;Assert(!Plan(new SBSignal()),"unresolved pre-restart intent");
 Fixture();fourTrades=1;Assert(!Plan(new SBSignal()),"4H daily limit independent");var tri=new SBSignal();tri.strategy=2;Assert(Plan(tri),"4H daily counter does not block triangle");
 Fixture();triangleTrades=3;Assert(Plan(new SBSignal())&&!Plan(tri),"triangle daily counter does not block 4H");
 Fixture();lastFill=9990;Assert(!Plan(tri),"triangle cooldown");
 Fixture();positions.Add(new Pos());Assert(!Plan(new SBSignal())&&Plan(tri),"strategy positions independent on hedging");
 hedge=false;Assert(!Plan(tri),"netting blocks same symbol even different magic");
 Fixture();positions.Add(new Pos());positions.Add(new Pos(){symbol="OTHER",strategy=2});Assert(!Plan(tri),"shared total account position limit");
 Fixture();positions.Add(new Pos(){symbol="OTHER",sl=0});Assert(!Plan(new SBSignal()),"unprotected other EA exposure blocks without modification");Assert(positions[0].sl==0,"foreign position unchanged");
 Fixture();positions.Add(new Pos(){symbol="OTHER",volume=.2,sl=95});Assert(!Plan(new SBSignal()),"combined monetary risk budget");
 Fixture();InpFixedVolume=1;Assert(!Plan(new SBSignal()),"fixed volume actual monetary risk ceiling");
 Fixture();InpFixedVolume=.001;Assert(!Plan(new SBSignal()),"volume below minimum never rounded up");
 Fixture();volumeLimit=.005;Assert(!Plan(new SBSignal()),"broker directional volume limit");
 Fixture();spread=1;Assert(!Plan(new SBSignal()),"spread ceiling");
 Fixture();stops=1000;Assert(!Plan(new SBSignal()),"broker stop distance");
 Fixture();free=2500;Assert(!Plan(new SBSignal()),"free margin reserve");
 Fixture();var stale=new SBSignal();stale.candle=9000;Assert(!Plan(stale),"historical stale signal blocked");
 Fixture();sb_signal_after=10000;Assert(!Plan(new SBSignal()),"candle already closed at startup cannot enter");sb_signal_after=0;
 Fixture();var future=new SBSignal();future.candle=10000;Assert(!Plan(future),"unfinished candle cannot enter");
 Fixture();var wrong=new SBSignal();wrong.structural_sl=101;Assert(!Plan(wrong),"wrong-side SL rejected");
 Fixture();var large=new SBSignal();large.max_stop_points=10;Assert(!Plan(large),"oversized stop rejected");
 Fixture();var rr=new SBSignal();rr.rr=1.9;Assert(!Plan(rr),"minimum 2R enforced");
 Fixture();fillMode=0;int fill=0;Assert(!SBFilling(ref fill),"RETURN filling forbidden for market execution");executionMode=1;Assert(SBFilling(ref fill)&&fill==ORDER_FILLING_RETURN,"RETURN allowed on nonmarket execution");
 Fixture();SBExecute(new SBSignal());SBExecute(new SBSignal());Assert(sends==1,"same signal not resent");Assert(SBGet(sb_account+"intent")!=0,"fill awaits protection reconciliation");
 Fixture();sendCode=TRADE_RETCODE_DONE_PARTIAL;SBExecute(new SBSignal());SBExecute(new SBSignal());Assert(sends==1,"partial fills not resubmitted");
 Fixture();sendCode=10012;sendOK=false;SBExecute(new SBSignal());Assert(SBGet(sb_account+"halt")==1&&SBGet(sb_account+"intent")!=0,"timeout keeps WAL and halts");
 Fixture();sendCode=TRADE_RETCODE_INVALID_STOPS;sendOK=false;SBExecute(new SBSignal());Assert(sends==1&&SBGet(sb_account+"intent")==0,"definitive reject clears intent without retry");
 Fixture();persist=false;SBExecute(new SBSignal());Assert(sends==0,"persistence failure prevents send");
 Fixture();checkOK=false;SBExecute(new SBSignal());Assert(sends==0,"OrderCheck failure prevents send");
 Fixture();SBExecute(new SBSignal());disk[sb_account+"intent"]=0;positions.Add(new Pos());SBExecute(tri);Assert(sends==2,"two strategies can submit subject to refreshed shared exposure");
 Fixture();var orb=new SBSignal(){strategy=SB_ORB,orb_mode=1};orbTrades=0;
 Assert(Plan(orb),"ORB passes shared symbol-aware risk checks");
 orbTrades=2;Assert(!Plan(orb)&&Plan(new SBSignal())&&Plan(tri),"ORB daily counter independent of strategies 1 and 2");orbTrades=0;
 Fixture();hedge=false;positions.Add(new Pos(){strategy=2});Assert(!Plan(orb),"ORB cannot merge with another strategy on netting account");
 Fixture();positions.Add(new Pos(){strategy=2});Assert(Plan(orb),"ORB independent magic on hedging account");
 Fixture();freeze=1000;Assert(!Plan(orb)&&Plan(new SBSignal()),"ORB entry freeze check does not change strategy 1 rule");
 Fixture();SBExecute(orb);SBExecute(orb);Assert(sends==1,"ORB duplicate order prevention");
 Fixture();var smt=new SBSignal(){strategy=SB_SMT,rr=1};InpSMTSignalOnly=false;InpSMTUseMinimumRR=true;smtTarget=108;
 Assert(Plan(smt),"SMT dynamic target can yield less than 2R while legacy strategies retain 2R minimum");
 smtTarget=103;Assert(!Plan(smt),"SMT optional minimum blocks sub-1R");InpSMTUseMinimumRR=false;Assert(Plan(smt),"SMT optional minimum can be disabled without forcing 3R");
 smtTarget=99;Assert(!Plan(smt),"SMT wrong-side target rejected even with minimum RR disabled");
 Fixture();smtTarget=108;InpSMTUseMinimumRR=true;InpSMTSignalOnly=true;SBExecute(smt);Assert(sends==0,"SMT profile signal-only cannot send when global signal-only is false");
 Fixture();InpSMTSignalOnly=false;smtRevalidate=false;SBExecute(smt);Assert(sends==0,"SMT immediate pre-send revalidation failure cannot submit");smtRevalidate=true;
 Fixture();InpSMTMaxTradeRiskPercent=.01;Assert(!Plan(smt),"SMT fixed-volume actual monetary risk cap");InpSMTMaxTradeRiskPercent=.25;
 Fixture();hedge=false;positions.Add(new Pos(){strategy=2});Assert(!Plan(smt),"SMT netting cannot reduce or merge another strategy position");
 Fixture();InpSMTMaxSpreadPoints=1;Assert(!Plan(smt),"SMT independent spread cap still respects shared cap");InpSMTMaxSpreadPoints=50;
 Fixture();var shapeTriangle=new SBSignal(){strategy=SB_TRIANGLE,method="BREAKOUT_CONTINUATION",pattern_type=1};
 Assert(Plan(shapeTriangle),"new Triangle continuation preserves legacy fixed-RR execution with deviation allowance");
 Fixture();var shapeReverse=new SBSignal(){strategy=SB_TRIANGLE,method="TRAP_REVERSAL",rr=1,target=112};
 Assert(Plan(shapeReverse),"Shape reversal dynamic target allowed through shared risk");
 shapeReverse.target=105.4;Assert(!Plan(shapeReverse),"Shape reversal cost-adjusted nearest-target RR rejects borderline 1R");
 Fixture();InpMaxTotalOpenPositions=5;InpMaxCombinedOpenRiskPercent=1;var vp=new SBSignal(){strategy=SB_VP_POC,rr=1.5};
 positions.Add(new Pos(){strategy=1});Assert(Plan(vp),"S1 BUY does not block S5 BUY on hedging account");
 positions.Clear();positions.Add(new Pos(){strategy=2,side=1,sl=105});Assert(Plan(vp),"S2 SELL does not block S5 BUY on hedging account");
 for(int m=5;m<=7;m++){positions.Clear();positions.Add(new Pos(){strategy=m});Assert(!Plan(vp),"each S5 method occupies the same internal symbol slot");}
 positions.Clear();positions.Add(new Pos(){strategy=5});Assert(Plan(new SBSignal()),"S5 position does not impose a slot restriction on S1 hedging entries");
 hedge=false;Assert(!Plan(vp),"netting S5 conflict cannot modify another position");
 Fixture();vpEntries=5;Assert(!Plan(vp),"five actual entry orders cap each broker day");
 Fixture();vpLastExit=TimeCurrent()-899;Assert(!Plan(vp),"cooldown starts at completed trade exit");vpLastExit=TimeCurrent()-900;Assert(Plan(vp),"exact 15 minute completed-trade cooldown elapsed");
 Fixture();disk[sb_account+"daily_lock"]=1;Assert(!Plan(vp),"shared daily loss/baseline lock blocks S5");
 Fixture();InpMaxTotalOpenPositions=5;InpMaxCombinedOpenRiskPercent=1;positions.Add(new Pos(){strategy=1,volume=.19});Assert(!Plan(vp),"combined account open risk including S1 cannot exceed one percent");
 Fixture();InpFixedVolume=.1;Assert(!Plan(vp),"S5 does not exceed quarter-percent monetary risk");
 Fixture();vp.structural_sl=101;Assert(!Plan(vp),"invalid POC protective stop rejected without replacing structure");
 Fixture();vp.structural_sl=95;minVolume=.02;Assert(!Plan(vp),"below-broker-minimum volume is rejected without rounding risk upward");
 for(int strategy=1;strategy<=7;strategy++){
  Fixture();disk[sb_account+"daily_lock"]=1;var dailySignal=new SBSignal(){strategy=strategy,vp_val=100,vp_vah=100};
  Assert(!Plan(dailySignal),"enabled daily gate blocks each strategy/method");
  InpEnableDailyRiskLock=false;Assert(Plan(dailySignal),"explicit daily opt-out permits strategy/method "+strategy+" with persisted daily lock");
 }
 Fixture();InpEnableDailyRiskLock=false;disk[sb_account+"halt"]=1;Assert(!Plan(new SBSignal()),"daily opt-out cannot bypass emergency/drawdown latch");
 Fixture();InpEnableDailyRiskLock=false;InpEmergency=true;Assert(!Plan(new SBSignal()),"daily opt-out cannot bypass emergency input");
 Fixture();InpEnableDailyRiskLock=false;disk[sb_account+"intent"]=1;Assert(!Plan(new SBSignal()),"daily opt-out cannot bypass pending intent");
 Fixture();InpEnableDailyRiskLock=false;fourTrades=1;Assert(!Plan(new SBSignal()),"strategy daily entry cap retained when daily loss gate disabled");
 Fixture();InpEnableDailyRiskLock=false;InpFixedVolume=1;Assert(!Plan(new SBSignal()),"per-trade monetary risk retained with daily lock disabled");
 Fixture();InpEnableDailyRiskLock=false;positions.Add(new Pos(){symbol="OTHER",volume=.2,sl=95});Assert(!Plan(new SBSignal()),"combined open-risk cap retained with daily lock disabled");
 // New mode is strategy-specific; geometry is structural and monetary safeguards remain.
 Fixture();InpShapeSetupBasedExits=true;
 var structuralShape=new SBSignal(){strategy=SB_TRIANGLE,method="BREAKOUT_CONTINUATION",pattern_type=1,target=101,max_stop_points=10};
 var structuralPlan=new SBPlan();string structuralWhy="";
 Assert(SBPlanTrade(structuralShape,structuralPlan,ref structuralWhy),"setup Shape triangle accepts structural target below 1R and wide stop");
 Assert(structuralPlan.tp==101 && structuralPlan.signal.rr<1 && structuralPlan.signal.max_stop_points==0,"Shape stores actual structural RR and durable zero stop-cap marker");
 InpShapeSetupBasedExits=false;Assert(!Plan(structuralShape),"disabled mode preserves original Shape stop ceiling");
 structuralShape.max_stop_points=1000;Assert(!Plan(structuralShape),"disabled mode preserves triangle 2R minimum");
 Fixture();InpShapeSetupBasedExits=true;InpSMTSetupBasedExits=true;
 Assert(!Plan(new SBSignal(){max_stop_points=10}),"Shape/SMT modes cannot relax S1 stop ceiling");
 Assert(!Plan(new SBSignal(){strategy=SB_ORB,max_stop_points=10}),"Shape/SMT modes cannot relax ORB stop ceiling");
 Assert(!Plan(new SBSignal(){strategy=SB_VP_POC,max_stop_points=10}),"Shape/SMT modes cannot relax S5 stop ceiling");
 Assert(!Plan(new SBSignal(){strategy=SB_TRIANGLE,max_stop_points=10}),"legacy triangle without Shape method retains ceiling");
 structuralShape.max_stop_points=10;structuralShape.target=101;
 InpFixedVolume=1;Assert(!Plan(structuralShape),"setup mode cannot bypass monetary risk with wide structural stop");
 Fixture();InpShapeSetupBasedExits=true;InpUseFixedVolume=false;structuralShape.structural_sl=80;
 structuralPlan=new SBPlan();Assert(SBPlanTrade(structuralShape,structuralPlan,ref structuralWhy) && structuralPlan.volume==.01 && structuralPlan.risk<=25,"wide structural stop reduces risk-sized volume");
 structuralShape.structural_sl=1;Assert(!Plan(structuralShape),"too-small risk-sized volume rejected rather than rounded up");
 Fixture();InpShapeSetupBasedExits=true;structuralShape.structural_sl=95;structuralShape.target=101;
 InpRoundTripCommissionPerLot=200;Assert(!Plan(structuralShape),"positive gross target cannot bypass negative net reward");
 Fixture();InpSMTSetupBasedExits=true;InpSMTUseMinimumRR=true;smtTarget=101;
 var structuralSMT=new SBSignal(){strategy=SB_SMT,rr=1,max_stop_points=10};
 structuralPlan=new SBPlan();Assert(SBPlanTrade(structuralSMT,structuralPlan,ref structuralWhy) && structuralPlan.tp==101 && structuralPlan.signal.rr<1 && structuralPlan.signal.max_stop_points==0,"setup SMT uses nearby target despite legacy minimum and point cap");
 smtTarget=100;Assert(!Plan(structuralSMT),"setup SMT still rejects wrong-side target");
 smtTarget=101;InpRoundTripCommissionPerLot=200;Assert(!Plan(structuralSMT),"setup SMT requires positive net reward");
 Fixture();InpSMTSetupBasedExits=true;smtTarget=101;disk[sb_account+"halt"]=1;Assert(!Plan(structuralSMT),"setup mode retains emergency halt");
 Fixture();InpShapeSetupBasedExits=true;permissions=false;Assert(!Plan(structuralShape),"setup mode retains trading permissions");
 Assert(SBRecordedSetupExits(SB_TRIANGLE,"SHAPE_M15_M5",0) && SBRecordedSetupExits(SB_SMT,"SMT_MTF",0),"recorded setup policy survives independently of runtime switches");
 Assert(!SBRecordedSetupExits(SB_TRIANGLE,"LEGACY_TRIANGLE",0) && !SBRecordedSetupExits(SB_ORB,"DEFAULT",0) && !SBRecordedSetupExits(SB_TRIANGLE,"SHAPE_M15_M5",250),"old requests and other strategies cannot acquire setup-mode reconciliation");
 return checks;
}
'@
Add-Type -TypeDefinition ("public static class ScalpingRisk {`n"+$mock+$code+$tests+"`n}")
$count=[ScalpingRisk]::Run()
Write-Output "PASS: $count assertions against production risk/execution functions (C# syntax adaptation; all broker/state APIs mocked; no orders sent)."


