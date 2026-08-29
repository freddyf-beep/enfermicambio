param([int]$Handle = 0)

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WinFore {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
}
'@

if ($Handle -eq 0) {
    throw "Pasa el handle de la ventana (-Handle 13860)"
}

$h = [IntPtr]$Handle
[WinFore]::ShowWindow($h, 9) | Out-Null
[WinFore]::BringWindowToTop($h) | Out-Null
[WinFore]::SetForegroundWindow($h) | Out-Null

Write-Output "Ventana $Handle llevada al frente"
