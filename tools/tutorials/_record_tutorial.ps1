param(
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Title = 'SCRCPY-Tutorial',
    [int]$RecordSeconds = 8
)

$ErrorActionPreference = 'Stop'

$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$scrcpy = 'C:\Users\fredd\AppData\Local\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v4.1\scrcpy.exe'

$outPath = [System.IO.Path]::GetFullPath($Out)
$outDir = Split-Path -Parent $outPath
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }

$tmpOut = Join-Path $env:TEMP ('scrcpy_tut_' + [guid]::NewGuid().ToString('N') + '.mp4')
$tmpOut = [System.IO.Path]::GetFullPath($tmpOut)

Write-Output ("TMP=" + $tmpOut)
Write-Output ("DEST=" + $outPath)

$args = @(
    '-s', 'emulator-5554'
    ('--window-title=' + $Title)
    '--window-x=0'
    '--window-y=0'
    ('--record=' + $tmpOut)
    '--record-format=mp4'
    '--max-size=2400'
)

$p = Start-Process -FilePath $scrcpy -ArgumentList $args -PassThru
Write-Output ("PID=" + $p.Id)

# Conduce taps mientras graba (para la prueba corta no hace nada útil, solo deja
# un flujo de video). La lógica de toques la maneja el llamador vía adb.
Start-Sleep -Seconds $RecordSeconds

Write-Output "Listo. Cerrar ventana con WM_CLOSE para finalizar (usar stop_scrcpy.ps1)."
