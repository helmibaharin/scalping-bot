param([Parameter(Mandatory=$true)][string]$MatrixFile)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Split-Path $PSScriptRoot -Parent)).Path
$terminal=(Resolve-Path "$root/artifacts/test-terminal").Path
if($terminal -ne [IO.Path]::GetFullPath("$root/artifacts/test-terminal")){throw 'Unexpected isolated terminal path.'}
$matrixPath=(Resolve-Path -LiteralPath $MatrixFile).Path
if(!$matrixPath.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Matrix must stay inside scalping-bot.'}
$rows=Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json
$template=@($rows)[0]
$output=Join-Path (Split-Path $matrixPath -Parent) ('screenshot-readonly-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))
New-Item -ItemType Directory -Force $output,"$terminal/MQL5/Scripts" | Out-Null
$running=@(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq "$terminal\terminal64.exe"})
if($running.Count){throw 'Isolated tester is still running.'}
Copy-Item "$PSScriptRoot/ShapeTimingScreenshot.ex5" "$terminal/MQL5/Scripts/ShapeTimingScreenshot.ex5" -Force
$receipt="$terminal/MQL5/Files/shape_timing_screenshot_result.json"
if(Test-Path -LiteralPath $receipt){Move-Item -LiteralPath $receipt -Destination "$output/previous-result.json"}
$common=((Get-Content $template.config -Raw) -split '\[Experts\]')[0]
$ini=$common+@'
[Experts]
Enabled=0
AllowLiveTrading=0
AllowDllImport=0
[StartUp]
Script=ShapeTimingScreenshot.ex5
Symbol=XAUUSD
Period=M5
ShutdownTerminal=1
'@
$config=Join-Path $output 'readonly.ini';$ini | Set-Content -LiteralPath $config -Encoding ASCII
$process=Start-Process "$terminal/terminal64.exe" -WorkingDirectory $terminal -ArgumentList @('/portable',('/config:"'+$config+'"')) -WindowStyle Hidden -PassThru
if(!$process.WaitForExit(90000)){
 Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq "$terminal\terminal64.exe"} | Stop-Process
 throw 'Isolated read-only snapshot replay timed out.'
}
if(!(Test-Path -LiteralPath $receipt)){throw 'No native screenshot replay receipt; inspect the isolated terminal logs.'}
$result=Get-Content -LiteralPath $receipt -Raw | ConvertFrom-Json
Get-ChildItem "$terminal/MQL5/Files" -Filter 'shape_timing_screenshot*' -File | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $output}
Get-Content "$terminal/MQL5/Logs/$([DateTime]::Now.ToString('yyyyMMdd')).log" | Select-String 'SHAPE_SCREENSHOT|1357682230' | ForEach-Object {$_.Line} | Set-Content "$output/native-replay.log" -Encoding UTF8
if($result.status -ne 'PASS' -or $result.failures -ne 0 -or $result.checks -lt 8){throw 'Native screenshot assertions failed.'}
Write-Output "PASS: $($result.checks) read-only native screenshot assertions. Evidence: $output"
