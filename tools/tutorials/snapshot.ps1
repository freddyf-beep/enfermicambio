param(
  [string]$Name = 'state'
)

$ErrorActionPreference = 'SilentlyContinue'
$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'

$png = Join-Path $env:TEMP ($Name + '.png')
& $adb -s emulator-5554 exec-out screencap -p > $png 2>$null
$f = Get-Item $png
Write-Output ("saved=" + $png + " bytes=" + $f.Length)

Write-Output '=== focus ==='
& $adb -s emulator-5554 shell dumpsys window 2>$null | Select-String 'mCurrentFocus|mFocusedApp' | Select-Object -First 3

Write-Output '=== ui dump ==='
$ui = '/sdcard/ui.xml'
& $adb -s emulator-5554 shell uiautomator dump $ui 2>$null | Out-Null
& $adb -s emulator-5554 shell cat $ui 2>$null | Out-String
