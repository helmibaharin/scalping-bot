param([Parameter(Mandatory=$true)][string]$MatrixFile,[string]$Name='ScalpingBot-v1.0-SMT.zip')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
$matrix=(Resolve-Path -LiteralPath $MatrixFile).Path
if(!$matrix.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($Name) -ne $Name){throw 'Package/matrix paths must stay inside Scalping Bot.'}
$folder=Split-Path $matrix -Parent
& "$PSScriptRoot/verify_smt_evidence.ps1" -MatrixFile $matrix
$verification=Get-Content -LiteralPath "$folder/verification.json" -Raw | ConvertFrom-Json
$project=Get-Content -LiteralPath "$root/artifacts/project-verification.json" -Raw | ConvertFrom-Json
if($project.status -ne 'PASS' -or $project.changed_files.Count){throw 'Protected-project check failed.'}
$zip=Join-Path $root "artifacts/$Name";if(Test-Path -LiteralPath $zip){throw 'Preserve existing package; select a new name.'}
$files=@()
foreach($directory in @('MQL5','profiles','docs','tests')){$files+=Get-ChildItem -LiteralPath "$root/$directory" -File -Recurse | Where-Object {$_.FullName -notmatch '\\__pycache__\\'}}
foreach($file in @('README.md','compile.ps1','.gitignore')){$files+=Get-Item -LiteralPath "$root/$file" -Force}
$manifest=[ordered]@{product='Scalping Bot';version='1.00 SMT extension';created_utc=[DateTime]::UtcNow.ToString('o');binary_sha256=$verification.binary_sha256;market_runs=$verification.market_runs;native_fixtures=$verification.native_fixtures;protected_files=$project.protected_files;trading_authority=$false;source_files=@()}
foreach($file in $files){$manifest.source_files+=[pscustomobject]@{path=$file.FullName.Substring($root.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "$root/artifacts/smt-release-manifest.json" -Encoding UTF8
$stage=Join-Path $root ('artifacts/smt-release-staging-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory -Path $stage | Out-Null
foreach($file in $files){$destination=Join-Path $stage $file.FullName.Substring($root.Length+1);New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null;Copy-Item -LiteralPath $file.FullName -Destination $destination}
$evidence=Join-Path $stage $folder.Substring($root.Length+1)
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
foreach($name in @('RESULTS.md','results.json','matrix.json','verification.json')){Copy-Item -LiteralPath "$folder/$name" -Destination "$evidence/$name"}
Get-ChildItem -LiteralPath $folder -File | Where-Object {$_.Extension -in @('.htm','.png')} | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $evidence}
$runs=Get-Content -LiteralPath $matrix -Raw | ConvertFrom-Json
foreach($run in $runs){
 $path=(Resolve-Path -LiteralPath $run.evidence_path).Path
 if(!$path.StartsWith($folder+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected raw evidence path.'}
 $destination=Join-Path $stage $path.Substring($root.Length+1);New-Item -ItemType Directory -Force -Path $destination | Out-Null
 Get-ChildItem -LiteralPath $path -File | Where-Object {$_.Extension -in @('.log','.csv','.set')} | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $destination}
}
foreach($name in @('smt-release-manifest.json','smt-changes.json','project-verification.json','protected-files-before.json')){Copy-Item -LiteralPath "$root/artifacts/$name" -Destination "$stage/artifacts/$name"}
New-Item -ItemType Directory -Force -Path "$stage/artifacts/smt-v1" | Out-Null
Copy-Item -LiteralPath "$root/artifacts/smt-v1/preserved-before.json" -Destination "$stage/artifacts/smt-v1/preserved-before.json"
Compress-Archive -Path "$stage/*" -DestinationPath $zip
Write-Output "Packaged verified SMT build, profiles, docs, tests and raw evidence: $zip"
Write-Output 'Runtime terminal/cache/account records excluded; prior release packages preserved.'
