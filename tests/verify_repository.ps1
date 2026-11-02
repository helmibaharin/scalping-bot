param([switch]$VerifyReleaseSnapshot)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
$checks=0
function Assert($condition,$message){if(!$condition){throw "FAIL: $message"};$script:checks++}
Assert (Test-Path "$root/MQL5/Experts/ScalpingBot.mq5") 'EA entry point exists'
$defaults=@{}
foreach($line in Get-Content "$root/MQL5/Include/ScalpingBot/Config.mqh"){
 if($line -match '^input\s+\w+\s+(Inp\w+)=(.*);$'){$defaults[$matches[1]]=$matches[2]}
}
Assert ($defaults.Count -ge 280) 'complete five-strategy input schema'
Assert ($defaults.InpBrokerTimeVerified -eq 'false') 'source defaults do not infer broker verification'
Assert ($defaults.InpShapeSetupBasedExits -eq 'false' -and $defaults.InpSMTSetupBasedExits -eq 'false') 'setup exits remain optional by default'
$profiles=@(Get-ChildItem "$root/profiles" -File -Filter '*.set')
Assert ($profiles.Count -ge 12) 'strategy and all-five presets available'
foreach($profile in $profiles){
 $values=@{};foreach($key in $defaults.Keys){$values[$key]=$defaults[$key]}
 $seen=@{}
 foreach($line in Get-Content $profile.FullName){
  if($line -match '^(Inp\w+)=(.*)$'){
   $key=$matches[1];$value=$matches[2]
   Assert ($defaults.ContainsKey($key)) "$($profile.Name): known input $key"
   Assert (!$seen.ContainsKey($key)) "$($profile.Name): unique input $key"
   $seen[$key]=$true;$values[$key]=$value
  }
 }
 Assert ($values.InpAllowRealAccount -eq 'false') "$($profile.Name): real-account block"
 Assert ($values.InpBrokerTimeVerified -in @('false','true')) "$($profile.Name): explicit broker verification boolean; user verification remains external"
 $magics=@('Inp4HMagicNumber','InpTriangleMagicNumber','InpORBMagicNumber','InpSMTMagicNumber','InpVPMagicPOCBounce','InpVPMagicValueReversal','InpVPMagicBreakout') | ForEach-Object {$values[$_]}
 Assert (@($magics | Select-Object -Unique).Count -eq 7) "$($profile.Name): distinct strategy/method magics"
 if($profile.Name -eq 'all-five-xauusd-mtf-demo-execution.set'){
  Assert ($seen.Count -eq $defaults.Count) 'all-five preset explicitly covers the input schema'
  foreach($key in @('InpEnable4HBreakout','InpEnableTriangleMethod','InpEnableORBStrategy','InpEnableSMTStrategy','InpEnableVolumeProfile')){Assert ($values[$key] -eq 'true') "all-five: $key"}
  foreach($key in @('InpSignalOnly','InpSMTSignalOnly','InpEnableDailyRiskLock')){Assert ($values[$key] -eq 'false') "all-five: $key"}
  foreach($key in @('InpShapeSetupBasedExits','InpSMTSetupBasedExits')){Assert ($values[$key] -eq 'true') "all-five: $key"}
 }else{Assert ($values.InpSignalOnly -eq 'true') "$($profile.Name): observation preset"}
}
$sources=@(Get-ChildItem "$root/MQL5","$root/tests" -Recurse -File | Where-Object {$_.Extension -in @('.mqh','.mq5')})
foreach($source in $sources){
 foreach($match in [regex]::Matches((Get-Content $source.FullName -Raw),'(?m)^#include\s+"([^"]+)"')){
  $target=[IO.Path]::GetFullPath((Join-Path $source.DirectoryName $match.Groups[1].Value))
  Assert ($target.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) "local include stays in repository: $($source.Name)"
  Assert (Test-Path -LiteralPath $target) "include resolves: $($source.Name) -> $($match.Groups[1].Value)"
 }
}
if($VerifyReleaseSnapshot){
 $buildPath="$root/artifacts/shape-drawing-v1/final-build.json"
 if(!(Test-Path -LiteralPath $buildPath)){$buildPath="$root/artifacts/smt-repair-v1/final-build.json"}
 if(!(Test-Path -LiteralPath $buildPath)){$buildPath="$root/artifacts/decision-timing-v1/final-build.json"}
 if(!(Test-Path -LiteralPath $buildPath)){$buildPath="$root/artifacts/shape-timing-v1/final-build.json"}
 if(!(Test-Path -LiteralPath $buildPath)){$buildPath="$root/artifacts/setup-exits-v1/final-build.json"}
 if(!(Test-Path -LiteralPath $buildPath)){$buildPath="$root/artifacts/range-recovery-v1/final-build.json"}
 if(!(Test-Path -LiteralPath $buildPath)){$buildPath="$root/artifacts/daily-lock-v1/final-build.json"}
 $build=Get-Content $buildPath -Raw | ConvertFrom-Json
 Assert ((Get-FileHash "$root/MQL5/Experts/ScalpingBot.ex5" -Algorithm SHA256).Hash.ToLowerInvariant() -eq $build.binary_sha256) 'distributed EA matches recorded build'
 foreach($source in $build.sources){Assert ((Get-FileHash (Join-Path $root $source.path) -Algorithm SHA256).Hash.ToLowerInvariant() -eq $source.sha256) "release source matches: $($source.path)"}
}
Write-Output "PASS: $checks standalone repository/input/include checks. No terminal or parent-workspace audit files required."
