# DSH 大肥鱼 · 通用函数（日志/JSON/格式/URL/凭据/版本）

# ── Write-DebugLog ────────────────────
function Write-DebugLog([string]$msg) {
  try {
    $dir = Split-Path -Parent $script:WidgetLog
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $line = "[{0}] {1}" -f (Get-Date -Format 'MM-dd HH:mm:ss'), $msg
    Add-Content -LiteralPath $script:WidgetLog -Value $line -Encoding UTF8
  } catch { }
}

try {
  if ((Test-Path -LiteralPath $script:WidgetLog) -and (Get-Item -LiteralPath $script:WidgetLog).Length -gt 524288) {
    Move-Item -LiteralPath $script:WidgetLog -Destination "$script:WidgetLog.1" -Force
  }
} catch { }

# ── 单实例 ───────────────────────────────────────────────────────────────
Write-DebugLog ("boot pid=$PID dir=" + $script:AppDir)
$script:Mutex = New-Object System.Threading.Mutex($false, 'Global\DshFishBuddyWidget')
if (-not ($Preview -or $Shot)) {
  $got = $false
  try {
    $got = $script:Mutex.WaitOne(0)
  } catch [System.Threading.AbandonedMutexException] {
    $got = $true
    Write-DebugLog 'mutex abandoned, taking over'
  } catch {
    Write-DebugLog ("mutex error: " + $_.Exception.Message)
  }
  if (-not $got) { Write-DebugLog 'mutex busy, exit'; return }
}
$script:OwnMutex = $true
if (-not ($Preview -or $Shot)) {
  try { [System.IO.File]::WriteAllText($script:PidPath, [string]$PID) } catch { }
}

# ── 程序集 ───────────────────────────────────────────────────────────────
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 高 DPI 感知（矢量绘制保持清晰）
try {
  Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class DshFishDpi {
  [DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
  if ([DshFishDpi]::SetProcessDpiAwarenessContext([IntPtr](-4)) -eq [IntPtr]::Zero) {
    [void][DshFishDpi]::SetProcessDPIAware()
  }
} catch { }

[System.Windows.Forms.Application]::EnableVisualStyles()

# ── 配置 ─────────────────────────────────────────────────────────────────

# ── Read-JsonFile ────────────────────
function Read-JsonFile([string]$path) {
  try {
    if (Test-Path -LiteralPath $path) {
      return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
  } catch { }
  return $null
}

# ── Save-JsonFile ────────────────────
function Save-JsonFile([string]$path, $obj) {
  try {
    $json = $obj | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
  } catch { }
}

$configExisted = Test-Path -LiteralPath $script:ConfigPath
$script:Config = Read-JsonFile $script:ConfigPath
if ($null -eq $script:Config) {
  if ($configExisted) {
    try { Copy-Item -LiteralPath $script:ConfigPath -Destination ($script:ConfigPath + '.corrupt-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force } catch { }
  }
  $script:Config = [pscustomobject]@{
    notify = $true
    sound  = $true
    tray   = $true
    compact = $false
  }
  Save-JsonFile $script:ConfigPath $script:Config
}

$script:Ui = Read-JsonFile $script:UiPath
if ($null -eq $script:Ui) {
  $script:Ui = [pscustomobject]@{ left = $null; top = $null; collapsed = $false; sound = $null }
}

$script:Collapsed = [bool]$script:Ui.collapsed
$script:SoundOn = if ($null -ne $script:Ui.sound) { [bool]$script:Ui.sound } else { [bool]$script:Config.sound }
$script:SoundVolume = 80
try {
  if ($null -ne $script:Ui.soundVolume) {
    $v = [int]$script:Ui.soundVolume
    if ($v -ge 0 -and $v -le 100) { $script:SoundVolume = $v }
  }
} catch { }
$script:NotifyOn = if ($null -ne $script:Ui.notify) { [bool]$script:Ui.notify } else { -not ($null -ne $script:Config.notify -and $script:Config.notify -eq $false) }
$script:Topmost = if ($null -ne $script:Ui.topmost) { [bool]$script:Ui.topmost } else { $true }
$script:Material = 'default'
try {
  $m = [string]$script:Ui.material
  if ($m -eq 'white' -or $m -eq 'liquid') { $script:Material = 'white' }
  elseif ($m -eq 'glass') { $script:Material = 'glass' }
} catch { }
$script:RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:PinnedSessionId = ''
try { if ($script:Ui.pinned) { $script:PinnedSessionId = [string]$script:Ui.pinned } } catch { }
$script:CurrentSessions = @()
$script:PetUntil = [DateTime]::MinValue
$script:PendingResize = $false
$script:DisplayedSession = $null
$script:DisplayedRunning = $false
$script:WindowHidden = $false
$script:HitHookRegistered = $false
$script:HitRects = @()
$script:HitKey = ''
$script:HitSource = $null
$script:HitHook = $null
$script:LastReconnectAt = [DateTime]::Now
$script:CoreStartedAt = [DateTime]::MinValue
$script:StaleSeconds = 30.0
$script:CoreWarmupSeconds = 120.0
try {
  $pollMs = [double]$script:Config.pollMs
  if ($pollMs -ge 200 -and $pollMs -le 600000) {
    $script:StaleSeconds = [Math]::Max(30.0, [Math]::Ceiling($pollMs * 3.0 / 1000.0) + 5.0)
  }
} catch { }
$script:CoreWarmupSeconds = [Math]::Max(120.0, $script:StaleSeconds)

$script:Mascot = 'chibi'
try { if ($script:Config.mascot) { $script:Mascot = [string]$script:Config.mascot } } catch { }
$script:XamlPath = Join-Path $script:BinDir $(if ($script:Mascot -eq 'fish') { 'fish-ui.xaml' } elseif ($script:Mascot -eq 'whale') { 'whale-ui.xaml' } else { 'chibi-ui.xaml' })

$script:Scale = 1.0
try {
  if ($null -ne $script:Ui.scale) { $script:Scale = [double]$script:Ui.scale }
  elseif ($null -ne $script:Config.scale) { $script:Scale = [double]$script:Config.scale }
} catch { }
if ($script:Mascot -eq 'fish') { $script:Scale = 1.0 }
else { $script:Scale = [Math]::Max(0.7, [Math]::Min(1.4, $script:Scale)) }

# ── 加载界面 ─────────────────────────────────────────────────────────────
[xml]$xaml = Get-Content -LiteralPath $script:XamlPath -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xaml
$script:Window = [Windows.Markup.XamlReader]::Load($reader)
try { $script:Window.Topmost = [bool]$script:Topmost } catch { }

# ── Format-Duration ────────────────────
function Format-Duration([double]$ms) {
  if ($ms -lt 0) { $ms = 0 }
  $ts = [TimeSpan]::FromMilliseconds($ms)
  if ($ts.TotalHours -ge 1) { return ('{0}:{1:00}:{2:00}' -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds) }
  return ('{0:00}:{1:00}' -f $ts.Minutes, $ts.Seconds)
}

# ── Test-AllowedDshUrl ────────────────────
function Test-AllowedDshUrl([string]$url) {
  try {
    $uri = [System.Uri]$url
    if ($uri.Scheme -notin @('http', 'https')) { return $false }
    if ($uri.UserInfo) { return $false }
    if ($uri.IsLoopback) { return $true }
    $hostName = $uri.Host.ToLowerInvariant()
    return @('localhost', '127.0.0.1', '::1', '[::1]') -contains $hostName
  } catch { return $false }
}

# ── Get-DshCredential ────────────────────
function Get-DshCredential([string]$name) {
  $v = [Environment]::GetEnvironmentVariable($name)
  if ($v) { return $v.Trim() }
  $paths = New-Object System.Collections.ArrayList
  if ($env:DSH_HOME) { [void]$paths.Add((Join-Path $env:DSH_HOME '.credentials.yaml')) }
  if ($env:USERPROFILE) { [void]$paths.Add((Join-Path $env:USERPROFILE '.dsh\.credentials.yaml')) }
  foreach ($cred in $paths) {
    try {
      if (-not (Test-Path -LiteralPath $cred)) { continue }
      $pattern = '^\s*' + [regex]::Escape($name) + ':\s*(\S+)'
      $m = Select-String -LiteralPath $cred -Pattern $pattern | Select-Object -First 1
      if ($m) {
        $val = $m.Matches[0].Groups[1].Value.Trim()
        $val = $val.Trim('"').Trim("'")
        if ($val) { return $val }
      }
    } catch { }
  }
  return ''
}

# ── Get-WidgetVersion ────────────────────
function Get-WidgetVersion {
  try {
    $vf = Join-Path $script:AppDir 'version.json'
    if (Test-Path -LiteralPath $vf) {
      $v = (Get-Content -LiteralPath $vf -Raw -ErrorAction Stop | ConvertFrom-Json).version
      if ($v -match '^\d+\.\d+\.\d+$') { return [string]$v }
    }
  } catch { }
  return $script:Version
}

# ── Test-AllowedReleaseUrl ────────────────────
function Test-AllowedReleaseUrl([string]$url) {
  try {
    if ([string]::IsNullOrWhiteSpace($url)) { return $false }
    $u = [Uri]$url
    if ($u.Scheme -ne 'https') { return $false }
    if ($u.Host -ne 'github.com') { return $false }
    if (-not [string]::IsNullOrEmpty($u.UserInfo)) { return $false }
    if (-not $u.AbsolutePath.StartsWith('/PCYBlurF/dsh-fish-buddy/releases/')) { return $false }
    return $true
  } catch {
    return $false
  }
}

# ── Get-Prop ────────────────────
function Get-Prop($obj, [string]$name) {
  if ($null -eq $obj) { return $null }
  $p = $obj.PSObject.Properties[$name]
  if ($null -eq $p) { return $null }
  return $p.Value
}
