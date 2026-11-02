param([string]$BootstrapMatrix='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
if(!$BootstrapMatrix){
 & "$PSScriptRoot/prepare_range_recovery_tests.ps1"
 $BootstrapMatrix=(Get-ChildItem "$root/artifacts/range-recovery-v1" -Directory | Where-Object {Test-Path "$($_.FullName)/matrix.json"} | Sort-Object Name -Descending | Select-Object -First 1).FullName+'/matrix.json'
}
$template=(Get-Content $BootstrapMatrix -Raw | ConvertFrom-Json)[0]
$terminal=Join-Path $root 'artifacts/test-terminal'
$output=Join-Path $root ('artifacts/decision-timing-v1/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory -Force $output | Out-Null
$experts=[ordered]@{'decision-timing'='DecisionTimingTests';'shape-timing'='ShapeTimingTests';'shape-regression'='ShapeTests';'orb-regression'='ORBTests';'smt-regression'='SMTTests';'vp-regression'='VolumeProfileTests';'session-regression'='SessionRangeTests';'all-five-continuous'='ScalpingBot'}
$matrix=@()
foreach($id in $experts.Keys){
 $name=$experts[$id];$binary=if($name -eq 'ScalpingBot'){"$root/MQL5/Experts/ScalpingBot.ex5"}else{"$PSScriptRoot/$name.ex5"}
 Copy-Item -LiteralPath $binary -Destination "$terminal/MQL5/Experts/$name.ex5" -Force
 $values=[ordered]@{}
 foreach($line in Get-Content "$root/profiles/all-five-xauusd-mtf-demo-execution.set"){if($line -match '^(Inp\w+)=(.*)$'){$values[$matches[1]]=$matches[2]}}
 $values.InpSignalOnly='true';$values.InpSMTSignalOnly='true';$values.InpAllowRealAccount='false'
 $values.InpBrokerTimeVerified='true';$values.InpBrokerDSTRule='0';$values.InpBrokerWinterUTCMinutes='180';$values.InpBrokerSummerUTCMinutes='180'
 $values.InpShapeSetupBasedExits='false';$values.InpSMTSetupBasedExits='false'
 if($id -eq 'all-five-continuous'){$values.InpShapeUseContext='true'}
 $values.InpDrawObjects=if($id -eq 'session-regression'){'true'}else{'false'}
 @('; TESTER ONLY. Explicit synthetic mapping; not historical broker verification.')+@($values.Keys | ForEach-Object {$_+'='+$values[$_]}) | Set-Content "$terminal/MQL5/Profiles/Tester/$id.set" -Encoding ASCII
 $ini=(Get-Content $template.config -Raw) -replace '(?m)^Expert=.*$',('Expert='+$name+'.ex5') -replace '(?m)^ExpertParameters=.*$',('ExpertParameters='+$id+'.set') -replace '(?m)^Report=.*$',('Report='+$id+'.htm')
 $ini | Set-Content "$output/$id.ini" -Encoding ASCII
 $matrix+= [pscustomobject]@{id=$id;symbol='XAUUSD';expert=$name+'.ex5';config=(Join-Path $output "$id.ini");report=(Join-Path $output $id);status='PREPARED_NOT_RUN';from='2026.08.03';to='2026.08.04';mapping_scope='SYNTHETIC_FIXED_NOT_BROKER_VERIFICATION';model='M1_OHLC'}
}
$matrix | ConvertTo-Json -Depth 4 | Set-Content "$output/matrix.json" -Encoding UTF8
Write-Output "Prepared decision timing tests: $output/matrix.json"
