# 临时验证脚本（非仓库既有工具）：用一块真正盖满显示器的无边框窗口冒充"全屏游戏"，
# 观察桌宠窗口的 WS_EX_TRANSPARENT 位是否随全屏进出切换。
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class W32 {
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetTopWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint c);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
  public static List<IntPtr> PetWindows(int pid) {
    var list = new List<IntPtr>();
    IntPtr h = GetTopWindow(IntPtr.Zero);
    while (h != IntPtr.Zero) {
      uint p; GetWindowThreadProcessId(h, out p);
      if ((int)p == pid && IsWindowVisible(h)) list.Add(h);
      h = GetWindow(h, 2);
    }
    return list;
  }
  public static string Report(int pid) {
    var sb = new StringBuilder();
    foreach (var h in PetWindows(pid)) {
      var cls = new StringBuilder(128); GetClassName(h, cls, 128);
      int ex = GetWindowLong(h, -20);
      bool through = (ex & 0x20) != 0;
      sb.AppendFormat("    hwnd=0x{0:X} cls={1} WS_EX_TRANSPARENT={2}\n", h.ToInt64(), cls, through);
    }
    return sb.Length == 0 ? "    (没有桌宠窗口)\n" : sb.ToString();
  }
  public static string RectOf(IntPtr h) {
    RECT r; GetWindowRect(h, out r);
    return string.Format("({0},{1})-({2},{3}) 尺寸 {4}x{5}", r.L, r.T, r.R, r.B, r.R - r.L, r.B - r.T);
  }
}
'@

[void][W32]::SetProcessDPIAware()

$pet = Get-Process -Name 'dsh-pet-standalone-webm-chat' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $pet) { throw '桌宠没在跑，无法验证' }

Write-Host "== 1. 全屏之前 =="
Write-Host ([W32]::Report($pet.Id))

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.ShowInTaskbar = $true
$form.TopMost = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(16, 16, 16)
$form.Show()
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
[void][W32]::SetWindowPos($form.Handle, [IntPtr]::Zero, $b.X, $b.Y, $b.Width, $b.Height, 0x0040)
[void][W32]::SetForegroundWindow($form.Handle)
Write-Host ("  冒充全屏的窗口: " + [W32]::RectOf($form.Handle))

$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt 5) {
  [System.Windows.Forms.Application]::DoEvents()
  Start-Sleep -Milliseconds 100
}
Write-Host "== 2. 全屏窗口在前台时 =="
Write-Host ([W32]::Report($pet.Id))

$form.Close()
$form.Dispose()
Start-Sleep -Seconds 2
Write-Host "== 3. 全屏关闭之后 =="
Write-Host ([W32]::Report($pet.Id))
