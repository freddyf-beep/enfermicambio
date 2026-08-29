param(
  [string]$Url = 'https://enfermicambio-98b5a.web.app/install'
)

$ErrorActionPreference = 'SilentlyContinue'
$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'

# Cerrar Play Store / cualquier actividad con back.
& $adb -s emulator-5554 shell input keyevent 4 2>$null
Start-Sleep -Milliseconds 600
& $adb -s emulator-5554 shell input keyevent 4 2>$null
Start-Sleep -Milliseconds 600

# Abrir Chrome (proceso principal) si no está.
& $adb -s emulator-5554 shell am start -n com.android.chrome/com.google.android.apps.chrome.Main 2>$null
Start-Sleep -Seconds 2

# Abrir la guía de instalación pública.
& $adb -s emulator-5554 shell am start -a android.intent.action.VIEW -d $Url 2>$null
Start-Sleep -Seconds 6

Write-Output '=== focus ==='
& $adb -s emulator-5554 shell dumpsys window 2>$null | Select-String 'mCurrentFocus|mFocusedApp' | Select-Object -First 3
