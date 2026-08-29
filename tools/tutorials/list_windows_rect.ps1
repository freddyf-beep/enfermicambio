Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public struct R2 { public int Left; public int Top; public int Right; public int Bottom; }
public class WEnum2 {
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
    [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out R2 r);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    delegate bool EnumWindowsProc(IntPtr h, IntPtr lp);
    public static List<string> List() {
        var result = new List<string>();
        EnumWindows((h, lp) => {
            if (!IsWindowVisible(h)) return true;
            int len = GetWindowTextLength(h);
            if (len > 0 && len < 200) {
                var sb = new StringBuilder(len + 1);
                GetWindowText(h, sb, len + 1);
                uint pid; GetWindowThreadProcessId(h, out pid);
                R2 r; GetWindowRect(h, out r);
                int w = r.Right - r.Left, ht = r.Bottom - r.Top;
                result.Add(h.ToInt64() + "\t" + pid + "\t" + w + "x" + ht + "\t" + sb.ToString());
            }
            return true;
        }, IntPtr.Zero);
        return result;
    }
}
'@

foreach ($w in [WEnum2]::List()) {
    if ($w -match "chrome|enfermi|Google Chrome|ChatGPT|Brave") { Write-Output $w }
}
