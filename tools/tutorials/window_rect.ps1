param([int]$Handle = 0)

Add-Type @'
using System;
using System.Runtime.InteropServices;
public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
public class WinRect {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
}
'@

if ($Handle -eq 0) { throw "Pasa -Handle" }

$r = New-Object RECT
[WinRect]::GetWindowRect([IntPtr]$Handle, [ref]$r) | Out-Null
$w = $r.Right - $r.Left
$h = $r.Bottom - $r.Top
Write-Output "HWND=$Handle rect width=$w height=$h (x=$($r.Left) y=$($r.Top))"
