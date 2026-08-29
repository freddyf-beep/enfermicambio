param(
  [string]$Source = (Join-Path $env:TEMP 'scrcpy_rec_db514081f41a4108934c065e77b86825.mp4'),
  [int[]]$Times = @(1,20,45,60,68,75,80,85,88)
)

$ErrorActionPreference = 'Continue'

$ffmpeg  = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
$ffprobe = (Get-Command ffprobe -ErrorAction SilentlyContinue).Source

if (-not $ffmpeg) { throw 'ffmpeg no encontrado' }

Write-Output ('source=' + $Source)

$out = Join-Path $env:TEMP 'rec_probe'
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Path $out | Out-Null

foreach ($t in $Times) {
  $png = Join-Path $out ('p_' + $t + '.png')
  & $ffmpeg -y -ss $t -i $Source -frames:v 1 $png 2>$null | Out-Null
}

Get-ChildItem $out | Select-Object Name,Length | Format-Table -AutoSize | Out-String
