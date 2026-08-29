param(
  [string]$Source = (Join-Path $env:TEMP 'scrcpy_rec_db514081f41a4108934c065e77b86825.mp4')
)

$ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
$ffmpeg  = Get-Command ffmpeg  -ErrorAction SilentlyContinue

Write-Output ('ffprobe=' + $ffprobe.Source + ' ffmpeg=' + $ffmpeg.Source)
Write-Output ('source=' + $Source)

if ($ffprobe) {
  Write-Output '=== video stream ==='
  & $ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,duration,nb_frames -of default=noprint_wrappers=1 -i $Source
  Write-Output '=== format ==='
  & $ffprobe -v error -show_entries format=duration,size -of default=noprint_wrappers=1 -i $Source
}

if ($ffmpeg) {
  Write-Output '=== sample frames ==='
  foreach ($t in @(0,2,4,6,8,10,12)) {
    $png = Join-Path $env:TEMP ('chk_' + $t + '.png')
    & $ffmpeg -y -ss $t -i $Source -frames:v 1 $png 2>$null | Out-Null
    if (Test-Path $png) {
      Add-Type -AssemblyName System.Drawing
      $bmp = [System.Drawing.Bitmap]::FromFile($png)
      $sum = 0; $cnt = 0
      for ($y = 0; $y -lt $bmp.Height; $y += 8) {
        for ($x = 0; $x -lt $bmp.Width; $x += 8) {
          $c = $bmp.GetPixel($x, $y)
          $sum += ($c.R + $c.G + $c.B)
          $cnt++
        }
      }
      $avg = [math]::Round($sum / ($cnt * 3), 1)
      Write-Output ('t=' + $t + ' size=' + $bmp.Width + 'x' + $bmp.Height + ' avg=' + $avg)
      $bmp.Dispose()
      Remove-Item $png -Force
    } else {
      Write-Output ('t=' + $t + ' NO_FRAME')
    }
  }

  Write-Output '=== extract review frames ==='
  $outDir = Join-Path $env:TEMP 'rec_frames'
  if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
  New-Item -ItemType Directory -Path $outDir | Out-Null
  foreach ($t in @(1,30,60,120,180,240,290)) {
    & $ffmpeg -y -ss $t -i $Source -frames:v 1 (Join-Path $outDir ('f_' + $t + '.png')) 2>$null | Out-Null
  }
  Get-ChildItem $outDir | Select-Object Name,Length | Format-Table -AutoSize | Out-String
}
