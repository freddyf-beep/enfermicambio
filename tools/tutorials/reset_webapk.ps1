param([string]$PackagePattern = 'org.chromium.webapk')

$ErrorActionPreference = 'SilentlyContinue'
$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'

Write-Output '=== webapk actuales ==='
$pkgs = & $adb -s emulator-5554 shell pm list packages 2>$null | Out-String
$matches = [regex]::Matches($pkgs, 'package:(' + [regex]::Escape($PackagePattern) + '[^\r\n]*)')

if ($matches.Count -eq 0) {
  Write-Output 'No se encontro WebAPK con ese patron.'
} else {
  foreach ($m in $matches) {
    $pkg = $m.Groups[1].Value.Trim()
    Write-Output ("Desinstalando " + $pkg)
    & $adb -s emulator-5554 shell pm uninstall $pkg 2>&1 | Out-String
  }
}

Write-Output '=== focus tras reset ==='
& $adb -s emulator-5554 shell dumpsys window 2>$null | Select-String 'mCurrentFocus|mFocusedApp' | Select-Object -First 3
