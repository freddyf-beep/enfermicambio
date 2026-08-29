param([string]$Filter = '')

Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class Win32Enum {
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
    [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    delegate bool EnumWindowsProc(IntPtr h, IntPtr lp);
    public static List<string> List() {
        var result = new List<string>();
        EnumWindows((h, lp) => {
            if (!IsWindowVisible(h)) return true;
            int len = GetWindowTextLength(h);
            if (len > 0) {
                var sb = new StringBuilder(len + 1);
                GetWindowText(h, sb, len + 1);
                uint pid; GetWindowThreadProcessId(h, out pid);
                result.Add(h.ToInt64() + "\t" + pid + "\t" + sb.ToString());
            }
            return true;
        }, IntPtr.Zero);
        return result;
    }
}
'@

$wins = [Win32Enum]::List()
foreach ($w in $wins) {
    if ($Filter -eq '' -or $w -match $Filter) {
        Write-Output $w
    }
}
