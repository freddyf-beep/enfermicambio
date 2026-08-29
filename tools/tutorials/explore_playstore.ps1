param(
  [string]$Url = 'https://play.google.com/store/apps/details?id=com.hcwebhook.app',
  [int]$WaitSeconds = 10
)

$ErrorActionPreference = 'Stop'
$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'

Write-Output ("Abrir: " + $Url)
& $adb -s emulator-5554 shell am start -a android.intent.action.VIEW -d $Url
Start-Sleep -Seconds $WaitSeconds

Write-Output '=== focus ==='
& $adb -s emulator-5554 shell dumpsys window 2>$null | Select-String 'mCurrentFocus|mFocusedApp' | Select-Object -First 3

Write-Output '=== dump UI text ==='
& $adb -s emulator-5554 shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
& $adb -s emulator-5554 shell cat /sdcard/ui.xml 2>$null | Out-String

$png = Join-Path $env:TEMP 'playstore_state.png'
& $adb -s emulator-5554 exec-out screencap -p > $png 2>$null
Write-Output ('saved=' + $png)
