$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
$checks=0
function Assert($ok,$why){if(!$ok){throw "FAIL: $why"};$script:checks++}
$before=Get-Content "$root/artifacts/protected-files-before.json" -Raw | ConvertFrom-Json
foreach($item in $before){Assert ((Test-Path -LiteralPath $item.path) -and (Get-FileHash -LiteralPath $item.path).Hash -eq $item.sha256) "protected parent file $($item.path) unchanged"}
$snapshot=Get-Content "$root/artifacts/shape-v1/before.json" -Raw | ConvertFrom-Json
$preserved=@('FourHourBreakout.mqh','Rules.mqh','ResistanceDetector.mqh','OrderBlockDetector.mqh','NewYorkTime.mqh','TriangleDetector.mqh','TriangleMethod.mqh','OpeningRangeBreakout.mqh','ORBEngine.mqh','ORBTypes.mqh','ORBExternal.mqh','SmartMoneyTrap.mqh','SMTContext.mqh','SMTEngine.mqh','SMTTypes.mqh','SMTLocations.mqh')
foreach($name in $preserved){$item=$snapshot|Where-Object {(Split-Path $_.path -Leaf) -eq $name};Assert ($null -ne $item -and (Get-FileHash -LiteralPath $item.path).Hash -eq $item.sha256) "$name unchanged"}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead("$root/artifacts/ScalpingBot-v1.0-SMT.zip")
try{
 $entries=@($zip.Entries|Where-Object {$_.FullName -match 'profiles[\\/].*\.set$'})
 Assert ($entries.Count -eq 6) 'six historical release profiles available for exact field comparison'
 foreach($entry in $entries){
  $reader=[IO.StreamReader]::new($entry.Open());try{$old=$reader.ReadToEnd()}finally{$reader.Dispose()}
  $name=($entry.FullName -split '[\\/]')[-1];$path=Join-Path $root "profiles/$name";$values=@{}
  foreach($line in Get-Content $path){if($line -match '^(Inp\w+)=(.*)$'){$values[$matches[1]]=$matches[2]}}
  foreach($line in ($old -split '\r?\n')){if($line -match '^(Inp\w+)=(.*)$'){Assert ($values[$matches[1]] -eq $matches[2]) "$name old input $($matches[1]) preserved"}}
  Assert ($values.InpShapeLegacyTriangle -eq 'true') "$name explicitly retains legacy Triangle behavior"
 }
}finally{$zip.Dispose()}
$config=Get-Content "$root/MQL5/Include/ScalpingBot/Config.mqh" -Raw
$expected=@([regex]::Matches($config,'(?m)^input\s+\w+\s+(Inp\w+)='))
$profiles=Get-ChildItem "$root/profiles" -Filter '*.set'
Assert ($profiles.Count -eq 7) 'six compatibility profiles and one new Shape profile'
foreach($profile in $profiles){
 $v=@{};foreach($line in Get-Content $profile.FullName){if($line -match '^(Inp\w+)=(.*)$'){Assert (!$v.ContainsKey($matches[1])) "$($profile.Name) unique input $($matches[1])";$v[$matches[1]]=$matches[2]}}
 Assert ($v.InpSignalOnly -eq 'true' -and $v.InpAllowRealAccount -eq 'false' -and $v.InpBrokerTimeVerified -eq 'false') "$($profile.Name) safe demo defaults"
 Assert ($v.InpBrokerMappingFromUTC -match '^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}$' -and $v.InpBrokerMappingUntilUTC -match '^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}$') "$($profile.Name) MT5 set-file datetime syntax"
 $missing=@($expected|ForEach-Object {$_.Groups[1].Value}|Where-Object {!$v.ContainsKey($_)})
 Assert (@($missing|Where-Object {$_ -notmatch '^Inp(?:EnableSMTStrategy|SMT)'}).Count -eq 0) "$($profile.Name) complete non-SMT schema"
 if($profile.Name -eq 'shape-m15-m5-demo.set'){
  Assert ($missing.Count -eq 0 -and $v.InpShapeLegacyTriangle -eq 'false' -and $v.InpShapeFormationTF -eq '15' -and $v.InpShapeEntryTF -eq '5') 'new Shape profile defaults and full schema'
  Assert ($v.InpShapeContinuation -eq 'true' -and $v.InpShapeReversal -eq 'true' -and $v.InpEnable4HBreakout -eq 'false' -and $v.InpEnableORBStrategy -eq 'false' -and $v.InpEnableSMTStrategy -eq 'false') 'both Shape methods independently enabled'
 }
}
$sources=(Get-ChildItem "$root/MQL5" -Recurse -File | Where-Object {$_.Extension -in '.mqh','.mq5'} | ForEach-Object {Get-Content $_.FullName -Raw}) -join "`n"
Assert ($sources -notmatch 'WebRequest\(|DatabaseOpen\(|iCustom\(') 'no external service or database'
Assert ($sources -match 'request.sl=plan.sl;request.tp=plan.tp' -and $sources -match 'SBAccountingAllows') 'protected entry and independent accounting guards retained'
[ordered]@{status='PASS';checks=$checks;protected_parent_files=$before.Count;preserved_modules=$preserved;profile_migration='all historical fields identical; explicit Shape legacy mode appended'} | ConvertTo-Json -Depth 4 | Set-Content "$root/artifacts/shape-v1/project-verification.json" -Encoding UTF8
Write-Output "PASS: $checks project/migration assertions; $($before.Count) parent files unchanged."

