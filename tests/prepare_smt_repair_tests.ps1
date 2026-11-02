param([string]$BootstrapMatrix='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
& "$PSScriptRoot/prepare_decision_timing_tests.ps1" -BootstrapMatrix $BootstrapMatrix
$prepared=Get-ChildItem "$root/artifacts/decision-timing-v1" -Directory | Where-Object {Test-Path "$($_.FullName)/matrix.json"} | Sort-Object Name -Descending | Select-Object -First 1
$rows=Get-Content "$($prepared.FullName)/matrix.json" -Raw | ConvertFrom-Json
$output=Join-Path $root ('artifacts/smt-repair-v1/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory -Force $output | Out-Null
$matrix=@()
foreach($row in $rows){
 $config=Join-Path $output ($row.id+'.ini');Copy-Item -LiteralPath $row.config -Destination $config
 $row.config=$config;$row.report=Join-Path $output $row.id;$matrix+=$row
}
$config=Join-Path $output 'smt-repair.ini'
$ini=(Get-Content $matrix[0].config -Raw) -replace '(?m)^Expert=.*$','Expert=SMTRepairTests.ex5' -replace '(?m)^Report=.*$','Report=smt-repair.htm'
$ini | Set-Content -LiteralPath $config -Encoding ASCII
Copy-Item "$PSScriptRoot/SMTRepairTests.ex5" "$root/artifacts/test-terminal/MQL5/Experts/SMTRepairTests.ex5" -Force
$matrix=@([pscustomobject]@{id='smt-repair';symbol='XAUUSD';expert='SMTRepairTests.ex5';config=$config;report=(Join-Path $output 'smt-repair');status='PREPARED_NOT_RUN';from='2026.08.03';to='2026.08.04';mapping_scope='SYNTHETIC_FIXED_NOT_BROKER_VERIFICATION';model='M1_OHLC'})+$matrix
$matrix | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $output 'matrix.json') -Encoding UTF8
Write-Output "Prepared SMT repair tests: $(Join-Path $output 'matrix.json')"
