param([Parameter(Mandatory=$true)][string]$MatrixFile,[string]$Name='ScalpingBot-v1.0-ORB.zip')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
$matrix=(Resolve-Path -LiteralPath $MatrixFile).Path
if(!$matrix.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Matrix must stay inside scalping-bot.'}
if([IO.Path]::GetFileName($Name) -ne $Name -or !$Name.EndsWith('.zip')){throw 'Provide a ZIP filename, not a path.'}
$folder=Split-Path $matrix -Parent
$binaryHash=(Get-FileHash -LiteralPath "$root/MQL5/Experts/ScalpingBot.ex5" -Algorithm SHA256).Hash
$runs=Get-Content -LiteralPath "$folder/results.json" -Raw | ConvertFrom-Json
if($runs.Count -ne 20 -or @($runs | Where-Object {!$_.completed -or !$_.real_ticks_reported -or $_.run.binary_sha256 -ne $binaryHash}).Count){throw 'Twenty completed real-tick regression/mode runs must match the delivered binary.'}
foreach($symbol in @('XAUUSD','EURUSD','GBPUSD','USDJPY')){
 foreach($mode in @('four-hour','triangle','orb-continuation','orb-reversal','combined')){
  if(@($runs | Where-Object {$_.run.symbol -eq $symbol -and $_.run.mode -eq $mode}).Count -ne 1){throw 'Incomplete symbol/mode matrix.'}
 }
}
$nativeFixture=Get-Content -LiteralPath "$folder/native-unit-results.json" -Raw | ConvertFrom-Json
if($nativeFixture.failures -ne 0 -or $nativeFixture.checks -lt 100 -or $nativeFixture.binary_sha256 -ne (Get-FileHash -LiteralPath "$root/tests/ORBTests.ex5" -Algorithm SHA256).Hash){throw 'Native fixture is missing, failed or stale.'}
$verification=Get-Content -LiteralPath "$root/artifacts/project-verification.json" -Raw | ConvertFrom-Json
if($verification.status -ne 'PASS' -or $verification.changed_files.Count){throw 'Protected project verification failed.'}
$zip=Join-Path $root "artifacts/$Name"
if(Test-Path -LiteralPath $zip){throw 'Release ZIP exists; preserve it and select another filename.'}
$files=@()
foreach($dir in @('MQL5','profiles','docs','tests')){
 $files+=Get-ChildItem -LiteralPath "$root/$dir" -File -Recurse | Where-Object {$_.FullName -notmatch '\\__pycache__\\'}
}
foreach($file in @('README.md','compile.ps1','.gitignore')){$files+=Get-Item -LiteralPath "$root/$file" -Force}
$manifest=[ordered]@{product='Scalping Bot';version='1.00 ORB extension';created_utc=[DateTime]::UtcNow.ToString('o');binary_sha256=$binaryHash;native_runs=$runs.Count;native_fixture_checks=$nativeFixture.checks;native_fixture_failures=$nativeFixture.failures;matrix=$matrix;protected_project_files=$verification.protected_files;trading_authority=$false;source_files=@()}
foreach($file in $files){$manifest.source_files+=[pscustomobject]@{path=$file.FullName.Substring($root.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$root/artifacts/orb-release-manifest.json" -Encoding UTF8
$stage=Join-Path $root ('artifacts/orb-release-staging-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory -Path $stage | Out-Null
foreach($file in $files){$relative=$file.FullName.Substring($root.Length+1);$destination=Join-Path $stage $relative;New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null;Copy-Item -LiteralPath $file.FullName -Destination $destination}
New-Item -ItemType Directory -Path "$stage/artifacts" | Out-Null
$evidenceStage=Join-Path $stage $folder.Substring($root.Length+1)
New-Item -ItemType Directory -Force -Path $evidenceStage | Out-Null
foreach($file in @('orb-release-manifest.json','orb-changes.json','project-verification.json','protected-files-before.json')){Copy-Item -LiteralPath "$root/artifacts/$file" -Destination "$stage/artifacts/$file"}
foreach($file in @('RESULTS.md','results.json','matrix.json','native-unit-results.json','verification.json')){Copy-Item -LiteralPath "$folder/$file" -Destination "$evidenceStage/$file"}
Get-ChildItem -LiteralPath $folder -File | Where-Object {$_.Extension -in @('.htm','.png')} | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $evidenceStage}
Compress-Archive -Path "$stage/*" -DestinationPath $zip
Write-Output "Packaged current binary, source, profiles, docs, tests and verified result summaries: $zip"
Write-Output 'Runtime terminal files, caches and account records are excluded. Original release remains preserved.'
