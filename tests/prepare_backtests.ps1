param(
 [string]$TerminalInstallation='C:\Users\C00567\AppData\Roaming\MetaTrader 5',
 [string]$CacheTerminal='C:\Users\C00567\AppData\Roaming\MetaQuotes\Terminal\16E88504E6323783A450F87A361BF087',
 [string]$Server='MetaQuotes-Demo',
 [long]$CacheLogin=112306962,
 [string]$From='2026.08.03',
 [string]$To='2026.08.05',
 [int]$AssumedBrokerUTCMinutes=180
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Copy-MarketSnapshot([string]$Source,[string]$Destination) {
 $before=Get-Item -LiteralPath $Source
 $sourceStamp=$before.LastWriteTimeUtc;$sourceLength=$before.Length
 $inputStream=[IO.File]::Open($Source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
 try {
  $outputStream=[IO.File]::Open($Destination,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try {$inputStream.CopyTo($outputStream)} finally {$outputStream.Dispose()}
 } finally {$inputStream.Dispose()}
 $after=Get-Item -LiteralPath $Source
 if($after.Length -ne $sourceLength -or $after.LastWriteTimeUtc -ne $sourceStamp){throw "Market cache changed during snapshot: $Source. Retry preparation."}
}
$terminal=Join-Path $root 'artifacts/test-terminal'
New-Item -ItemType Directory -Force -Path $terminal,"$terminal/Config","$terminal/MQL5/Experts","$terminal/MQL5/Profiles/Tester","$terminal/bases/$Server/symbols","$root/artifacts/backtests" | Out-Null
foreach($file in @('terminal64.exe','metatester64.exe')){Copy-Item -LiteralPath (Join-Path $TerminalInstallation $file) -Destination (Join-Path $terminal $file) -Force}
# Copy only market/symbol caches and endpoint metadata. Never copy accounts/passwords or existing EAs.
Copy-Item -LiteralPath "$CacheTerminal/config/servers.dat" -Destination "$terminal/Config/servers.dat" -Force
Get-ChildItem -LiteralPath "$CacheTerminal/bases/$Server/symbols" -File | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination "$terminal/bases/$Server/symbols" -Force}
Copy-Item -LiteralPath "$root/MQL5/Experts/ScalpingBot.ex5" -Destination "$terminal/MQL5/Experts/ScalpingBot.ex5" -Force
$matrix=@()
$cacheEvidence=@()
foreach($symbol in @('XAUUSD','EURUSD','GBPUSD','USDJPY')) {
 foreach($kind in @('history','ticks')) {
  $dest="$terminal/bases/$Server/$kind/$symbol"
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  $files=Get-ChildItem -LiteralPath "$CacheTerminal/bases/$Server/$kind/$symbol" -File -ErrorAction SilentlyContinue
  foreach($file in $files){if($file.Name -eq '2026.hcc' -or $file.Name -eq 'ticks.dat' -or $file.Name -eq '202608.tkc'){
   $source=$file.FullName;$status='COPIED_READ_ONLY'
   try {Copy-MarketSnapshot $source (Join-Path $dest $file.Name)} catch {
    $fallback=Join-Path (Split-Path $root -Parent) "artifacts/mt5/trend-execution/terminal/bases/$Server/$kind/$symbol/$($file.Name)"
    if(Test-Path -LiteralPath $fallback){$source=(Resolve-Path $fallback).Path;Copy-MarketSnapshot $source (Join-Path $dest $file.Name);$status='COPIED_ARCHIVED_READ_ONLY'}
    else {$status='UNAVAILABLE_LOCKED_BY_EXISTING_TERMINAL'}
   }
   $cacheEvidence+=[pscustomobject]@{symbol=$symbol;kind=$kind;file=$file.Name;source=$source;status=$status}
  }}
 }
 foreach($mode in @('four-hour','triangle','combined')) {
  $id=$symbol.ToLower()+'-'+$mode
  $values=[ordered]@{}
  foreach($line in Get-Content "$root/profiles/scalping-bot-$($symbol.ToLower())-demo.set") {if($line -match '^(Inp\w+)=(.*)$'){$values[$matches[1]]=$matches[2]}}
  $values.InpEnable4HBreakout=if($mode -eq 'triangle'){'false'}else{'true'}
  $values.InpEnableTriangleMethod=if($mode -eq 'four-hour'){'false'}else{'true'}
  $values.InpEnableORBStrategy='false' # Preserve this original two-strategy matrix; use prepare_orb_backtests.ps1 for Strategy 3.
  $values.InpSignalOnly='false' # Tester simulation only; production/demo profiles remain signal-only.
  $values.InpBrokerTimeVerified='true';$values.InpBrokerDSTRule='0'
  $values.InpBrokerWinterUTCMinutes=$AssumedBrokerUTCMinutes.ToString();$values.InpBrokerSummerUTCMinutes=$AssumedBrokerUTCMinutes.ToString()
  $values.InpShowPanel='false';$values.InpDrawObjects='false'
  $lines=@('; SIMULATED STRATEGY TESTER ORDERS ONLY. Assumed broker mapping; verify independently.')
  foreach($key in $values.Keys){$lines+=($key+'='+$values[$key])}
  $lines | Set-Content -LiteralPath "$terminal/MQL5/Profiles/Tester/$id.set" -Encoding ASCII
  $report=Join-Path $root "artifacts/backtests/$id"
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
Expert=ScalpingBot.ex5
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
  $config=Join-Path $root "artifacts/backtests/$id.ini"
  $ini | Set-Content -LiteralPath $config -Encoding ASCII
  $matrix+=[pscustomobject]@{id=$id;symbol=$symbol;mode=$mode;from=$From;to=$To;requested_model='REAL_TICKS';assumed_broker_utc_minutes=$AssumedBrokerUTCMinutes;config=$config;report=$report;status='PREPARED_NOT_RUN'}
 }
}
$matrix | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$root/artifacts/backtests/matrix.json" -Encoding UTF8
$cacheEvidence | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$root/artifacts/backtests/cache-status.json" -Encoding UTF8
Write-Output "Prepared $($matrix.Count) isolated tests. Terminal: $terminal. Existing terminal data is read only."
