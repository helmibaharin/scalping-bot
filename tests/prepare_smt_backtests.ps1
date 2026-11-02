param([string]$From='2026.08.03',[string]$To='2026.08.05')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
# Reuse the audited read-only market-cache and portable terminal bootstrap.
& "$PSScriptRoot/prepare_orb_backtests.ps1" -From $From -To $To -Symbols @('EURUSD','XAUUSD')
$bootstrap=Get-ChildItem -LiteralPath "$root/artifacts/orb-v1" -Directory | Sort-Object Name -Descending | Select-Object -First 1
$source=Get-Content -LiteralPath "$($bootstrap.FullName)/matrix.json" -Raw | ConvertFrom-Json
$output=Join-Path $root ('artifacts/smt-v1/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory -Path $output | Out-Null
$terminal=Join-Path $root 'artifacts/test-terminal'
Copy-Item -LiteralPath "$PSScriptRoot/SMTTests.ex5" -Destination "$terminal/MQL5/Experts/SMTTests.ex5"
$matrix=@()
foreach($old in $source | Where-Object {$_.mode -in @('orb-unit','combined')}){
 $id='regression-'+$old.id;$config=Join-Path $output "$id.ini"
 $text=(Get-Content -LiteralPath $old.config -Raw) -replace '(?m)^Report=.*$',('Report='+$id+'.htm')
 $text | Set-Content -LiteralPath $config -Encoding ASCII
 $matrix+=[pscustomobject]@{id=$id;symbol=$old.symbol;mode=$old.mode;from=$From;to=$To;requested_model='REAL_TICKS';assumed_broker_utc_minutes=180;config=$config;report=(Join-Path $output $id);expert=$old.expert;status='PREPARED_NOT_RUN'}
}
foreach($profile in @('mtf','scalp')){
 $file=if($profile -eq 'mtf'){'smt-mtf-d1-h1-m15-m5-demo.set'}else{'smt-scalp-m15-m1-demo.set'}
 foreach($symbol in @('EURUSD','XAUUSD')){
  $modes=if($symbol -eq 'EURUSD'){@(('smt-'+$profile+'-unit'),('smt-'+$profile))}else{@('smt-'+$profile)}
  foreach($mode in $modes){
   $id=$symbol.ToLower()+'-'+$mode;$values=[ordered]@{}
   foreach($line in Get-Content -LiteralPath "$root/profiles/$file"){if($line -match '^(Inp\w+)=(.*)$'){$values[$matches[1]]=$matches[2]}}
   $values.InpSignalOnly='false';$values.InpSMTSignalOnly='false';$values.InpBrokerTimeVerified='true';$values.InpBrokerDSTRule='0'
   $values.InpBrokerWinterUTCMinutes='180';$values.InpBrokerSummerUTCMinutes='180';$values.InpShowPanel='false';$values.InpDrawObjects='false'
   @('; ISOLATED STRATEGY TESTER SIMULATION ONLY.')+@($values.Keys | ForEach-Object {$_+'='+$values[$_]}) | Set-Content -LiteralPath "$terminal/MQL5/Profiles/Tester/$id.set" -Encoding ASCII
   $expert=if($mode.EndsWith('-unit')){'SMTTests.ex5'}else{'ScalpingBot.ex5'}
   $old=$source | Where-Object {$_.symbol -eq $symbol -and $_.mode -eq 'combined'} | Select-Object -First 1
   $text=(Get-Content -LiteralPath $old.config -Raw) -replace '(?m)^Expert=.*$',('Expert='+$expert) -replace '(?m)^ExpertParameters=.*$',('ExpertParameters='+$id+'.set') -replace '(?m)^Report=.*$',('Report='+$id+'.htm')
   $config=Join-Path $output "$id.ini";$text | Set-Content -LiteralPath $config -Encoding ASCII
   $matrix+=[pscustomobject]@{id=$id;symbol=$symbol;mode=$mode;from=$From;to=$To;requested_model='REAL_TICKS';assumed_broker_utc_minutes=180;config=$config;report=(Join-Path $output $id);expert=$expert;status='PREPARED_NOT_RUN'}
  }
 }
}
$matrix | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$output/matrix.json" -Encoding UTF8
Write-Output "Prepared $($matrix.Count) independent SMT/native-regression scenarios: $output/matrix.json"
