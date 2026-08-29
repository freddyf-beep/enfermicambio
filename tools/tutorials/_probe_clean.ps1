$ErrorActionPreference = 'Stop'

$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$scrcpy = 'C:\Users\fredd\AppData\Local\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v4.1\scrcpy.exe'
$probe = Join-Path $env:TEMP 'scrcpy_probe.mp4'

if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force }

Write-Output ("PROBE=" + $probe)

$args = @(
    '-s', 'emulator-5554'
    '--window-title=SCRCPY-Probe'
    '--window-x=0'
    '--window-y=0'
    ('--record=' + $probe)
    '--record-format=mp4'
    '--max-size=2400'
)

$p = Start-Process -FilePath $scrcpy -ArgumentList $args -PassThru
Start-Sleep -Seconds 6

Write-Output ("PID=" + $p.Id)
Write-Output ("Alive=" + (-not $p.HasExited))

$f = Get-Item -LiteralPath $probe -ErrorAction SilentlyContinue
if ($f) {
    Write-Output ("Length=" + $f.Length)
    Write-Output ("LastWrite=" + $f.LastWriteTime)
} else {
    Write-Output "No se genero el archivo de prueba."
}
