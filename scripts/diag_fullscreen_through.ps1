# 临时诊断：用一个盖满屏幕的无边框窗口冒充全屏，逐秒打印
# ① 前台窗口是谁 ② 桌宠窗口的 WS_EX_TRANSPARENT 位，用于定位穿透失效在哪一步。
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class D32 {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetTopWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint c);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
  public static string Describe(IntPtr h) {
    if (h == IntPtr.Zero) return "null";
    var sb = new StringBuilder(128); GetClassName(h, sb, 128);
    uint pid; GetWindowThreadProcessId(h, out pid);
    string p = ""; try { p = System.Diagnostics.Process.GetProcessById((int)pid).ProcessName; } catch {}
    int style = GetWindowLong(h, -16), ex = GetWindowLong(h, -20);
    RECT r; GetWindowRect(h, out r);
    return string.Format("{0} cls={1} caption={2} topmost={3} tool={4} rect=({5},{6})-({7},{8})",
      p, sb, (style & 0x00C00000) != 0, (ex & 0x8) != 0, (ex & 0x80) != 0, r.L, r.T, r.R, r.B);
  }
  public static string PetFlags(int pid) {
    var sb = new StringBuilder();
    IntPtr h = GetTopWindow(IntPtr.Zero);
    while (h != IntPtr.Zero) {
      uint p; GetWindowThreadProcessId(h, out p);
      if ((int)p == pid && IsWindowVisible(h)) {
        var cls = new StringBuilder(128); GetClassName(h, cls, 128);
        int ex = GetWindowLong(h, -20);
        sb.AppendFormat("      hwnd=0x{0:X} cls={1} transparent={2}\n", h.ToInt64(), cls, (ex & 0x20) != 0);
      }
      h = GetWindow(h, 2);
    }
    return sb.ToString();
  }
}
'@

[void][D32]::SetProcessDPIAware()
$pet = Get-Process -Name 'dsh-pet-standalone-webm-chat' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $pet) { throw '桌宠没在跑' }
Write-Host "桌宠 PID = $($pet.Id)"

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.ShowInTaskbar = $true
$form.TopMost = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 12)
$form.Show()
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
[void][D32]::SetWindowPos($form.Handle, [IntPtr]::Zero, $b.X, $b.Y, $b.Width, $b.Height, 0x0040)
[void][D32]::SetForegroundWindow($form.Handle)

for ($i = 1; $i -le 10; $i++) {
  [System.Windows.Forms.Application]::DoEvents()
  Start-Sleep -Milliseconds 900
  [void][D32]::SetForegroundWindow($form.Handle)
  "第 {0,2} 秒  前台: {1}" -f $i, [D32]::Describe([D32]::GetForegroundWindow())
  Write-Host ([D32]::PetFlags($pet.Id))
}
$form.Close(); $form.Dispose()
