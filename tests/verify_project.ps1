$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if(!(Test-Path -LiteralPath "$root/artifacts/protected-files-before.json")){
 & "$PSScriptRoot/verify_repository.ps1"
 exit 0
}
if(Test-Path -LiteralPath "$root/artifacts/daily-lock-v1/before.json"){
 $env:PYTHONHOME='C:/Program Files/MySQL/MySQL Shell 8.0/lib/Python3.12'
 & 'C:/Program Files/MySQL/MySQL Workbench 8.0 CE/python.exe' "$PSScriptRoot/verify_daily_risk.py"
 if($LASTEXITCODE -ne 0){throw 'Daily risk preservation gate failed'}
 exit 0
}
if(Test-Path -LiteralPath "$root/artifacts/broker-time-v1/before.json"){
 $env:PYTHONHOME='C:/Program Files/MySQL/MySQL Shell 8.0/lib/Python3.12'
 & 'C:/Program Files/MySQL/MySQL Workbench 8.0 CE/python.exe' "$PSScriptRoot/verify_broker_time.py"
 if($LASTEXITCODE -ne 0){throw 'Broker time preservation gate failed'}
 exit 0
}
if(Test-Path -LiteralPath "$root/profiles/volume-profile-xauusd-m15-m5-balanced-demo.set"){
 $env:PYTHONHOME='C:/Program Files/MySQL/MySQL Shell 8.0/lib/Python3.12'
 & 'C:/Program Files/MySQL/MySQL Workbench 8.0 CE/python.exe' "$PSScriptRoot/verify_volume_profile.py"
 if($LASTEXITCODE -ne 0){throw 'Volume Profile preservation gate failed'}
 exit 0
}
# Shape expands the schema and explicitly migrates the six historical profiles.
# Preserve the historical verifier below for old releases; use the migration-aware gate now.
if(Test-Path -LiteralPath "$root/profiles/shape-m15-m5-demo.set"){
 & "$PSScriptRoot/verify_shape_project.ps1"
 exit $LASTEXITCODE
}
$checks=0
function Assert($ok,$name){if(!$ok){throw "FAIL: $name"};$script:checks++}
$profiles=Get-ChildItem -LiteralPath "$root/profiles" -File -Filter '*.set'
Assert ($profiles.Count -eq 6) 'four preserved symbol profiles plus two SMT profiles'
$allMagics=@()
$expectedInputs=@(Select-String -LiteralPath "$root/MQL5/Include/ScalpingBot/Config.mqh" -Pattern '^input\s+\w+\s+Inp\w+=').Count
$smtInputs=@(Select-String -LiteralPath "$root/MQL5/Include/ScalpingBot/Config.mqh" -Pattern '^input\s+\w+\s+Inp(?:EnableSMTStrategy|SMT\w+)=').Count
foreach($profile in $profiles){
 $values=@{};foreach($line in Get-Content -LiteralPath $profile.FullName){if($line -match '^(Inp\w+)=(.*)$'){$values[$matches[1]]=$matches[2]}}
 $isSMT=$profile.Name.StartsWith('smt-')
 Assert ($values.Count -eq $(if($isSMT){$expectedInputs}else{$expectedInputs-$smtInputs})) "$($profile.Name) correct complete profile schema"
 Assert ($values.InpSignalOnly -eq 'true' -and $values.InpAllowRealAccount -eq 'false') "$($profile.Name) demo-first defaults"
 Assert ($values.InpBrokerTimeVerified -eq 'false') "$($profile.Name) requires broker verification"
 if($isSMT){
  Assert ($values.InpEnableSMTStrategy -eq 'true' -and $values.InpSMTSignalOnly -eq 'true') "$($profile.Name) SMT signal-only enabled"
  Assert ($values.InpEnable4HBreakout -eq 'false' -and $values.InpEnableTriangleMethod -eq 'false' -and $values.InpEnableORBStrategy -eq 'false') "$($profile.Name) strategies 1-3 independently disabled"
  Assert ($values.InpSMTTrendMode -eq '0' -and $values.InpSMTDynamicTP -eq 'true' -and $values.InpSMTMinimumRR -eq '1.0') "$($profile.Name) strict trend and dynamic optional 1R minimum"
  Assert ($values.InpSMTUseBSL -eq 'true' -and $values.InpSMTUseSSL -eq 'true' -and $values.InpSMTUseSupply -eq 'true' -and $values.InpSMTUseDemand -eq 'true' -and $values.InpSMTUseAccumulation -eq 'true' -and $values.InpSMTUseDistribution -eq 'true') "$($profile.Name) all six locations enabled"
  Assert ($values.InpSMTEnableClassic -eq 'true' -and $values.InpSMTEnableMultipleBaby -eq 'true' -and $values.InpSMTEnableRangeTrap -eq 'true' -and $values.InpSMTRequireFreshZones -eq 'true') "$($profile.Name) all trap patterns and mandatory freshness"
  if($values.InpSMTProfile -eq '0'){
   Assert ($values.InpSMTTrendTF -eq '16408' -and $values.InpSMTContextTF -eq '16388' -and $values.InpSMTZoneTF -eq '16388' -and $values.InpSMTSecondaryZoneTF -eq '16385' -and $values.InpSMTTrapTF -eq '15' -and $values.InpSMTEntryTF -eq '5') 'MTF exact timeframe mapping'
  }else{Assert ($values.InpSMTTrendTF -eq '15' -and $values.InpSMTZoneTF -eq '1' -and $values.InpSMTSecondaryZoneTF -eq '1' -and $values.InpSMTTrapTF -eq '1' -and $values.InpSMTEntryTF -eq '1') 'SCALP exact timeframe mapping'}
  $allMagics+=@($values.InpSMTMagicNumber)
 }else{
  Assert ($values.InpEnable4HBreakout -eq 'true' -and $values.InpEnableTriangleMethod -eq 'true' -and $values.InpEnableORBStrategy -eq 'true' -and !$values.ContainsKey('InpEnableSMTStrategy')) "$($profile.Name) original defaults preserved; SMT defaults disabled"
 }
 Assert ($values.InpEnableAscendingTriangle -eq 'true' -and $values.InpEnableDescendingTriangle -eq 'true' -and $values.InpEnableSymmetricalTriangle -eq 'true') "$($profile.Name) all three formations"
 Assert ([double]$values.Inp4HRewardRiskRatio -ge 2 -and [double]$values.InpTriangleRewardRiskRatio -ge 2) "$($profile.Name) minimum RR"
 Assert ([double]$values.InpFixedVolume -eq .01 -and [double]$values.InpMaxCombinedOpenRiskPercent -eq .5) "$($profile.Name) conservative research defaults"
 Assert ([double]$values.InpORBMinimumRR -ge 2 -and $values.InpORBExternalPolicy -eq '0') "$($profile.Name) strict ORB research defaults"
 $allMagics+=@($values.Inp4HMagicNumber,$values.InpTriangleMagicNumber,$values.InpORBMagicNumber)
}
Assert (@($allMagics|Select-Object -Unique).Count -eq 20) 'independent profile magics including unused ownership locks'
$sources=Get-ChildItem -LiteralPath "$root/MQL5" -Recurse -File | Where-Object {$_.Extension -in @('.mq5','.mqh')}
$text=($sources | ForEach-Object {Get-Content -LiteralPath $_.FullName -Raw}) -join "`n"
Assert ($text -notmatch 'CapitalGuard|WebRequest\(|iATR\(|iMA\(|iADX\(|iCustom\(|DatabaseOpen\(') 'standalone with no indicators or external services'
Assert ($text -match 'request\.sl=plan\.sl;request\.tp=plan\.tp') 'protected entry request'
Assert ($text -match 'signal\.candle\+SBSignalSeconds.*<=sb_signal_after') 'pre-startup signals blocked'
Assert ($text -match 'if\(StringLen\(sb_object_prefix\)>0\)ObjectsDeleteAll') 'failed init cannot delete unrelated chart objects'
Assert ($text -match 'FILE_COMMON' -and $text -match 'SBAccountingAllows') 'instance/account synchronization and accounting guard present'
$before=Get-Content -LiteralPath "$root/artifacts/protected-files-before.json" -Raw | ConvertFrom-Json
$changed=@()
foreach($item in $before){if(!(Test-Path -LiteralPath $item.path) -or (Get-FileHash -LiteralPath $item.path -Algorithm SHA256).Hash -ne $item.sha256){$changed+=$item.path}}
Assert ($changed.Count -eq 0) 'all pre-existing protected source/config/documentation/test files unchanged'
$preserved=Get-Content -LiteralPath "$root/artifacts/smt-v1/preserved-before.json" -Raw | ConvertFrom-Json
foreach($item in $preserved){Assert ((Get-FileHash -LiteralPath $item.path -Algorithm SHA256).Hash -eq $item.sha256) 'existing strategy module or demo profile unchanged'}
$result=[ordered]@{status='PASS';checks=$checks;protected_files=$before.Count;changed_files=$changed;scope='Existing Experts, config, docs, scripts, tests (excluding pycache), root README/compile/.gitignore. Active external runtime journals are not snapshotted.'}
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$root/artifacts/project-verification.json" -Encoding UTF8
Write-Output "PASS: $checks project/profile assertions; $($before.Count) pre-existing files unchanged."
