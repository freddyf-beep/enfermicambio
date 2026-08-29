param(
  [string]$Source = (Join-Path $env:TEMP 'scrcpy_rec_db514081f41a4108934c065e77b86825.mp4')
)

$ffmpeg  = Get-Command ffmpeg -ErrorAction SilentlyContinue
$ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue

Write-Output ('source=' + $Source)
if ($ffprobe) {
  Write-Output '=== stream ==='
  & $ffprobe -v error -select_streams v:0 -show_entries stream=duration,nb_frames -of default=noprint_wrappers=1 -i $Source
}

# Muestrear brillo cada 5s para detectar el punto donde el contenido deja de cambiar.
Add-Type -AssemblyName System.Drawing
$prev = -1
foreach ($t in (0..60 | ForEach-Object { $_ * 5 })) {
  $png = Join-Path $env:TEMP ('scene_' + $t + '.png')
  & $ffmpeg -y -ss $t -i $Source -frames:v 1 $png 2>$null | Out-Null
  if (Test-Path $png) {
    $bmp = [System.Drawing.Bitmap]::FromFile($png)
    $sum = 0; $cnt = 0
    for ($y = 0; $y -lt $bmp.Height; $y += 12) {
      for ($x = 0; $x -lt $bmp.Width; $x += 12) {
        $c = $bmp.GetPixel($x, $y)
        $sum += ($c.R + $c.G + $c.B); $cnt++
      }
    }
    $avg = [int][math]::Round($sum / ($cnt * 3))
    $delta = if ($prev -lt 0) { 0 } else { [math]::Abs($avg - $prev) }
    Write-Output ('t=' + $t + ' avg=' + $avg + ' delta=' + $delta)
    $prev = $avg
    $bmp.Dispose()
    Remove-Item $png -Force
  }
}
