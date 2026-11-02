param([string[]]$Ids=@(),[int]$TimeoutSeconds=240,[long]$TesterLogin=0,[Alias('Matrix')][string]$MatrixFile='',[switch]$OnlyIncomplete)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$terminal=(Resolve-Path -LiteralPath "$root/artifacts/test-terminal").Path
if(!$terminal.StartsWith((Resolve-Path $root).Path+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Tester must be inside scalping-bot.'}
if(!$MatrixFile){$MatrixFile=Join-Path $root 'artifacts/backtests/matrix.json'}
$matrixPath=(Resolve-Path -LiteralPath $MatrixFile).Path
if(!$matrixPath.StartsWith((Resolve-Path $root).Path+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Matrix must stay inside scalping-bot.'}
$evidenceRoot=Split-Path $matrixPath -Parent
$matrix=Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json
$selectedRuns=@($matrix | Where-Object {($Ids.Count -eq 0 -or $_.id -in $Ids) -and (!$OnlyIncomplete -or $_.status -notin @('REPORT_CREATED_REVIEW_REQUIRED','TEST_COMPLETED_CSV_AND_LOG'))})
if($selectedRuns.Count -eq 0){throw 'No matching test IDs; no tests were run.'}
if($TesterLogin -eq 0 -and (Test-Path -LiteralPath "$terminal/Config/common.ini")) {
 foreach($line in Get-Content -LiteralPath "$terminal/Config/common.ini"){if($line -match '^Login=(\d+)$'){$TesterLogin=[long]$matches[1]}}
}
foreach($run in $selectedRuns) {
 if(Test-Path -LiteralPath ($run.report+'.htm')){throw "Report already exists: $($run.report). Preserve it and prepare a new run directory."}
 Write-Output "TEST_START $($run.id)"
 $started=Get-Date
 $nativeReport=Join-Path $terminal "$($run.id).htm"
 if(Test-Path -LiteralPath $nativeReport) {
  $preserved=Join-Path $evidenceRoot ($run.id+'-previous-'+$started.ToUniversalTime().ToString('yyyyMMddTHHmmss')+'.htm')
  Move-Item -LiteralPath $nativeReport -Destination $preserved
 }
 $logLines=@{}
 foreach($logRoot in @("$terminal/logs","$terminal/Tester/logs")) {
  Get-ChildItem -LiteralPath $logRoot -File -Filter '*.log' -ErrorAction SilentlyContinue | ForEach-Object {$logLines[$_.FullName]=@(Get-Content -LiteralPath $_.FullName).Count}
 }
 $effectiveConfig=$run.config
 if($TesterLogin -gt 0) {
  $effectiveConfig=Join-Path $evidenceRoot "$($run.id)-effective.ini"
  ((Get-Content -LiteralPath $run.config -Raw) -replace '(?m)^Login=\d+\r?$',('Login='+$TesterLogin)) | Set-Content -LiteralPath $effectiveConfig -Encoding ASCII
 }
 $arguments=@('/portable',('/config:"{0}"' -f $effectiveConfig))
 $process=Start-Process -FilePath "$terminal/terminal64.exe" -ArgumentList $arguments -WorkingDirectory $terminal -WindowStyle Hidden -PassThru
 $watch=[Diagnostics.Stopwatch]::StartNew();$quietSince=$null;$finished=$false
 while($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
  # MT5 LiveUpdate can replace the launched PID. Follow only this portable installation.
  $own=@(Get-Process -Name terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq (Join-Path $terminal 'terminal64.exe')})
  if((Test-Path -LiteralPath $nativeReport) -and ((Get-Date)-(Get-Item -LiteralPath $nativeReport).LastWriteTime).TotalSeconds -ge 3) {
   $finished=$true
   # A completed tester report is durable; stop a terminal left open by its updater.
   foreach($p in $own){Stop-Process -Id $p.Id -ErrorAction SilentlyContinue}
   break
  }
  if($own.Count -eq 0 -and $process.HasExited) {
   if($null -eq $quietSince){$quietSince=Get-Date}
   if(((Get-Date)-$quietSince).TotalSeconds -ge 15){$finished=$true;break}
  } else {$quietSince=$null}
  Start-Sleep -Milliseconds 500
 }
 if(!$finished) {
  # Never enumerate/stop the existing user terminal; exact portable executable only.
  Get-Process -Name terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq (Join-Path $terminal 'terminal64.exe')} | Stop-Process -ErrorAction SilentlyContinue
  $run.status='TIMEOUT';Write-Output "TEST_TIMEOUT $($run.id)"
 } else {
  if(Test-Path -LiteralPath "$terminal/$($run.id).htm"){
   Copy-Item -LiteralPath "$terminal/$($run.id).htm" -Destination ($run.report+'.htm')
   Get-ChildItem -LiteralPath $terminal -Filter ($run.id+'*.png') -File | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $evidenceRoot}
  }
  $run.status=if(Test-Path -LiteralPath ($run.report+'.htm')){'REPORT_CREATED_REVIEW_REQUIRED'}else{'NO_REPORT'}
  Write-Output "TEST_FINISH $($run.id) $($run.status)"
 }
 $folder=Join-Path $evidenceRoot ("$($run.id)-evidence/"+$started.ToUniversalTime().ToString('yyyyMMddTHHmmss'))
 New-Item -ItemType Directory -Force -Path $folder | Out-Null
 # Retain the exact simulation inputs outside the disposable runtime cache.
 $parameters=Select-String -LiteralPath $effectiveConfig -Pattern '^ExpertParameters=(.+)$' | Select-Object -First 1
 if($parameters){
  $profileRoot=(Resolve-Path -LiteralPath "$terminal/MQL5/Profiles/Tester").Path
  $profilePath=(Resolve-Path -LiteralPath (Join-Path $profileRoot $parameters.Matches[0].Groups[1].Value.Trim())).Path
  if(!$profilePath.StartsWith($profileRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Tester inputs must stay inside the isolated profile directory.'}
  Copy-Item -LiteralPath $profilePath -Destination "$folder/tester-inputs.set"
 }
 foreach($logRoot in @("$terminal/logs","$terminal/Tester/logs")) {
  # MT5 may leave a log handle open after the report; Windows can retain an old
  # LastWriteTime until close. Capture appended lines instead of filtering by mtime.
  Get-ChildItem -LiteralPath $logRoot -File -Filter '*.log' -ErrorAction SilentlyContinue | ForEach-Object {
   $skip=if($logLines.ContainsKey($_.FullName)){$logLines[$_.FullName]}else{0}
   $appended=@(Get-Content -LiteralPath $_.FullName | Select-Object -Skip $skip)
   if($appended.Count){$appended | Set-Content -LiteralPath (Join-Path $folder ((Split-Path $logRoot -Parent | Split-Path -Leaf)+'-'+$_.Name)) -Encoding UTF8}
  }
 }
 $agentFiles=Join-Path $terminal 'Tester/Agent-127.0.0.1-32311/MQL5/Files/ScalpingBot'
 Get-ChildItem -LiteralPath $agentFiles -Filter '*.csv' -File -ErrorAction SilentlyContinue | Where-Object {$_.LastWriteTime -ge $started.AddSeconds(-2)} | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $folder}
 $testLog=Join-Path $folder ('Tester-'+(Get-Date).ToString('yyyyMMdd')+'.log')
 if($run.status -eq 'NO_REPORT' -and (Test-Path $testLog) -and (Select-String -LiteralPath $testLog -SimpleMatch 'SCALPING BOT | TESTER |' -Quiet)){$run.status='TEST_COMPLETED_CSV_AND_LOG'}
 $run | Add-Member -NotePropertyName evidence_path -NotePropertyValue $folder -Force
 $expert=if($run.PSObject.Properties.Name -contains 'expert'){$run.expert}else{'ScalpingBot.ex5'}
 $run | Add-Member -NotePropertyName binary_sha256 -NotePropertyValue (Get-FileHash -LiteralPath "$terminal/MQL5/Experts/$expert" -Algorithm SHA256).Hash -Force
 $run | Add-Member -NotePropertyName elapsed_seconds -NotePropertyValue ([Math]::Round(((Get-Date)-$started).TotalSeconds,2)) -Force
 $matrix | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $matrixPath -Encoding UTF8
}
