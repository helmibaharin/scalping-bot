$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
& "$PSScriptRoot/prepare_orb_backtests.ps1" -Symbols @('EURUSD') -From '2026.08.03' -To '2026.08.04'
$boot=Get-ChildItem "$root/artifacts/orb-v1" -Directory | Sort-Object Name -Descending | Select-Object -First 1
$rows=Get-Content "$($boot.FullName)/matrix.json" -Raw | ConvertFrom-Json
$template=@($rows)[0]
$output=Join-Path $root ('artifacts/daily-lock-v1/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory $output | Out-Null
$terminal=Join-Path $root 'artifacts/test-terminal'
Copy-Item "$PSScriptRoot/DailyRiskTests.ex5" "$terminal/MQL5/Experts/DailyRiskTests.ex5"
# Reuse only the existing local demo-account record in the disposable, non-trading tester.
Copy-Item 'C:/Users/C00567/AppData/Roaming/MetaQuotes/Terminal/16E88504E6323783A450F87A361BF087/config/accounts.dat' "$terminal/Config/accounts.dat"
$id='daily-risk-unit';$profile=Join-Path $terminal "MQL5/Profiles/Tester/$id.set"
Copy-Item "$terminal/MQL5/Profiles/Tester/$($template.id).set" $profile
$ini=(Get-Content $template.config -Raw) -replace '(?m)^Expert=.*$','Expert=DailyRiskTests.ex5' -replace '(?m)^ExpertParameters=.*$',('ExpertParameters='+$id+'.set') -replace '(?m)^Report=.*$',('Report='+$id+'.htm')
$config=Join-Path $output "$id.ini";$ini | Set-Content $config -Encoding ASCII
$matrix=@([pscustomobject]@{id=$id;symbol='EURUSD';mode='daily-risk-unit';from='2026.08.03';to='2026.08.04';expert='DailyRiskTests.ex5';config=$config;report=(Join-Path $output $id);status='PREPARED_NOT_RUN'})
ConvertTo-Json -InputObject $matrix -Depth 5 | Set-Content "$output/matrix.json" -Encoding UTF8
Write-Output "Prepared isolated production account-policy test: $output/matrix.json"
