param(
  [string]$Tmp = (Join-Path $env:TEMP 'scrcpy_probe_touch.mp4')
)

$ErrorActionPreference = 'Stop'
$scrcpy = 'C:\Users\fredd\AppData\Local\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v4.1\scrcpy.exe'

if (Test-Path -LiteralPath $Tmp) { Remove-Item -LiteralPath $Tmp -Force }

$args = @(
  '-s', 'emulator-5554'
  '--window-title=SCRCPY-EnfermiCambio'
  '--window-x=0'
  '--window-y=0'
  ('--record=' + $Tmp)
  '--record-format=mp4'
  '--max-size=2400'
  '--show-touches'
)

$p = Start-Process -FilePath $scrcpy -ArgumentList $args -PassThru
Write-Output ("scrcpy PID=" + $p.Id)
Write-Output ("TMP=" + $Tmp)
