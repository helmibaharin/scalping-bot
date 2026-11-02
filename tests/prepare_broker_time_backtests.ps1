$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
& "$PSScriptRoot/prepare_orb_backtests.ps1" -Symbols @('EURUSD','XAUUSD') -From '2026.08.03' -To '2026.08.05'
$bootstrap=Get-ChildItem "$root/artifacts/orb-v1" -Directory | Sort-Object Name -Descending | Select-Object -First 1
$base=Get-Content "$($bootstrap.FullName)/matrix.json" -Raw | ConvertFrom-Json
$prior=Get-Content "$root/artifacts/volume-profile-v1/20261102T011704/matrix.json" -Raw | ConvertFrom-Json
$output=Join-Path $root ('artifacts/broker-time-v1/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory $output | Out-Null
$terminal=Join-Path $root 'artifacts/test-terminal'
Copy-Item "$PSScriptRoot/BrokerTimeTests.ex5" "$terminal/MQL5/Experts/BrokerTimeTests.ex5"
$matrix=@()
foreach($id in @('clock-unit','orb-unit','preserved-eurusd','preserved-xauusd','table-equivalent-xauusd','unverified-xauusd')){
 $symbol=if($id -like '*eurusd' -or $id -eq 'orb-unit'){'EURUSD'}else{'XAUUSD'}
 $old=$prior | Where-Object {$_.id -eq ('preserved-regression-'+$symbol.ToLower()+'-combined')} | Select-Object -First 1
 $parameters=Get-Content (Join-Path $old.evidence_path 'tester-inputs.set') -Raw
 $parameters+="`r`nInpBrokerUTCTransitions=`r`n"
 $expert='ScalpingBot.ex5';$mode='market-regression'
 if($id -eq 'clock-unit'){$expert='BrokerTimeTests.ex5';$mode='clock-unit'}
 if($id -eq 'orb-unit'){$expert='ORBTests.ex5';$mode='orb-unit'}
 if($id -eq 'unverified-xauusd'){$parameters=$parameters -replace '(?m)^InpBrokerTimeVerified=.*$','InpBrokerTimeVerified=false';$mode='unverified-block'}
 if($id -eq 'table-equivalent-xauusd'){$parameters=$parameters -replace '(?m)^InpBrokerDSTRule=.*$','InpBrokerDSTRule=3' -replace '(?m)^InpBrokerUTCTransitions=.*$','InpBrokerUTCTransitions=2007.01.01 00:00=180';$mode='synthetic-table-equivalence'}
 $parameters | Set-Content "$terminal/MQL5/Profiles/Tester/$id.set" -Encoding ASCII
 $template=$base | Where-Object {$_.symbol -eq $symbol -and $_.mode -eq 'combined'} | Select-Object -First 1
 $ini=(Get-Content $template.config -Raw) -replace '(?m)^Expert=.*$',('Expert='+$expert) -replace '(?m)^ExpertParameters=.*$',('ExpertParameters='+$id+'.set') -replace '(?m)^Report=.*$',('Report='+$id+'.htm')
 $config=Join-Path $output "$id.ini";$ini | Set-Content $config -Encoding ASCII
 $matrix+=[pscustomobject]@{id=$id;symbol=$symbol;mode=$mode;from='2026.08.03';to='2026.08.05';expert=$expert;config=$config;report=(Join-Path $output $id);status='PREPARED_NOT_RUN';mapping_scope='Synthetic verified settings for regression/equivalence ONLY. Not evidence of the actual broker timezone.'}
}
ConvertTo-Json -InputObject @($matrix) -Depth 5 | Set-Content "$output/matrix.json" -Encoding UTF8
Write-Output "Prepared broker mapping fixtures, frozen regressions, table equivalence and fail-closed test: $output/matrix.json"
