param(
 [string]$TerminalInstallation='C:\Users\C00567\AppData\Roaming\MetaTrader 5',
 [string]$CacheTerminal='C:\Users\C00567\AppData\Roaming\MetaQuotes\Terminal\16E88504E6323783A450F87A361BF087',
 [string]$Server='MetaQuotes-Demo',[long]$TesterLogin=0
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
& "$PSScriptRoot/prepare_range_recovery_tests.ps1" -TerminalInstallation $TerminalInstallation -CacheTerminal $CacheTerminal -Server $Server -TesterLogin $TesterLogin
$bootstrap=Get-ChildItem "$root/artifacts/range-recovery-v1" -Directory | Where-Object {Test-Path "$($_.FullName)/matrix.json"} | Sort-Object Name -Descending | Select-Object -First 1
$template=@(Get-Content "$($bootstrap.FullName)/matrix.json" -Raw | ConvertFrom-Json)[0]
$terminal=Join-Path $root 'artifacts/test-terminal'
$output=Join-Path $root ('artifacts/shape-timing-v1/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory -Force $output | Out-Null
foreach($name in 'ShapeTimingTests','ShapeTests'){Copy-Item "$PSScriptRoot/$name.ex5" "$terminal/MQL5/Experts/$name.ex5" -Force}
$matrix=@()
foreach($id in 'timing-native','shape-regression','shape-continuous'){
 $values=[ordered]@{}
 foreach($line in Get-Content "$root/profiles/all-five-xauusd-mtf-demo-execution.set"){if($line -match '^(Inp\w+)=(.*)$'){$values[$matches[1]]=$matches[2]}}
 $values.InpEnable4HBreakout='false';$values.InpEnableORBStrategy='false';$values.InpEnableVolumeProfile='false';$values.InpEnableSMTStrategy='false';$values.InpEnableTriangleMethod='true'
 $values.InpBrokerTimeVerified='true';$values.InpBrokerDSTRule='0';$values.InpBrokerWinterUTCMinutes='120';$values.InpBrokerSummerUTCMinutes='120'
 $values.InpSignalOnly='true';$values.InpAllowRealAccount='false';$values.InpDrawObjects='false';$values.InpShapeDraw='false'
 # Original exit mode for the old native regression suite; current mode for other runs.
 if($id -eq 'shape-regression'){$values.InpShapeSetupBasedExits='false';$values.InpSMTSetupBasedExits='false'}
 $from=if($id -eq 'timing-screenshot'){'2026.11.02'}else{'2026.08.03'}
 $until=if($id -eq 'timing-screenshot'){'2026.11.03'}elseif($id -eq 'shape-continuous'){'2026.08.05'}else{'2026.08.04'}
 $expert=switch($id){'shape-regression' {'ShapeTests.ex5'} 'shape-continuous' {'ScalpingBot.ex5'} default {'ShapeTimingTests.ex5'}}
 @('; TESTER ONLY. Broker mapping is an explicit synthetic test input, not historical verification.')+@($values.Keys | ForEach-Object {$_+'='+$values[$_]}) | Set-Content "$terminal/MQL5/Profiles/Tester/$id.set" -Encoding ASCII
 $ini=(Get-Content $template.config -Raw) -replace '(?m)^Expert=.*$',('Expert='+$expert) -replace '(?m)^ExpertParameters=.*$',('ExpertParameters='+$id+'.set') -replace '(?m)^Report=.*$',('Report='+$id+'.htm') -replace '(?m)^FromDate=.*$',('FromDate='+$from) -replace '(?m)^ToDate=.*$',('ToDate='+$until)
 $config=Join-Path $output "$id.ini";$ini | Set-Content -LiteralPath $config -Encoding ASCII
 $matrix+=[pscustomobject]@{id=$id;symbol='XAUUSD';mode=$id;from=$from;to=$until;expert=$expert;config=$config;report=(Join-Path $output $id);status='PREPARED_NOT_RUN';model='M1_OHLC';mapping_scope='SYNTHETIC_FIXED_UTC_PLUS_2_NOT_BROKER_VERIFICATION'}
}
ConvertTo-Json -InputObject @($matrix) -Depth 5 | Set-Content "$output/matrix.json" -Encoding UTF8
Write-Output "Prepared Shape decision-timing tests: $output/matrix.json"
