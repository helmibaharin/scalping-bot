param(
 [string]$TerminalInstallation='C:\Users\C00567\AppData\Roaming\MetaTrader 5',
 [string]$CacheTerminal='C:\Users\C00567\AppData\Roaming\MetaQuotes\Terminal\16E88504E6323783A450F87A361BF087',
 [string]$Server='MetaQuotes-Demo',[long]$TesterLogin=0
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
# Reuse the isolated runtime/history preparation. Do not launch its unrelated matrix.
& "$PSScriptRoot/prepare_range_recovery_tests.ps1" -TerminalInstallation $TerminalInstallation -CacheTerminal $CacheTerminal -Server $Server -TesterLogin $TesterLogin
$bootstrap=Get-ChildItem "$root/artifacts/range-recovery-v1" -Directory | Where-Object {Test-Path "$($_.FullName)/matrix.json"} | Sort-Object Name -Descending | Select-Object -First 1
$template=@(Get-Content "$($bootstrap.FullName)/matrix.json" -Raw | ConvertFrom-Json)[0]
$terminal=Join-Path $root 'artifacts/test-terminal'
$output=Join-Path $root ('artifacts/setup-exits-v1/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory -Force $output | Out-Null
foreach($name in 'SetupExitTests','ShapeTests','SMTTests'){Copy-Item "$PSScriptRoot/$name.ex5" "$terminal/MQL5/Experts/$name.ex5" -Force}
$matrix=@()
foreach($id in 'setup-exits-native','shape-regression','smt-regression','shape-smt-structural','shape-smt-original'){
 $values=[ordered]@{}
 foreach($line in Get-Content "$root/profiles/all-five-xauusd-mtf-demo-execution.set"){if($line -match '^(Inp\w+)=(.*)$'){$values[$matches[1]]=$matches[2]}}
 $values.InpEnable4HBreakout='false';$values.InpEnableORBStrategy='false';$values.InpEnableVolumeProfile='false'
 $values.InpEnableTriangleMethod='true';$values.InpEnableSMTStrategy='true'
 $values.InpBrokerTimeVerified='true';$values.InpBrokerDSTRule='0';$values.InpBrokerWinterUTCMinutes='180';$values.InpBrokerSummerUTCMinutes='180'
 $values.InpSignalOnly=if($id -eq 'setup-exits-native'){'false'}else{'true'}
 $values.InpSMTSignalOnly='false';$values.InpAllowRealAccount='false';$values.InpDrawObjects='false';$values.InpUseFixedVolume='false'
 $mode=if($id -eq 'shape-smt-structural'){'true'}else{'false'}
 $values.InpShapeSetupBasedExits=$mode;$values.InpSMTSetupBasedExits=$mode
 $expert=switch($id){'setup-exits-native' {'SetupExitTests.ex5'} 'shape-regression' {'ShapeTests.ex5'} 'smt-regression' {'SMTTests.ex5'} default {'ScalpingBot.ex5'}}
 $until=if($id -in @('shape-smt-structural','shape-smt-original')){'2026.08.05'}else{'2026.08.04'}
 $deposit=if($id -eq 'setup-exits-native'){'100000'}else{'10000'}
 @('; ISOLATED TESTER ONLY. Synthetic verified UTC+3 is not broker-timezone evidence.')+@($values.Keys | ForEach-Object {$_+'='+$values[$_]}) | Set-Content "$terminal/MQL5/Profiles/Tester/$id.set" -Encoding ASCII
 $ini=(Get-Content $template.config -Raw) -replace '(?m)^Expert=.*$',('Expert='+$expert) -replace '(?m)^ExpertParameters=.*$',('ExpertParameters='+$id+'.set') -replace '(?m)^Report=.*$',('Report='+$id+'.htm') -replace '(?m)^ToDate=.*$',('ToDate='+$until) -replace '(?m)^Deposit=.*$',('Deposit='+$deposit)
 $config=Join-Path $output "$id.ini";$ini | Set-Content -LiteralPath $config -Encoding ASCII
 $matrix+=[pscustomobject]@{id=$id;symbol='XAUUSD';mode=$id;from='2026.08.03';to=$until;expert=$expert;config=$config;report=(Join-Path $output $id);status='PREPARED_NOT_RUN';model='M1_OHLC';mapping_scope='SYNTHETIC_FIXED_UTC_PLUS_3_NOT_BROKER_VERIFICATION'}
}
ConvertTo-Json -InputObject @($matrix) -Depth 5 | Set-Content "$output/matrix.json" -Encoding UTF8
Write-Output "Prepared setup-exit native and market regression tests: $output/matrix.json"
