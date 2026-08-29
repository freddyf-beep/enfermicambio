Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Disp {
  [DllImport("user32.dll")]
  public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumProc lpfnEnum, IntPtr dwData);

  [DllImport("user32.dll")]
  public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);

  [DllImport("user32.dll")]
  public static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

  public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, IntPtr lprcMonitor, IntPtr dwData);

  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
  public struct MONITORINFO {
    public int cbSize;
    public RECT rcMonitor;
    public RECT rcWork;
    public uint dwFlags;
  }

  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
  public struct DISPLAY_DEVICE {
    public int cb;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string StateString;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    public uint Flags;
  }

  public const uint EDD_GET_DEVICE_INTERFACE_NAME = 0x00000001;

  public static string[] DevNames() {
    var list = new System.Collections.Generic.List<string>();
    DISPLAY_DEVICE dd = new DISPLAY_DEVICE();
    dd.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
    int i = 0;
    while (EnumDisplayDevices(null, (uint)i, ref dd, 0)) {
      if (dd.DeviceString.Length > 0) {
        list.Add(dd.DeviceName + " | " + dd.DeviceString + " | flags=" + dd.Flags);
      }
      dd = new DISPLAY_DEVICE();
      dd.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
      i++;
    }
    return list.ToArray();
  }
}
'@

Write-Output '=== Adaptadores de video ==='
try {
  Get-CimInstance Win32_VideoController | Select-Object Name,CurrentHorizontalResolution,CurrentVerticalResolution,VideoModeDescription | Format-List | Out-String | Write-Output
} catch { Write-Output 'Win32_VideoController no disponible' }

Write-Output '=== Dispositivos de pantalla (EnumDisplayDevices) ==='
[Disp]::DevNames() | ForEach-Object { Write-Output $_ }

Write-Output '=== Monitores (EnumDisplayMonitors) ==='
$items = New-Object System.Collections.ArrayList
$cb = [Disp+MonitorEnumProc]{
  param($hMon, $hdc, $rect, $data)
  $mi = New-Object Disp+MONITORINFO
  $mi.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type][Disp+MONITORINFO])
  [Disp]::GetMonitorInfo($hMon, [ref]$mi) | Out-Null
  $isPrimary = ($mi.dwFlags -band 1) -ne 0
  $null = $items.Add(('mon=' + $mi.rcMonitor.Left + ',' + $mi.rcMonitor.Top + ' ' + ($mi.rcMonitor.Right - $mi.rcMonitor.Left) + 'x' + ($mi.rcMonitor.Bottom - $mi.rcMonitor.Top) + ' primary=' + $isPrimary))
  return $true
}
[Disp]::EnumDisplayMonitors([IntPtr]::Zero, [IntPtr]::Zero, $cb, [IntPtr]::Zero) | Out-Null
$items | ForEach-Object { Write-Output $_ }

Write-Output '=== Screen (System.Windows.Forms) ==='
[System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
  Write-Output ('dev=' + $_.DeviceName + ' bounds=' + $_.Bounds + ' primary=' + $_.Primary)
}
