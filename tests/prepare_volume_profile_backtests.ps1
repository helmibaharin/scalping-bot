$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
& "$PSScriptRoot/prepare_orb_backtests.ps1" -Symbols @('EURUSD','XAUUSD') -From '2026.08.03' -To '2026.08.05'
$bootstrap=Get-ChildItem "$root/artifacts/orb-v1" -Directory | Sort-Object Name -Descending | Select-Object -First 1
$base=Get-Content "$($bootstrap.FullName)/matrix.json" -Raw | ConvertFrom-Json
$output=Join-Path $root ('artifacts/volume-profile-v1/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory $output | Out-Null
$terminal=Join-Path $root 'artifacts/test-terminal'
foreach($expert in @('VolumeProfileEngineTests','VolumeProfileTests','VolumeProfileLifecycleTests','ShapeTests','ORBTests','SMTTests','LifecycleTests')){Copy-Item "$PSScriptRoot/$expert.ex5" "$terminal/MQL5/Experts/$expert.ex5" -Force}
$matrix=@()
function Register-Test($id,$symbol,$mode,$expert,$from,$to,$parameters){
 $profile="$terminal/MQL5/Profiles/Tester/$id.set";$parameters | Set-Content $profile -Encoding ASCII
 $template=$base|Where-Object {$_.symbol -eq $symbol -and $_.mode -eq 'combined'}|Select-Object -First 1
 $ini=(Get-Content $template.config -Raw) -replace '(?m)^Expert=.*$',('Expert='+$expert) -replace '(?m)^ExpertParameters=.*$',('ExpertParameters='+$id+'.set') -replace '(?m)^Report=.*$',('Report='+$id+'.htm') -replace '(?m)^FromDate=.*$',('FromDate='+$from) -replace '(?m)^ToDate=.*$',('ToDate='+$to)
 $config=Join-Path $output "$id.ini";$ini | Set-Content $config -Encoding ASCII
 $script:matrix+=[pscustomobject]@{id=$id;symbol=$symbol;mode=$mode;from=$from;to=$to;requested_model='REAL_TICKS';assumed_broker_utc_minutes=180;config=$config;report=(Join-Path $output $id);expert=$expert;status='PREPARED_NOT_RUN'}
}
# Frozen historical inputs, not the user's now-edited SMT presets, define regression parity.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead("$root/artifacts/ScalpingBot-v1.0-Shape.zip")
try{
 $wanted=@('regression-eurusd-orb-unit','regression-eurusd-combined','regression-xauusd-combined','eurusd-smt-mtf-unit','eurusd-smt-scalp-unit','eurusd-smt-mtf','xauusd-smt-mtf','eurusd-smt-scalp','xauusd-smt-scalp','eurusd-shape-unit','eurusd-lifecycle-unit','eurusd-shape-both','xauusd-shape-both')
 foreach($id in $wanted){
  $entry=$zip.Entries|Where-Object {($_.FullName.Replace('\','/')) -match ('/'+[regex]::Escape($id)+'-evidence/[^/]+/tester-inputs.set$')}|Select-Object -First 1
  if(!$entry){throw "Frozen historical inputs unavailable: $id"}
  $reader=[IO.StreamReader]::new($entry.Open());try{$parameters=$reader.ReadToEnd()}finally{$reader.Dispose()}
  $symbol=if($id -match 'xauusd'){'XAUUSD'}else{'EURUSD'}
  $expert=if($id -match 'orb-unit'){'ORBTests.ex5'}elseif($id -match 'smt-.*-unit'){'SMTTests.ex5'}elseif($id -match 'shape-unit'){'ShapeTests.ex5'}elseif($id -match 'lifecycle-unit'){'LifecycleTests.ex5'}else{'ScalpingBot.ex5'}
  $mode=if($id.EndsWith('-unit')){$id}else{'preserved-strategy-market'}
  Register-Test ('preserved-'+$id) $symbol $mode $expert '2026.08.03' '2026.08.05' $parameters
 }
}finally{$zip.Dispose()}
foreach($mode in @('engine-unit','methods-unit','lifecycle-unit','all','poc','reversal','breakout','combined','stress','validation-all','holdout-all','holdout-poc','holdout-reversal','holdout-breakout')){
 $file=switch($mode){'poc'{'volume-profile-poc-bounce-only-demo.set'}'holdout-poc'{'volume-profile-poc-bounce-only-demo.set'}'reversal'{'volume-profile-value-reversal-only-demo.set'}'holdout-reversal'{'volume-profile-value-reversal-only-demo.set'}'breakout'{'volume-profile-breakout-only-demo.set'}'holdout-breakout'{'volume-profile-breakout-only-demo.set'}default{'volume-profile-xauusd-m15-m5-balanced-demo.set'}}
 $values=[ordered]@{};foreach($line in Get-Content "$root/profiles/$file"){if($line -match '^(Inp\w+)=(.*)$'){$values[$matches[1]]=$matches[2]}}
 $values.InpSignalOnly='false';$values.InpBrokerTimeVerified='true';$values.InpBrokerDSTRule='0';$values.InpBrokerWinterUTCMinutes='180';$values.InpBrokerSummerUTCMinutes='180';$values.InpDrawObjects='false';$values.InpShowPanel='false';$values.InpVPDrawObjects='false'
 if($mode -eq 'combined'){$values.InpEnable4HBreakout='true';$values.InpEnableTriangleMethod='true';$values.InpEnableORBStrategy='true';$values.InpEnableSMTStrategy='true';$values.InpSMTSignalOnly='false'}
 if($mode -eq 'stress'){$values.InpRoundTripCommissionPerLot='7';$values.InpDeviationPoints='20'}
 $from='2026.08.03';$to='2026.08.08'
 if($mode.StartsWith('validation')){$from='2026.08.10';$to='2026.08.15'}
 if($mode.StartsWith('holdout')){$from='2026.08.17';$to='2026.08.22'}
 if($mode.EndsWith('-unit')){$to='2026.08.04'}
 $expert=switch($mode){'engine-unit'{'VolumeProfileEngineTests.ex5'}'methods-unit'{'VolumeProfileTests.ex5'}'lifecycle-unit'{'VolumeProfileLifecycleTests.ex5'}default{'ScalpingBot.ex5'}}
 $symbol=if($mode.EndsWith('-unit')){'EURUSD'}else{'XAUUSD'}
 Register-Test ('vp-'+$mode) $symbol ('vp-'+$mode) $expert $from $to (@('; ISOLATED STRATEGY TESTER ONLY.')+@($values.Keys|ForEach-Object {$_+'='+$values[$_]}))
}
ConvertTo-Json -InputObject @($matrix) -Depth 5 | Set-Content "$output/matrix.json" -Encoding UTF8
Write-Output "Prepared $($matrix.Count) native VP, frozen regression, development/validation/holdout and cost-stress scenarios: $output/matrix.json"
