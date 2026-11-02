$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
$manifest=[ordered]@{product='Scalping Bot';version='1.00';created_utc=[DateTime]::UtcNow.ToString('o');source_files=@();binary_sha256=(Get-FileHash -LiteralPath "$root/MQL5/Experts/ScalpingBot.ex5" -Algorithm SHA256).Hash;native_runs=24;native_real_tick_runs=24;rules_assertions=243;risk_execution_assertions=45;project_checks=36;metric_unit_tests=2;preexisting_protected_files_unchanged=219;trading_authority=$false}
$files=@()
foreach($dir in @('MQL5','profiles','docs','tests')) {
 $files+=Get-ChildItem -LiteralPath "$root/$dir" -File -Recurse | Where-Object {$_.FullName -notmatch '\\__pycache__\\'}
}
foreach($name in @('README.md','compile.ps1','.gitignore')){$files+=Get-Item -LiteralPath "$root/$name" -Force}
foreach($file in $files){$manifest.source_files+=[pscustomobject]@{path=$file.FullName.Substring($root.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}}
# Verify each completed matrix really belongs to the delivered binary before packaging.
foreach($kind in @('backtests','out-of-sample')) {
 $runs=Get-Content -LiteralPath "$root/artifacts/$kind/results.json" -Raw | ConvertFrom-Json
 if($runs.Count -ne 12 -or @($runs | Where-Object {!$_.completed -or !$_.real_ticks_reported -or $_.run.binary_sha256 -ne $manifest.binary_sha256}).Count -gt 0){throw "Native evidence does not match delivered binary: $kind"}
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$root/artifacts/release-manifest.json" -Encoding UTF8
$stage=Join-Path $root ('artifacts/release-staging-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory -Path $stage | Out-Null
foreach($file in $files){$relative=$file.FullName.Substring($root.Length+1);$dest=Join-Path $stage $relative;New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null;Copy-Item -LiteralPath $file.FullName -Destination $dest}
New-Item -ItemType Directory -Path "$stage/artifacts" | Out-Null
foreach($name in @('release-manifest.json','project-verification.json','protected-files-before.json')){Copy-Item -LiteralPath "$root/artifacts/$name" -Destination "$stage/artifacts/$name"}
foreach($kind in @('backtests','out-of-sample')) {
 New-Item -ItemType Directory -Path "$stage/artifacts/$kind" | Out-Null
 foreach($name in @('RESULTS.md','results.json','matrix.json')){Copy-Item -LiteralPath "$root/artifacts/$kind/$name" -Destination "$stage/artifacts/$kind/$name"}
 Get-ChildItem -LiteralPath "$root/artifacts/$kind" -Filter '*.htm' -File | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination "$stage/artifacts/$kind"}
}
$zip=Join-Path $root 'artifacts/ScalpingBot-v1.0.zip'
if(Test-Path -LiteralPath $zip){throw 'Release ZIP already exists; preserve it and select a new release filename.'}
Compress-Archive -Path "$stage/*" -DestinationPath $zip
Write-Output "Packaged source, binary, profiles, docs, tests and result summaries: $zip"
Write-Output 'Runtime terminal/account files, downloaded caches and credentials are excluded.'
