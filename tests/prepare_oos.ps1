param([string]$From='2026.08.10',[string]$To='2026.08.12')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$source=Get-Content -LiteralPath "$root/artifacts/backtests/matrix.json" -Raw | ConvertFrom-Json
$folder=Join-Path $root 'artifacts/out-of-sample'
New-Item -ItemType Directory -Force -Path $folder | Out-Null
if(Test-Path -LiteralPath "$folder/matrix.json"){throw 'OOS matrix already exists; preserve it.'}
$matrix=@()
foreach($old in $source){
 $id='oos-'+$old.id
 $config=Join-Path $folder "$id.ini"
 $text=Get-Content -LiteralPath $old.config -Raw
 $text=$text -replace '(?m)^FromDate=.*$',('FromDate='+$From) -replace '(?m)^ToDate=.*$',('ToDate='+$To) -replace '(?m)^Report=.*$',('Report='+$id+'.htm')
 $text | Set-Content -LiteralPath $config -Encoding ASCII
 $matrix+=[pscustomobject]@{id=$id;symbol=$old.symbol;mode=$old.mode;from=$From;to=$To;requested_model='REAL_TICKS';assumed_broker_utc_minutes=$old.assumed_broker_utc_minutes;config=$config;report=(Join-Path $folder $id);status='PREPARED_NOT_RUN';parameter_policy='Same frozen .set files as chronological earlier engineering tests; no parameter tuning.'}
}
$matrix | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$folder/matrix.json" -Encoding UTF8
Write-Output "Prepared 12 later chronological OOS engineering tests in $folder with unchanged strategy parameters."
