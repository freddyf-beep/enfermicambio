param(
    [string]$Pattern = '.*'
)

$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$tmp = Join-Path $env:TEMP 'ui_dump.xml'

& $adb -s emulator-5554 shell uiautomator dump /sdcard/ui_dump.xml 2>&1 | Out-Null
& $adb -s emulator-5554 pull /sdcard/ui_dump.xml $tmp 2>&1 | Out-Null

$xml = Get-Content -LiteralPath $tmp -Raw
$m = [regex]::Matches($xml, 'text="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
foreach ($g in $m) {
    $text = $g.Groups[1].Value
    if ($text -match $Pattern) {
        $x1 = [int]$g.Groups[2].Value
        $y1 = [int]$g.Groups[3].Value
        $x2 = [int]$g.Groups[4].Value
        $y2 = [int]$g.Groups[5].Value
        $cx = [int](($x1 + $x2) / 2)
        $cy = [int](($y1 + $y2) / 2)
        Write-Output ("center=({0},{1}) bounds=[{2},{3}][{4},{5}] text='{6}'" -f $cx, $cy, $x1, $y1, $x2, $y2, $text)
    }
}
