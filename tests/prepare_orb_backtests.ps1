param(
 [string]$TerminalInstallation='C:\Users\C00567\AppData\Roaming\MetaTrader 5',
 [string]$CacheTerminal='C:\Users\C00567\AppData\Roaming\MetaQuotes\Terminal\16E88504E6323783A450F87A361BF087',
 [string]$Server='MetaQuotes-Demo',[long]$CacheLogin=112306962,
 [string]$From='2026.08.03',[string]$To='2026.08.05',
 [string[]]$Symbols=@('EURUSD','XAUUSD','GBPUSD','USDJPY'),[int]$AssumedBrokerUTCMinutes=180
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
$terminal=Join-Path $root 'artifacts/test-terminal'
$output=Join-Path $root ('artifacts/orb-v1/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
if(Test-Path -LiteralPath "$output/matrix.json"){throw 'Preserve existing ORB evidence; use a new output folder.'}
if(@(Get-Process -Name terminal64,metatester64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -and $_.Path.StartsWith($terminal+'\',[StringComparison]::OrdinalIgnoreCase)}).Count){throw 'Stop only the isolated tester before preparing a new matrix.'}
New-Item -ItemType Directory -Force -Path $output,"$terminal/Config","$terminal/MQL5/Experts","$terminal/MQL5/Profiles/Tester","$terminal/bases/$Server/symbols" | Out-Null
foreach($file in @('terminal64.exe','metatester64.exe')){Copy-Item -LiteralPath "$TerminalInstallation/$file" -Destination "$terminal/$file" -Force}
Copy-Item -LiteralPath "$CacheTerminal/config/servers.dat" -Destination "$terminal/Config/servers.dat" -Force
Get-ChildItem -LiteralPath "$CacheTerminal/bases/$Server/symbols" -File | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination "$terminal/bases/$Server/symbols" -Force}
Copy-Item -LiteralPath "$root/MQL5/Experts/ScalpingBot.ex5" -Destination "$terminal/MQL5/Experts/ScalpingBot.ex5" -Force
Copy-Item -LiteralPath "$PSScriptRoot/ORBTests.ex5" -Destination "$terminal/MQL5/Experts/ORBTests.ex5" -Force
function Copy-ReadOnlyCache([string]$Source,[string]$Destination){
 $before=Get-Item -LiteralPath $Source
 $length=$before.Length;$stamp=$before.LastWriteTimeUtc
 $src=[IO.File]::Open($Source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
 try{$dst=[IO.File]::Open($Destination,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$src.CopyTo($dst)}finally{$dst.Dispose()}}finally{$src.Dispose()}
 $after=Get-Item -LiteralPath $Source
 if($after.Length -ne $length -or $after.LastWriteTimeUtc -ne $stamp){throw 'Market source changed during snapshot.'}
}
$matrix=@();$cache=@()
foreach($symbol in $Symbols){
 foreach($kind in @('history','ticks')){
  $destination="$terminal/bases/$Server/$kind/$symbol";New-Item -ItemType Directory -Force -Path $destination | Out-Null
  foreach($file in Get-ChildItem -LiteralPath "$CacheTerminal/bases/$Server/$kind/$symbol" -File -ErrorAction SilentlyContinue){
   if($file.Name -notin @('2026.hcc','ticks.dat','202608.tkc')){continue}
   $source=$file.FullName
   try{Copy-ReadOnlyCache $source "$destination/$($file.Name)"}catch{
    $fallback=Join-Path (Split-Path $root -Parent) "artifacts/mt5/trend-execution/terminal/bases/$Server/$kind/$symbol/$($file.Name)"
    if(!(Test-Path -LiteralPath $fallback)){
     $cache+=[pscustomobject]@{symbol=$symbol;kind=$kind;file=$file.Name;source=$source;status='UNAVAILABLE_LOCKED_BY_EXISTING_TERMINAL'}
     continue
    };$source=$fallback;Copy-ReadOnlyCache $source "$destination/$($file.Name)"
   }
   $cache+=[pscustomobject]@{symbol=$symbol;kind=$kind;file=$file.Name;source=$source;status='COPIED_READ_ONLY'}
  }
 }
 $modes=@('four-hour','triangle','orb-continuation','orb-reversal','combined')
 if($symbol -eq $Symbols[0]){$modes=@('orb-unit')+$modes}
 foreach($mode in $modes){
  $id=$symbol.ToLower()+'-'+$mode;$values=[ordered]@{}
  foreach($line in Get-Content -LiteralPath "$root/profiles/scalping-bot-$($symbol.ToLower())-demo.set"){
   if($line -match '^(Inp\w+)=(.*)$'){$values[$matches[1]]=$matches[2]}
  }
  $values.InpEnable4HBreakout=if($mode -in @('four-hour','combined')){'true'}else{'false'}
  $values.InpEnableTriangleMethod=if($mode -in @('triangle','combined')){'true'}else{'false'}
  $values.InpEnableORBStrategy=if($mode -in @('orb-continuation','orb-reversal','combined')){'true'}else{'false'}
  $values.InpORBEnableContinuation=if($mode -eq 'orb-reversal'){'false'}else{'true'}
  $values.InpORBEnableFalseBreakout=if($mode -eq 'orb-continuation'){'false'}else{'true'}
  $values.InpSignalOnly='false';$values.InpBrokerTimeVerified='true';$values.InpBrokerDSTRule='0'
  $values.InpBrokerWinterUTCMinutes=[string]$AssumedBrokerUTCMinutes;$values.InpBrokerSummerUTCMinutes=[string]$AssumedBrokerUTCMinutes
  $values.InpShowPanel='false';$values.InpDrawObjects='false'
  @('; ISOLATED TESTER SIMULATION ONLY; assumed historical broker UTC mapping.')+@($values.Keys | ForEach-Object {$_+'='+$values[$_]}) | Set-Content -LiteralPath "$terminal/MQL5/Profiles/Tester/$id.set" -Encoding ASCII
  $expert=if($mode -eq 'orb-unit'){'ORBTests.ex5'}else{'ScalpingBot.ex5'}
  $ini=@"
[Common]
Login=$CacheLogin
Server=$Server
KeepPrivate=1
[Experts]
Enabled=0
AllowLiveTrading=0
AllowDllImport=0
[Tester]
Expert=$expert
ExpertParameters=$id.set
Symbol=$symbol
Period=M5
Login=$CacheLogin
Model=4
ExecutionMode=100
Optimization=0
FromDate=$From
ToDate=$To
ForwardMode=0
Deposit=10000
Currency=USD
Leverage=100
UseLocal=1
UseRemote=0
UseCloud=0
Visual=0
Report=$id.htm
ReplaceReport=0
ShutdownTerminal=1
Port=32311
"@
  $config=Join-Path $output "$id.ini";$ini | Set-Content -LiteralPath $config -Encoding ASCII
  $matrix+=[pscustomobject]@{id=$id;symbol=$symbol;mode=$mode;from=$From;to=$To;requested_model='REAL_TICKS';assumed_broker_utc_minutes=$AssumedBrokerUTCMinutes;config=$config;report=(Join-Path $output $id);expert=$expert;status='PREPARED_NOT_RUN'}
 }
}
$matrix | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$output/matrix.json" -Encoding UTF8
$cache | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$output/cache-status.json" -Encoding UTF8
Write-Output "Prepared $($matrix.Count) isolated ORB/regression tests. Existing evidence preserved. Matrix: $output/matrix.json"
