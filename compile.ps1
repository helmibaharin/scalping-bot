param(
    [string]$MetaEditor='C:\Users\C00567\AppData\Roaming\MetaTrader 5\metaeditor64.exe',
    [string]$Source=(Join-Path $PSScriptRoot 'MQL5/Experts/ScalpingBot.mq5')
)
$ErrorActionPreference='Stop'
$project=(Resolve-Path -LiteralPath $PSScriptRoot).Path
$sourcePath=(Resolve-Path -LiteralPath $Source).Path
if(!$sourcePath.StartsWith($project+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Compile source must stay inside scalping-bot.'}
$editor=(Resolve-Path -LiteralPath $MetaEditor).Path
$log=[IO.Path]::ChangeExtension($sourcePath,'.compile.log')
$started=Get-Date
Start-Process -FilePath $editor -WindowStyle Hidden -Wait -ArgumentList @('/compile:"'+$sourcePath+'"','/log:"'+$log+'"')
if(!(Test-Path -LiteralPath $log)){throw 'No compiler log produced.'}
$result=Get-Content -LiteralPath $log -Raw
$result | Select-String 'Result:.*' | ForEach-Object {$_.Matches.Value}
if((Get-Item -LiteralPath $log).LastWriteTime -lt $started.AddSeconds(-2) -or $result -notmatch '0 errors, 0 warnings'){Write-Output $result;throw 'Compile failed zero-errors/zero-warnings gate.'}
$binary=[IO.Path]::ChangeExtension($sourcePath,'.ex5')
if(!(Test-Path -LiteralPath $binary) -or (Get-Item -LiteralPath $binary).LastWriteTime -lt $started.AddSeconds(-2)){throw 'No fresh EX5 produced.'}
Write-Output "Compiled: $binary"
