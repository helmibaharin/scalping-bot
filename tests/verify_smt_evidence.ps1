param([Parameter(Mandatory=$true)][string]$MatrixFile)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
$matrixPath=(Resolve-Path -LiteralPath $MatrixFile).Path
$folder=Split-Path $matrixPath -Parent
$matrix=Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json
foreach($run in $matrix){if(!(Test-Path -LiteralPath "$($run.evidence_path)/tester-inputs.set")){throw 'Missing frozen tester input profile.'}}
$units=@($matrix | Where-Object {$_.mode.EndsWith('-unit')})
if($units.Count -ne 3){throw 'Expected two SMT fixtures and one ORB regression fixture.'}
$receipts=@()
foreach($unit in $units){
 $logs=(Get-ChildItem -LiteralPath $unit.evidence_path -Filter 'Tester-*.log' | ForEach-Object {Get-Content -LiteralPath $_.FullName -Raw}) -join "`n"
 if($logs -match 'ASSERT_FAIL'){throw "Native assertion failed in $($unit.id)."}
 $pattern=if($unit.mode -eq 'orb-unit'){'ORB_TEST_RESULT \| checks=(\d+) failures=(\d+)'}else{'SMT_TEST_RESULT \| profile=\w+ checks=(\d+) failures=(\d+)'}
 $found=[regex]::Matches($logs,$pattern)
 if(!$found.Count){throw "Missing native fixture receipt: $($unit.id)"}
 $last=$found[$found.Count-1];$checks=[int]$last.Groups[1].Value;$failures=[int]$last.Groups[2].Value
 $minimum=if($unit.mode -eq 'orb-unit'){100}else{107}
 if($failures -ne 0 -or $checks -lt $minimum){throw 'Incomplete native fixture.'}
 if($unit.binary_sha256 -ne (Get-FileHash -LiteralPath "$root/tests/$($unit.expert)" -Algorithm SHA256).Hash){throw 'Fixture binary changed after execution.'}
 $receipts+=[pscustomobject]@{id=$unit.id;status='PASS';checks=$checks;failures=$failures;binary_sha256=$unit.binary_sha256;evidence_path=$unit.evidence_path}
}
$results=Get-Content -LiteralPath "$folder/results.json" -Raw | ConvertFrom-Json
$hash=(Get-FileHash -LiteralPath "$root/MQL5/Experts/ScalpingBot.ex5" -Algorithm SHA256).Hash
if($results.Count -ne 6 -or @($results | Where-Object {!$_.completed -or !$_.real_ticks_reported -or $_.run.binary_sha256 -ne $hash}).Count){throw 'Six completed current-binary real-tick market runs required.'}
$entries=0
foreach($result in $results){
 foreach($file in Get-ChildItem -LiteralPath $result.run.evidence_path -Filter '*_deals.csv'){
  foreach($row in Import-Csv -LiteralPath $file.FullName){
   if($row.entry_type -ne '0'){continue};$entries++
   if(($result.run.mode -like 'smt-*' -and $row.strategy -ne 'SMT') -or ($result.run.mode -eq 'combined' -and $row.strategy -eq 'SMT')){throw 'Strategy isolation failed.'}
   if(($result.run.mode -eq 'smt-mtf' -and $row.comment -notlike 'SBM.*') -or ($result.run.mode -eq 'smt-scalp' -and $row.comment -notlike 'SBS.*')){throw 'SMT profile order identity failed.'}
  }
 }
}
foreach($symbol in @('EURUSD','XAUUSD')){foreach($mode in @('combined','smt-mtf','smt-scalp')){
 if(@($results | Where-Object {$_.run.symbol -eq $symbol -and $_.run.mode -eq $mode}).Count -ne 1){throw 'Missing symbol/profile test scenario.'}
}}
$preserved=Get-Content -LiteralPath "$root/artifacts/smt-v1/preserved-before.json" -Raw | ConvertFrom-Json
foreach($file in $preserved){if((Get-FileHash -LiteralPath $file.path -Algorithm SHA256).Hash -ne $file.sha256){throw 'Existing strategy module/profile changed.'}}
$summary=[ordered]@{status='PASS';binary_sha256=$hash;native_fixtures=$receipts;market_runs=$results.Count;entry_isolation_checks=$entries;preserved_strategy_and_profile_files=$preserved.Count;period_from=$matrix[0].from;period_to_exclusive=$matrix[0].to;trading_authority=$false}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$folder/verification.json" -Encoding UTF8
Write-Output "PASS: two 107-check SMT fixtures, 100-check ORB regression, six real-tick market runs, $entries entry isolation checks, $($preserved.Count) preserved strategy/profile files."
