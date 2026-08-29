param(
  [Parameter(Mandatory = $true)][string]$Text
)

$ErrorActionPreference = 'SilentlyContinue'
$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'

# adb input text no acepta '+' como espacio literal ni algunos caracteres especiales.
# Transformamos los espacios en '%s' (como hace adb) y dejamos el resto tal cual.
$safe = $Text -replace '\s', '%s'

# Presiona la tecla TAB no; primero tocamos nada. Solo escribe el texto ya enfocado.
& $adb -s emulator-5554 shell input text $safe 2>$null

Write-Output ("text -> " + $Text)
