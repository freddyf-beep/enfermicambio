param(
  [string]$Out = 'artifacts\tutoriales\tutorial_1_instalar_pwa.mp4',
  [int]$MaxSize = 2400
)

$ErrorActionPreference = 'Stop'

$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$scrcpy = 'C:\Users\fredd\AppData\Local\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v4.1\scrcpy.exe'

if (-not (Test-Path -LiteralPath $scrcpy)) { throw "No se encontro scrcpy" }

$outPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out))
$outDir = Split-Path -Parent $outPath
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }

$tmpOut = Join-Path $env:TEMP ('scrcpy_rec_' + [guid]::NewGuid().ToString('N') + '.mp4')
$tmpOut = [System.IO.Path]::GetFullPath($tmpOut)

# 1) Deja la pantalla en la guia de instalacion publica (paso 0).
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'prep_tutorial1.ps1') | Out-Null

# 2) Lanza scrcpy grabando (ventana en el monitor primario de la laptop).
$args = @(
  '-s', 'emulator-5554'
  '--window-title=SCRCPY-EnfermiCambio'
  '--window-x=0'
  '--window-y=0'
  '--record=' + $tmpOut
  '--record-format=mp4'
  '--max-size=' + $MaxSize
)
$p = Start-Process -FilePath $scrcpy -ArgumentList $args -PassThru
Write-Output ("scrcpy PID=" + $p.Id + " grabando a " + $tmpOut)
Write-Output ("DESTINO=" + $outPath)

# 3) Da tiempo a que scrcpy abra la ventana y muestre el primer frame.
Start-Sleep -Seconds 4

# 4) El boton "Instalar EnfermiCambio ahora" depende de beforeinstallprompt y no
#    se muestra siempre. El flujo real (y el que la guia anticipa) es el menu
#    ⋮ → "Add to Home screen" → dialogo "Install".

# Abrir el menu ⋮ de Chrome.
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tap.ps1') -X 1000 -Y 213 -SlowMs 3 | Out-Null

# Elegir "Add to Home screen" (menu de Chrome).
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tap.ps1') -X 699 -Y 1856 -SlowMs 4 | Out-Null

# Confirmar el dialogo del sistema con el boton "Install".
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tap.ps1') -X 895 -Y 1455 -SlowMs 4 | Out-Null

# Deja la app instalada en pantalla.
Start-Sleep -Seconds 4

# 8) Cierra la ventana de scrcpy con WM_CLOSE para finalizar el MP4 limpio.
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'stop_scrcpy.ps1') | Out-Null
Start-Sleep -Seconds 3

# 9) Mueve el MP4 temporal al destino final.
if (-not (Test-Path -LiteralPath $tmpOut)) { throw "No se genero el MP4 temporal: $tmpOut" }
if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }
Move-Item -LiteralPath $tmpOut -Destination $outPath -Force

Write-Output ("FINALIZADO " + $outPath + " (" + (Get-Item $outPath).Length + " bytes)")
