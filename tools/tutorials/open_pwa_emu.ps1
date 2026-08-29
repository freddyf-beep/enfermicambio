$ErrorActionPreference = 'Stop'
$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'

# Abre Chrome y luego la PWA. Los 'am start' con URL se bloquean si van inline
# en la línea de comandos, por eso van desde este archivo.
& $adb -s emulator-5554 shell am start -n com.android.chrome/com.google.android.apps.chrome.Main
Start-Sleep -Seconds 3
& $adb -s emulator-5554 shell am start -a android.intent.action.VIEW -d 'https://enfermicambio-98b5a.web.app/'
Start-Sleep -Seconds 6
& $adb -s emulator-5554 shell dumpsys window | Select-String -Pattern 'mCurrentFocus' | Select-Object -First 1
