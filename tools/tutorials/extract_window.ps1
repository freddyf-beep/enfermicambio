param(
  [string]$Source = (Join-Path $env:TEMP 'scrcpy_rec_db514081f41a4108934c065e77b86825.mp4'),
  [int]$Start = 55,
  [int]$End = 95,
  [int]$Step = 2
)

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
$outDir = Join-Path $env:TEMP ('win_' + $Start + '_' + $End)
if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Path $outDir | Out-Null

Write-Output ('source=' + $Source)
Write-Output ('window ' + $Start + '..' + $End + ' step ' + $Step)
Write-Output ('outDir=' + $outDir)

for ($t = $Start; $t -le $End; $t += $Step) {
  & $ffmpeg -y -ss $t -i $Source -frames:v 1 (Join-Path $outDir ('f_' + $t + '.png')) 2>$null | Out-Null
}

Get-ChildItem $outDir | Select-Object Name,Length | Format-Table -AutoSize | Out-String
