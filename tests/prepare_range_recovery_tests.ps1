param(
 [string]$TerminalInstallation='C:\Users\C00567\AppData\Roaming\MetaTrader 5',
 [string]$CacheTerminal='C:\Users\C00567\AppData\Roaming\MetaQuotes\Terminal\16E88504E6323783A450F87A361BF087',
 [string]$Server='MetaQuotes-Demo',
 [long]$TesterLogin=0
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
$terminal=Join-Path $root 'artifacts/test-terminal'
if(@(Get-Process terminal64,metatester64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -and $_.Path.StartsWith($terminal+'\',[StringComparison]::OrdinalIgnoreCase)}).Count){throw 'Isolated tester is already running.'}
$output=Join-Path $root ('artifacts/range-recovery-v1/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory -Force $output,"$terminal/Config","$terminal/MQL5/Experts","$terminal/MQL5/Profiles/Tester","$terminal/bases/$Server/symbols","$terminal/bases/$Server/history/XAUUSD" | Out-Null
foreach($file in 'terminal64.exe','metatester64.exe'){Copy-Item -LiteralPath "$TerminalInstallation/$file" -Destination "$terminal/$file" -Force}
foreach($file in 'servers.dat','accounts.dat'){Copy-Item -LiteralPath "$CacheTerminal/config/$file" -Destination "$terminal/Config/$file" -Force}
if($TesterLogin -eq 0){
 foreach($line in Get-Content -LiteralPath "$CacheTerminal/config/common.ini"){if($line -match '^Login=(\d+)$'){$TesterLogin=[long]$matches[1]}}
}
if($TesterLogin -eq 0){throw 'Supply an existing demo tester login; no credentials are printed or saved in source.'}
Get-ChildItem -LiteralPath "$CacheTerminal/bases/$Server/symbols" -File | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination "$terminal/bases/$Server/symbols" -Force}
# M1 OHLC tests need no tick cache. Read the existing history without touching the live terminal.
$source="$CacheTerminal/bases/$Server/history/XAUUSD/2026.hcc"
try{
 $src=[IO.File]::Open($source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
 try{$dst=[IO.File]::Open("$terminal/bases/$Server/history/XAUUSD/2026.hcc",[IO.FileMode]::Create,[IO.FileAccess]::Write);try{$src.CopyTo($dst)}finally{$dst.Dispose()}}finally{$src.Dispose()}
}catch [System.IO.IOException]{Write-Output 'Live history seed is locked; isolated tester must download its own XAUUSD history.'}
Copy-Item "$root/MQL5/Experts/ScalpingBot.ex5" "$terminal/MQL5/Experts/ScalpingBot.ex5" -Force
foreach($fixture in 'SessionRangeTests','BrokerTimeTests','ORBTests'){Copy-Item "$PSScriptRoot/$fixture.ex5" "$terminal/MQL5/Experts/$fixture.ex5" -Force}
$matrix=@()
foreach($id in 'range-recovery','clock-regression','orb-regression','continuous-recovery','unverified-recovery','ny-dst-history','broker-dst-history'){
 $expert=switch($id){'range-recovery' {'SessionRangeTests.ex5'} 'clock-regression' {'BrokerTimeTests.ex5'} 'orb-regression' {'ORBTests.ex5'} default {'ScalpingBot.ex5'}}
 $values=[ordered]@{}
 foreach($line in Get-Content "$root/profiles/scalping-bot-xauusd-demo.set"){if($line -match '^(Inp\w+)=(.*)$'){$values[$matches[1]]=$matches[2]}}
 $values.InpBrokerTimeVerified=if($id -eq 'unverified-recovery'){'false'}else{'true'}
 $values.InpBrokerDSTRule='0';$values.InpBrokerWinterUTCMinutes='180';$values.InpBrokerSummerUTCMinutes='180'
 $from='2026.08.03';$to='2026.08.04'
 if($id -in @('ny-dst-history','broker-dst-history')){
  $values.InpBrokerDSTRule='1';$values.InpBrokerWinterUTCMinutes='120';$values.InpBrokerSummerUTCMinutes='180'
  if($id -eq 'ny-dst-history'){$from='2026.03.06';$to='2026.03.11'}else{$from='2026.10.23';$to='2026.10.28'}
 }
 $values.InpSignalOnly='true';$values.InpAllowRealAccount='false';$values.InpEnableDailyRiskLock='true'
 $values.InpEnable4HBreakout='true';$values.InpEnableORBStrategy='true';$values.InpEnableTriangleMethod='false';$values.InpEnableSMTStrategy='false'
 $values.InpEnableVolumeProfile=if($id -eq 'range-recovery'){'true'}else{'false'}
 $values.InpDrawObjects='true';$values.InpVPDrawObjects='true';$values.InpCSVLogging='true'
 @('; TESTER ONLY: synthetic verified fixed/EU settings are NOT broker timezone evidence.')+@($values.Keys | ForEach-Object {$_+'='+$values[$_]}) | Set-Content "$terminal/MQL5/Profiles/Tester/$id.set" -Encoding ASCII
 $ini=@"
[Common]
Login=$TesterLogin
Server=$Server
KeepPrivate=1
[Experts]
Enabled=0
AllowLiveTrading=0
AllowDllImport=0
[Tester]
Expert=$expert
ExpertParameters=$id.set
Symbol=XAUUSD
Period=M5
Login=$TesterLogin
Model=1
ExecutionMode=100
Optimization=0
FromDate=$from
ToDate=$to
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
 $matrix+=[pscustomobject]@{id=$id;symbol='XAUUSD';mode=$id;from=$from;to=$to;expert=$expert;config=$config;report=(Join-Path $output $id);status='PREPARED_NOT_RUN';mapping_scope='SYNTHETIC_FIXED_OR_EU_RULE_NOT_BROKER_VERIFICATION';model='M1_OHLC'}
}
ConvertTo-Json -InputObject @($matrix) -Depth 5 | Set-Content "$output/matrix.json" -Encoding UTF8
Write-Output "Prepared isolated range tests: $output/matrix.json"
