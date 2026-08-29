param(
    [string]$Out = 'artifacts\android_take_1.mp4',
    [switch]$NoWindow,
    [int]$MaxSize = 2400
)

$ErrorActionPreference = 'Stop'

$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$scrcpy = 'C:\Users\fredd\AppData\Local\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v4.1\scrcpy.exe'

if (-not (Test-Path -LiteralPath $scrcpy)) {
    throw "No se encontro scrcpy en $scrcpy"
}

# Garantiza que el dispositivo este online antes de grabar.
$count = 0
$online = $false
while ($count -lt 20) {
    $list = (& $adb devices 2>&1 | Out-String)
    if ($list -match 'emulator-5554\s+device') {
        $online = $true
        break
    }
    Start-Sleep -Seconds 2
    $count++
}

if (-not $online) {
    throw "El emulador emulator-5554 no esta online. No se puede grabar."
}

$outPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out))
$outDir = Split-Path -Parent $outPath
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}
if (Test-Path -LiteralPath $outPath) {
    Remove-Item -LiteralPath $outPath -Force
}

# WSL-path: scrcpy no recibe bien rutas con espacios cuando se pasan como un
# único elemento '--record=ruta'. Para que sea robusto, generamos una ruta sin
# espacios en TEMP y la movemos al destino al cerrar.
$tmpOut = Join-Path $env:TEMP ('scrcpy_rec_' + [guid]::NewGuid().ToString('N') + '.mp4')
$tmpOut = [System.IO.Path]::GetFullPath($tmpOut)

# Ventana en el monitor primario (X=0,Y=0) y grabacion nativa del dispositivo.
$args = @(
    '-s', 'emulator-5554'
    '--window-title=SCRCPY-EnfermiCambio'
    '--window-x=0'
    '--window-y=0'
    '--record=' + $tmpOut
    '--record-format=mp4'
    '--max-size=' + $MaxSize
)

if ($NoWindow) {
    $args += '--no-window'
}

# Se lanza con ventana visible para que aparezca en el monitor primario y,
# al cerrar la ventana con WM_CLOSE, scrcpy finalice el MP4 de forma limpia.
$p = Start-Process -FilePath $scrcpy -ArgumentList $args -PassThru

Write-Output ("scrcpy PID=" + $p.Id + " grabando a " + $tmpOut)
Write-Output ("DESTINO=" + $outPath)
