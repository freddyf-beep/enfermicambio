$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$ui = '/sdcard/ui.xml'
& $adb -s emulator-5554 shell uiautomator dump $ui 2>$null | Out-Null
$xml = (& $adb -s emulator-5554 shell cat $ui 2>$null | Out-String)

$needle = [regex]::Escape('Instalar EnfermiCambio en este dispositivo')
$dq = [char]34
$attr = 'text'
$attrVal = [regex]::Escape($attr)
$pat = $attrVal + $dq + '[^' + $dq + ']*' + $needle + '[^' + $dq + ']*' + $dq + '[^>]*bounds=' + $dq + '\[(\d+),(\d+)\]\[(\d+),(\d+)\]' + $dq

Write-Output ("PATTERN: " + $pat)
$m = [regex]::Match($xml, $pat)
Write-Output ("MATCH: " + $m.Success)
if ($m.Success) { Write-Output ("bounds " + $m.Groups[1].Value + "," + $m.Groups[2].Value + "," + $m.Groups[3].Value + "," + $m.Groups[4].Value) }

# Buscar un substring simple
$idx = $xml.IndexOf('Instalar EnfermiCambio en este dispositivo')
Write-Output ("indexOf=" + $idx)
if ($idx -ge 0) {
  Write-Output ("snippet: " + $xml.Substring([math]::Max(0,$idx-120), [math]::Min(400, $xml.Length - [math]::Max(0,$idx-120))))
}
