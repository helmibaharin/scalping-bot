$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$inc=Join-Path $root 'MQL5/Include/ScalpingBot'
# Run actual production decision functions, adapting only MQL syntax/API boundaries to C#.
# This is not a substitute for the separate native MQL compilation or tick backtests.
$inputs=''
foreach($line in Get-Content "$inc/Config.mqh") {
 if($line -match '^input\s+(\w+)\s+(Inp\w+)=(.+);$') {
  $type=$matches[1];$name=$matches[2];$value=$matches[3]
  if($type -eq 'datetime'){$type='long';$value="Date(`""+$value.Substring(2).TrimEnd("'")+"`" )"}
  if($type -eq 'SB_BROKER_DST' -or $type -eq 'ENUM_TIMEFRAMES'){$type='int'}
  $inputs+="public static $type $name=$value;`n"
 }
}
$rules=Get-Content "$inc/Rules.mqh" -Raw
$time=Get-Content "$inc/NewYorkTime.mqh" -Raw
$time=$time.Substring(0,$time.IndexOf('string SBTradeCountText'))
$resistance=Get-Content "$inc/ResistanceDetector.mqh" -Raw
$ob=Get-Content "$inc/OrderBlockDetector.mqh" -Raw
$detector=Get-Content "$inc/TriangleDetector.mqh" -Raw
$triangle=Get-Content "$inc/TriangleMethod.mqh" -Raw
$triangle=$triangle.Substring(0,$triangle.IndexOf('void SBEvaluateTriangle'))
# C# prohibits reuse of a parent's local name in a preceding child scope.
$detectStart=$triangle.IndexOf('      SBTriangle p={};')
$detectEnd=$triangle.IndexOf('   SBTriangle p=sb_triangle.pattern;')
$triangle=$triangle.Substring(0,$detectStart)+($triangle.Substring($detectStart,$detectEnd-$detectStart) -replace '\bp\b','detected')+$triangle.Substring($detectEnd)
$code=($rules+$time+$resistance+$ob+$detector+$triangle) -replace '(?m)^#.*$',''
$code=$code -replace 'string &(why)','ref string $1' -replace 'string error;','string error="";' -replace 'string why;','string why="";'
$code=$code -replace 'SBMappingConfigValid\(error\)','SBMappingConfigValid(ref error)'
$code=$code -replace 'SBUTCToServerChecked\(utc,server,why\)','SBUTCToServerChecked(utc,ref server,ref why)'
$code=$code -replace 'SBServerToUTCChecked\(server,utc,why\)','SBServerToUTCChecked(server,ref utc,ref why)'
$code=$code -replace 'int offsets\[\];','int[] offsets=new int[0];' -replace 'ArrayCopy\(offsets,sb_mapping_offsets\)','offsets=(int[])sb_mapping_offsets.Clone()'
$code=$code -replace 'ArrayResize\(offsets,InpBrokerDSTRule==SB_FIXED\?1:2\)','System.Array.Resize(ref offsets,InpBrokerDSTRule==SB_FIXED?1:2)' -replace 'ArraySize\(offsets\)','offsets.Length'
$code=$code -replace '\bdatetime\b','long' -replace '(?m)^(bool|int|double|void|long) ','public static $1 '
$code=$code -replace 'MqlRates &bars\[\]','MqlRates[] bars' -replace 'SBTriangle &p','ref SBTriangle p'
$code=$code -replace '(SBUpper|SBLower)\(ref SBTriangle p','$1(SBTriangle p'
$code=$code -replace 'int &side','ref int side' -replace 'double &extreme','ref double extreme'
$code=$code -replace 'double &stop','ref double stop' -replace 'long &origin','ref long origin' -replace 'double &zone_low','ref double zone_low' -replace 'double &zone_high','ref double zone_high'
$code=$code -replace 'long &(local|day|midnight_utc|server|utc)','ref long $1'
$code=$code -replace 'MqlDateTime t=\{\};','MqlDateTime t=new MqlDateTime();' -replace 'MqlDateTime t;','MqlDateTime t=new MqlDateTime();'
$code=$code -replace 'long local;','long local=0;' -replace 'long check;','long check=0;' -replace ',back;',',back=0;'
$code=$code -replace ',local\)',',ref local)' -replace ',check\)',',ref check)' -replace ',back\)',',ref back)'
$code=$code -replace 'int offsets\[2\];','int[] offsets=new int[2];' -replace 'int highs\[\],lows\[\];','int[] highs=new int[0],lows=new int[0];'
$code=$code -replace 'ArraySize\((highs|lows)\)','$1.Length' -replace 'ArrayResize\((highs|lows),n\+1\)','System.Array.Resize(ref $1,n+1)'
$code=$code -replace '(SBTriangle|SBSignal) (\w+)=\{\};','$1 $2=new $1();'
$code=$code -replace 'ZeroMemory\(sb_triangle\)','sb_triangle=new SBTriangleState()'
$code=$code -replace '(?m)^SBTriangleState sb_triangle;',''
$code=$code -replace 'SBDetectTriangle\(bars,end,detected\)','SBDetectTriangle(bars,end,ref detected)'
$mock=@'
public const int PERIOD_D1=16408,PERIOD_H4=16388,PERIOD_H1=16385,PERIOD_M15=15,PERIOD_M1=1;
public const int SB_FIXED=0,SB_EU=1,SB_US=2,PERIOD_M5=5,SB_ASCENDING=1,SB_DESCENDING=2,SB_SYMMETRICAL=3,SB_4H=1,SB_TRIANGLE=2;
// These legacy C# tests cover built-in calendar conversion. Table parsing/validation is native-tested separately.
public const int SB_UTC_TABLE=3;public static int[] sb_mapping_offsets=new int[0];
public static bool SBMappingConfigValid(ref string why){why="";return true;}
public static int SBTableOffset(long utc){throw new System.NotSupportedException("UTC table requires native fixture");}
public const double DBL_MAX=double.MaxValue;
public static double _Point=1;public static string _Symbol="TEST.suffix";
public class MqlDateTime { public int year,mon,day,hour,min,sec,day_of_week; }
public struct MqlRates { public long time;public double open,high,low,close; }
public struct SBTriangle { public int type;public long h1,h2,l1,l2,formed;public double hp1,hp2,lp1,lp2,apex;public string id; }
public struct SBTriangleState { public SBTriangle pattern;public int phase,direction;public long breakout,retest;public double retest_low,retest_high; }
public struct SBSignal { public int strategy,direction,pattern_type;public long candle;public string id,sl_method;public double structural_sl,rr,max_stop_points; }
public static SBTriangleState sb_triangle;
public static System.Collections.Generic.HashSet<string> used=new System.Collections.Generic.HashSet<string>();
public static int signals=0,checks=0;public static SBSignal captured;
public static long Date(string x) { return new System.DateTimeOffset(System.DateTime.SpecifyKind(System.DateTime.ParseExact(x.Trim(),"yyyy.MM.dd HH:mm",System.Globalization.CultureInfo.InvariantCulture),System.DateTimeKind.Utc)).ToUnixTimeSeconds(); }
public static long StructToTime(MqlDateTime t) { return new System.DateTimeOffset(t.year,t.mon,t.day,t.hour,t.min,t.sec,System.TimeSpan.Zero).ToUnixTimeSeconds(); }
public static bool TimeToStruct(long x,MqlDateTime t) { try {var d=System.DateTimeOffset.FromUnixTimeSeconds(x);t.year=d.Year;t.mon=d.Month;t.day=d.Day;t.hour=d.Hour;t.min=d.Minute;t.sec=d.Second;t.day_of_week=(int)d.DayOfWeek;return true;}catch{return false;} }
public static int MathMax(int a,int b){return System.Math.Max(a,b);} public static double MathMax(double a,double b){return System.Math.Max(a,b);}
public static int MathMin(int a,int b){return System.Math.Min(a,b);} public static double MathMin(double a,double b){return System.Math.Min(a,b);}
public static double MathAbs(double x){return System.Math.Abs(x);}public static double MathFloor(double x){return System.Math.Floor(x);}public static double MathCeil(double x){return System.Math.Ceiling(x);}
public static double SymbolInfoDouble(string s,int p){return .01;}public const int SYMBOL_TRADE_TICK_SIZE=1;
public static int PeriodSeconds(int tf){return tf*60;}
public static string IntegerToString(long x){return x.ToString();}
public static string SBId(string x){return x;} // Identity payload is retained for assertions; hashing is native-compiled separately.
public static bool SBConsumed(int s,string id){return used.Contains(id);}
public static bool SBConsume(int s,string id){used.Add(id);return true;}
public static string SBPatternName(int t){return t.ToString();}
public static void SBEvent(int s,string e,string d){}
public const int clrTomato=0,clrDodgerBlue=1,clrOrange=2,clrAqua=3,clrLimeGreen=4;
public static void SBTrend(string id,long t1,double p1,long t2,double p2,int color){}
public static void SBMarker(int strategy,string id,long time,double price,int color){}
public static void SBExecute(SBSignal s){signals++;captured=s;used.Add(s.id);}
public static void Assert(bool ok,string message){checks++;if(!ok)throw new System.Exception("FAIL: "+message);}
public static MqlRates[] Formation(int type) {
 var b=new MqlRates[40];long start=Date("2026.10.20 12:00");
 for(int i=0;i<b.Length;i++) {
  double u=type==1?110:(type==2?120-i*.6666666667:120-i*.5);
  double l=type==2?90:(type==1?86.6666666667+i*.6666666667:80+i*.5);
  b[i].time=start+i*300;b[i].open=b[i].close=(u+l)/2;b[i].high=u-2;b[i].low=l+2;
  if(i==2||i==8||i==14)b[i].high=u;
  if(i==5||i==11||i==17)b[i].low=l;
 }
 return b;
}
public static void TriangleSettings() {
 InpTriangleHorizontalTolerancePoints=.5;InpTriangleMinHeightPoints=5;InpTriangleMinSeparationBars=3;
 InpTriangleMinDurationBars=8;InpTriangleMaxDurationBars=60;InpTriangleMinTouches=2;
 InpTriangleMinConvergence=.15;InpTriangleMinApexBars=2;InpTriangleMaxApexBars=100;
 InpTriangleBreakoutClearancePoints=.1;InpTriangleRetestTolerancePoints=.5;InpTriangleInvalidationPoints=1;
 InpTriangleStopBufferPoints=1;InpEnableAscendingTriangle=InpEnableDescendingTriangle=InpEnableSymmetricalTriangle=true;
 InpTriangleRequireDirectionalBody=true;InpTriangleMaxRetestBars=12;
 used.Clear();signals=0;sb_triangle=new SBTriangleState();
}
'@
$tests=@'
public static int Run() {
 Assert(!SBUpperBody(99,100,100,.01),"wick-only upper rejected");
 Assert(SBUpperBody(99,101,100,.01),"upper body crossing");
 Assert(!SBUpperBody(102,103,100,.01),"outside upper body not new breakout");
 Assert(SBLowerBody(101,99,100,.01),"lower body crossing");
 Assert(!SBLowerBody(98,97,100,.01),"outside lower body rejected");
 Assert(!SBInside(100,90,100,.01)&&SBInside(99,90,100,.01),"return strictly inside");
 int side=0;double extreme=0;
 Assert(SB4HStep(ref side,ref extreme,100,113,99,111,90,110,.01)==1 && side==1,"upper starts SELL setup");
 for(int i=0;i<150;i++)Assert(SB4HStep(ref side,ref extreme,115,120+i,114,118,90,110,.01)==0 && side==1,"no candle-count/extension expiry");
 Assert(SB4HStep(ref side,ref extreme,115,280,95,100,90,110,.01)==3 && extreme==280,"return candle included in frozen excursion");
 side=0;extreme=0;Assert(SB4HStep(ref side,ref extreme,95,96,80,85,90,110,.01)==2 && side==-1,"lower starts BUY setup");
 Assert(SB4HStep(ref side,ref extreme,85,105,75,100,90,110,.01)==3 && extreme==75,"BUY return excursion");
 side=1;extreme=120;Assert(SB4HStep(ref side,ref extreme,115,116,80,85,90,110,.01)==4 && side==0,"opposite boundary invalidates without reverse");
 Assert(SBTarget(1,100,95,2)==110 && SBTarget(-1,100,105,2)==90,"final stop 2R targets");
 Assert(System.Math.Abs(SBVolumeFloor(.019,.01)-.01)<1e-9,"volume never rounded up");
 Assert(SBRoundPrice(100.03,.05,1)>=100.03 && SBRoundPrice(100.03,.05,-1)<=100.03,"tick rounding outward");
 Assert(SBAccountingAllows(true,true,1,2),"hedging permits independent second position");
 Assert(!SBAccountingAllows(false,true,1,2),"netting collision denied");
 Assert(!SBAccountingAllows(true,false,2,2),"shared position limit");
 Assert(SBAccountingAllows(false,false,0,2),"empty netting symbol permitted");
 long local=0,day=0,midnight=0,utc=0,server=0;
 Assert(SBNYLocal(Date("2026.03.08 06:59"),ref local)&&local==Date("2026.03.08 01:59"),"EST before spring transition");
 Assert(SBNYLocal(Date("2026.03.08 07:00"),ref local)&&local==Date("2026.03.08 03:00"),"EDT spring gap");
 Assert(SBNYLocal(Date("2026.11.01 05:59"),ref local)&&local==Date("2026.11.01 01:59"),"EDT before fall fold");
 Assert(SBNYLocal(Date("2026.11.01 06:00"),ref local)&&local==Date("2026.11.01 01:00"),"EST fall repeated hour");
 Assert(!SBUSDST(Date("2006.03.20 12:00")) && SBUSDST(Date("2006.04.02 07:00")),"pre-2007 historical US rule");
 Assert(!SBNYLocal(Date("1986.01.01 00:00"),ref local),"unsupported historical years fail closed");
 Assert(SBNYDay(Date("2026.03.08 12:00"),ref day,ref midnight)&&midnight==Date("2026.03.08 05:00"),"spring midnight uses previous offset");
 SBNYLocal(midnight+14400,ref local);Assert(local!=day+14400,"spring 00-04 four-H1 mismatch safely identifiable");
 Assert(SBNYDay(Date("2026.11.01 12:00"),ref day,ref midnight)&&midnight==Date("2026.11.01 04:00"),"fall midnight uses previous offset");
 SBNYLocal(midnight+14400,ref local);Assert(local!=day+14400,"fall 00-04 four-H1 mismatch");
 InpBrokerTimeVerified=false;Assert(!SBUTCToServer(Date("2026.10.01 12:00"),ref server),"unverified mapping disabled");
 InpBrokerTimeVerified=true;InpBrokerDSTRule=SB_EU;InpBrokerWinterUTCMinutes=120;InpBrokerSummerUTCMinutes=180;
 Assert(!SBServerToUTC(Date("2026.10.25 03:30"),ref utc),"ambiguous broker fall fold rejected");
 Assert(!SBServerToUTC(Date("2026.03.29 03:30"),ref utc),"nonexistent broker spring hour rejected");
 Assert(SBUTCToServer(Date("2026.07.01 12:00"),ref server)&&server==Date("2026.07.01 15:00"),"EU summer offset");
 Assert(SBServerToUTC(server,ref utc)&&utc==Date("2026.07.01 12:00"),"broker UTC roundtrip");
 Assert(!SBUTCToServer(Date("2050.01.01 00:00"),ref server),"mapping validity bound");
 TriangleSettings();
 for(int type=1;type<=3;type++) {
  var b=Formation(type);var p=new SBTriangle();
  Assert(SBDetectTriangle(b,20,ref p)&&p.type==type,"confirmed triangle classification "+type);
  long latest=System.Math.Max(p.h2,p.l2);Assert(latest<=b[18].time,"pivot right confirmation available before detection");
  var p2=new SBTriangle();Assert(SBDetectTriangle(b,20,ref p2)&&p.id==p2.id,"stable pattern identity");
  Assert(SBTriangleBreak(100,110,90,112,110,90,.1)==1 && SBTriangleBreak(100,110,90,88,110,90,.1)==-1,"either direction independent of triangle type");
  for(int dir=-1;dir<=1;dir+=2) {
   TriangleSettings();b=Formation(type);SBTriangleBar(b,20,true,false);Assert(sb_triangle.phase==1 && signals==0,"detected pattern no immediate entry");
   double line=dir>0?SBUpper(sb_triangle.pattern,b[21].time):SBLower(sb_triangle.pattern,b[21].time);
   b[21].open=line-dir*.5;b[21].close=line+dir*2;b[21].high=System.Math.Max(b[21].open,b[21].close)+.5;b[21].low=System.Math.Min(b[21].open,b[21].close)-.5;
   SBTriangleBar(b,21,true,false);Assert(sb_triangle.phase==2 && signals==0,"breakout waits for retest type/dir "+type+"/"+dir);
   line=dir>0?SBUpper(sb_triangle.pattern,b[22].time):SBLower(sb_triangle.pattern,b[22].time);
   b[22].open=line+dir;b[22].close=line+dir*.5;b[22].high=line+1.5;b[22].low=line-1.5;
   SBTriangleBar(b,22,true,false);Assert(sb_triangle.phase==3 && signals==0,"wick touch only confirms retest");
   line=dir>0?SBUpper(sb_triangle.pattern,b[23].time):SBLower(sb_triangle.pattern,b[23].time);
   b[23].open=line+dir;b[23].close=line+dir*2;b[23].high=System.Math.Max(b[23].open,b[23].close)+.2;b[23].low=System.Math.Min(b[23].open,b[23].close)-.2;
   SBTriangleBar(b,23,true,false);Assert(signals==1 && captured.direction==dir && captured.rr>=2,"distinct continuation confirmed type/dir "+type+"/"+dir);
   Assert(dir>0?captured.structural_sl<b[22].low:captured.structural_sl>b[22].high,"structural retest stop");
   string traded=captured.id;SBTriangleBar(b,20,true,false);Assert(signals==1 && used.Contains(traded),"duplicate pattern suppressed");
  }
 }
 TriangleSettings();var bad=Formation(1);for(int i=0;i<bad.Length;i++)bad[i].low=80;
 var invalid=new SBTriangle();Assert(!SBDetectTriangle(bad,20,ref invalid),"unconfirmed/degenerate lows rejected");
 Assert(!SBConverges(10,-1,1,.1,20,2,100)&&!SBConverges(10,11,1,.1,20,2,100),"crossed/diverging geometry rejected");
 Assert(!SBConverges(10,5,1,.1,1,2,100),"too close apex rejected");
 Assert(SBTriangleBreak(100,110,90,109,110,90,.1)==0,"triangle wick-only no close break");
 Assert(SBTriangleFailed(1,108,110,1)&&SBTriangleFailed(-1,92,90,1),"failed retest both directions");
 TriangleSettings();var timeout=Formation(1);SBTriangleBar(timeout,20,true,false);sb_triangle.phase=2;sb_triangle.direction=1;sb_triangle.breakout=timeout[20].time;
 SBTriangleBar(timeout,33,true,false);Assert(signals==0 && sb_triangle.phase==0,"retest timeout does not chase");
 TriangleSettings();InpEnableAscendingTriangle=false;var disabled=Formation(1);invalid=new SBTriangle();Assert(!SBDetectTriangle(disabled,20,ref invalid),"individual triangle switch");InpEnableAscendingTriangle=true;
 var levels=new MqlRates[10];for(int i=0;i<10;i++){levels[i].time=Date("2026.10.20 12:00")+i*300;levels[i].high=103;levels[i].low=99;levels[i].open=100;levels[i].close=101;}
 levels[2].high=levels[6].high=105;InpStructurePivotStrength=1;InpResistanceMinTouches=2;InpResistanceTolerancePoints=.5;Inp4HStopBufferPoints=1;Inp4HMaxStopPoints=10;
 double stop=0,zl=0,zh=0;long origin=0;
 Assert(SBResistance(levels,9,100,ref stop,ref origin,ref zl,ref zh)&&stop==106,"SELL confirmed resistance fallback");
 levels[9].close=107;Assert(!SBResistance(levels,9,100,ref stop,ref origin,ref zl,ref zh),"broken resistance rejected");
 for(int i=0;i<10;i++){levels[i].open=105;levels[i].close=106;levels[i].high=107;levels[i].low=104;}
 levels[2].open=101;levels[2].close=100;levels[2].low=99;levels[2].high=102;
 levels[3].open=101;levels[3].close=106;levels[3].low=100;levels[3].high=107;
 Assert(SBBullishOrderBlock(levels,9,108,ref stop,ref origin,ref zl,ref zh)&&stop==98,"BUY confirmed displacement order block fallback");
 levels[8].low=98;Assert(!SBBullishOrderBlock(levels,9,108,ref stop,ref origin,ref zl,ref zh),"invalidated order block rejected");
 return checks;
}
'@
$adapted=("public static class ScalpingRules {`n"+$inputs+$mock+$code+$tests+"`n}") -creplace '\bsb_triangle\b','triangle_state'
Add-Type -TypeDefinition $adapted
$count=[ScalpingRules]::Run()
Write-Output "PASS: $count deterministic assertions against production rules, timezone, structure, triangle detector and retest state machine (C# syntax adaptation; mocked terminal APIs)."
