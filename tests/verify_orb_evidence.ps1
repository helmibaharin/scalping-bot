param([Parameter(Mandatory=$true)][string]$MatrixFile)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
$matrixPath=(Resolve-Path -LiteralPath $MatrixFile).Path
$folder=Split-Path $matrixPath -Parent
$matrix=Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json
$units=@($matrix | Where-Object mode -eq orb-unit)
if($units.Count -ne 1){throw 'Expected one native ORB fixture.'}
$unit=$units[0]
$unitLog=(Get-ChildItem -LiteralPath $unit.evidence_path -Filter 'Tester-*.log' | ForEach-Object {Get-Content -LiteralPath $_.FullName -Raw}) -join "`n"
$matchesFound=[regex]::Matches($unitLog,'ORB_TEST_RESULT \| checks=(\d+) failures=(\d+)')
if(!$matchesFound.Count -or $unitLog -match 'ORB_ASSERT_FAIL'){throw 'Native fixture did not pass.'}
$last=$matchesFound[$matchesFound.Count-1];$checks=[int]$last.Groups[1].Value;$failures=[int]$last.Groups[2].Value
if($failures -ne 0 -or $checks -lt 100){throw 'Missing, failed, or incomplete ORB fixture.'}
if($unit.binary_sha256 -ne (Get-FileHash -LiteralPath "$root/tests/ORBTests.ex5" -Algorithm SHA256).Hash){throw 'Fixture binary changed after execution.'}
$native=[ordered]@{status='PASS';checks=$checks;failures=$failures;binary_sha256=$unit.binary_sha256;evidence_path=$unit.evidence_path;scope='Native MQL production-function fixtures in isolated Strategy Tester; synthetic rule paths, not market profitability.'}
$native | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$folder/native-unit-results.json" -Encoding UTF8
$results=Get-Content -LiteralPath "$folder/results.json" -Raw | ConvertFrom-Json
$hash=(Get-FileHash -LiteralPath "$root/MQL5/Experts/ScalpingBot.ex5" -Algorithm SHA256).Hash
if($results.Count -ne 20 -or @($results | Where-Object {!$_.completed -or !$_.real_ticks_reported -or $_.run.binary_sha256 -ne $hash}).Count){throw 'Current-binary 20-run real-tick matrix incomplete.'}
$rangeReports=0;$entryChecks=0
foreach($result in $results){
 $mode=$result.run.mode
 foreach($file in Get-ChildItem -LiteralPath $result.run.evidence_path -Filter '*_deals.csv'){
  foreach($row in Import-Csv -LiteralPath $file.FullName){
   if($row.entry_type -ne '0'){continue};$entryChecks++
   if(($mode -eq 'four-hour' -and $row.strategy -ne '4H') -or ($mode -eq 'triangle' -and $row.strategy -ne 'TRIANGLE') -or
      ($mode -like 'orb-*' -and $row.strategy -ne 'ORB')){throw 'Disabled strategy placed a tester entry.'}
   if(($mode -eq 'orb-continuation' -and $row.comment -notlike 'SBOC.*') -or ($mode -eq 'orb-reversal' -and $row.comment -notlike 'SBOF.*')){throw 'Disabled ORB mode placed an entry.'}
  }
 }
 if($mode -in @('orb-continuation','orb-reversal','combined')){
  $rangeRows=@(Get-ChildItem -LiteralPath $result.run.evidence_path -Filter '*.csv' | Where-Object {$_.Name -notlike '*_deals.csv'} | ForEach-Object {Import-Csv -LiteralPath $_.FullName} | Where-Object {$_.event -eq 'ORB_RANGE_READY'})
  if(!$rangeRows.Count){throw "No ORB range constructed in $($result.run.id)."}
  $days=@($rangeRows | ForEach-Object {if($_.detail -match 'frozen NY=(.*)$'){$matches[1]}else{throw 'Range day not recorded.'}})
  if(@($days|Select-Object -Unique).Count -ne $days.Count){throw 'ORB range was refinalized within the same NY day.'}
  $rangeReports+=$rangeRows.Count
 }
}
$summary=[ordered]@{status='PASS';binary_sha256=$hash;market_runs=$results.Count;native_fixture_checks=$checks;native_fixture_failures=$failures;range_finalizations=$rangeReports;entry_ownership_checks=$entryChecks;sample_from=$matrix[0].from;sample_to_exclusive=$matrix[0].to;broker_mapping='Explicit fixed UTC+3 assumption for August test interval; verify independently.';trading_authority=$false}
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$folder/verification.json" -Encoding UTF8
Write-Output "PASS: $checks native ORB assertions; $($results.Count) real-tick runs; $rangeReports frozen ranges; $entryChecks entry ownership checks."
