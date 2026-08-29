param([string]$Title = 'SCRCPY-EnfermiCambio')

Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class WClose {
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
    [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    delegate bool EnumWindowsProc(IntPtr h, IntPtr lp);
    public static List<IntPtr> Find(string title) {
        var outList = new List<IntPtr>();
        EnumWindows((h, lp) => {
            if (!IsWindowVisible(h)) return true;
            int len = GetWindowTextLength(h);
            if (len > 0 && len < 200) {
                var sb = new StringBuilder(len + 1);
                GetWindowText(h, sb, len + 1);
                if (sb.ToString().IndexOf(title, StringComparison.OrdinalIgnoreCase) >= 0) {
                    outList.Add(h);
                }
            }
            return true;
        }, IntPtr.Zero);
        return outList;
    }
    public static void Close(IntPtr h, uint msg = 0x0010) {
        PostMessage(h, msg, IntPtr.Zero, IntPtr.Zero);
    }
}
'@

$found = [WClose]::Find($Title)
if ($found.Count -eq 0) {
    # Fallback: cerrar el proceso padre de scrcpy por nombre.
    $procs = Get-Process -Name scrcpy -ErrorAction SilentlyContinue
    if ($procs) {
        foreach ($pr in $procs) { $pr | Stop-Process -Force }
        Write-Output "No habia ventana por titulo; se detuvo scrcpy por proceso."
    } else {
        Write-Output "No se encontro ventana con titulo '$Title' ni proceso scrcpy."
    }
    exit 0
}

foreach ($h in $found) {
    [WClose]::Close($h) | Out-Null
    Write-Output ("WM_CLOSE enviado a HWND " + $h.ToInt64())
}

# Espera breve para que scrcpy finalice el MP4 y luego confirma que no queda proceso.
Start-Sleep -Seconds 3
Get-Process -Name scrcpy -ErrorAction SilentlyContinue | Select-Object Id,MainWindowTitle | Format-Table -AutoSize
