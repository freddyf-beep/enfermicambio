param(
  [Parameter(Mandatory = $true)][string]$Source,
  [string]$OutDir = (Join-Path $env:TEMP 'review_frames'),
  [int]$Scale = 405,
  [int]$Height = 900
)

$ErrorActionPreference = 'Stop'

if (Test-Path -LiteralPath $OutDir) { Remove-Item -LiteralPath $OutDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ffmpeg) { throw 'No se encontro ffmpeg' }

# Extrae un frame por segundo hasta 20s (los tutoriales son cortos).
foreach ($t in @(1,2,4,6,8,10,12,14,16,18,20)) {
  $out = Join-Path $OutDir ('f_' + $t + '.jpg')
  $vf = 'scale=' + $Scale + ':' + $Height
  # No se redirige 2>$null porque, con espacios en la ruta, PowerShell parte el
  # argumento y ffmpeg busca un archivo truncado. La salida de ffmpeg es ruidosa
  # pero inofensiva. ffmpeg devuelve 0 al terminar correctamente.
  & $ffmpeg -y -ss "$t" -i $Source -frames:v 1 -vf $vf $out
}

Get-ChildItem -LiteralPath $OutDir | Sort-Object Name | Select-Object Name,Length | Format-Table -AutoSize | Out-String
