param([string]$From='2026.08.03',[string]$To='2026.08.05')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
& "$PSScriptRoot/prepare_smt_backtests.ps1" -From $From -To $To
$bootstrap=Get-ChildItem "$root/artifacts/smt-v1" -Directory | Where-Object {Test-Path "$($_.FullName)/matrix.json"} | Sort-Object Name -Descending | Select-Object -First 1
$source=Get-Content "$($bootstrap.FullName)/matrix.json" -Raw | ConvertFrom-Json
$output=Join-Path $root ('artifacts/shape-v1/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory -Path $output | Out-Null
$terminal=Join-Path $root 'artifacts/test-terminal'
foreach($expert in @('ShapeTests','LifecycleTests')){Copy-Item "$PSScriptRoot/$expert.ex5" "$terminal/MQL5/Experts/$expert.ex5" -Force}
$matrix=@()
foreach($old in $source){
 $id=$old.id;$config=Join-Path $output "$id.ini"
 (Get-Content $old.config -Raw) | Set-Content $config -Encoding ASCII
 $matrix+=[pscustomobject]@{id=$id;symbol=$old.symbol;mode=$old.mode;from=$From;to=$To;requested_model='REAL_TICKS';assumed_broker_utc_minutes=180;config=$config;report=(Join-Path $output $id);expert=$old.expert;status='PREPARED_NOT_RUN'}
}
foreach($symbol in @('EURUSD','XAUUSD')){
 $modes=@('shape-both','shape-continuation','shape-reversal','shape-combined')
 if($symbol -eq 'EURUSD'){$modes=@('shape-unit','lifecycle-unit')+$modes}
 foreach($mode in $modes){
  $id=$symbol.ToLower()+'-'+$mode;$values=[ordered]@{}
  foreach($line in Get-Content "$root/profiles/shape-m15-m5-demo.set"){if($line -match '^(Inp\w+)=(.*)$'){$values[$matches[1]]=$matches[2]}}
  $values.InpSignalOnly='false';$values.InpBrokerTimeVerified='true';$values.InpBrokerDSTRule='0';$values.InpBrokerWinterUTCMinutes='180';$values.InpBrokerSummerUTCMinutes='180';$values.InpShowPanel='false';$values.InpDrawObjects='false'
  $values.InpShapeContinuation=if($mode -eq 'shape-reversal'){'false'}else{'true'}
  $values.InpShapeReversal=if($mode -eq 'shape-continuation'){'false'}else{'true'}
  if($mode -eq 'shape-combined'){$values.InpEnable4HBreakout='true';$values.InpEnableORBStrategy='true';$values.InpEnableSMTStrategy='true';$values.InpSMTSignalOnly='false'}
  @('; ISOLATED TESTER ONLY. Broker offset is an engineering assumption.')+@($values.Keys|ForEach-Object {$_+'='+$values[$_]}) | Set-Content "$terminal/MQL5/Profiles/Tester/$id.set" -Encoding ASCII
  $expert=if($mode -eq 'shape-unit'){'ShapeTests.ex5'}elseif($mode -eq 'lifecycle-unit'){'LifecycleTests.ex5'}else{'ScalpingBot.ex5'}
  $old=$source | Where-Object {$_.symbol -eq $symbol -and $_.mode -eq 'combined'} | Select-Object -First 1
  $text=(Get-Content $old.config -Raw) -replace '(?m)^Expert=.*$',('Expert='+$expert) -replace '(?m)^ExpertParameters=.*$',('ExpertParameters='+$id+'.set') -replace '(?m)^Report=.*$',('Report='+$id+'.htm')
  $config=Join-Path $output "$id.ini";$text | Set-Content $config -Encoding ASCII
  $matrix+=[pscustomobject]@{id=$id;symbol=$symbol;mode=$mode;from=$From;to=$To;requested_model='REAL_TICKS';assumed_broker_utc_minutes=180;config=$config;report=(Join-Path $output $id);expert=$expert;status='PREPARED_NOT_RUN'}
 }
}
$matrix | ConvertTo-Json -Depth 4 | Set-Content "$output/matrix.json" -Encoding UTF8
Write-Output "Prepared $($matrix.Count) Shape and regression scenarios: $output/matrix.json"
