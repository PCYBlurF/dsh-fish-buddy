#requires -Version 5.1
<#
  DSH 大肥鱼 · 桌面挂件
  透明置顶的 DeepSeek 鲸鱼娘（或大肥鱼），实时显示 DSH 任务进度，完成时提醒。
  由 fish-core.mjs 提供 state.json，本脚本只负责显示与交互。
#>
param(
  [string]$Preview = "",
  [string]$Shot = "",
  [int]$ShotDelay = 1600,
  [switch]$NoCore
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Off

$script:AppDir = Split-Path -Parent $PSScriptRoot
$script:BinDir = $PSScriptRoot
$script:StatePath = Join-Path $script:AppDir 'state.json'
$script:ConfigPath = Join-Path $script:AppDir 'config.json'
$script:UiPath = Join-Path $script:AppDir 'ui.json'
$script:IconPath = Join-Path $script:AppDir 'assets\fish.ico'
$script:ChimePath = Join-Path $script:AppDir 'assets\chime.wav'
$script:CorePath = Join-Path $script:BinDir 'fish-core.mjs'
$script:WidgetLog = Join-Path $script:AppDir 'logs\widget.log'
$script:PidPath = Join-Path $script:AppDir 'widget.pid'
$script:Version = '0.1.22'
. (Join-Path $script:BinDir 'widget-lib.ps1')
. (Join-Path $script:BinDir 'widget-balance.ps1')
. (Join-Path $script:BinDir 'widget-update.ps1')

function Find-Name([string]$name) { return $script:Window.FindName($name) }

$script:Root = Find-Name 'Root'
$script:BubbleHost = Find-Name 'BubbleHost'
$script:Bubble = Find-Name 'Bubble'
$script:BubbleTail = Find-Name 'BubbleTail'
$script:GlassTint = Find-Name 'GlassTint'
$script:GlassNoise = Find-Name 'GlassNoise'
$script:BubbleContent = Find-Name 'BubbleContent'
$script:BubbleSlide = Find-Name 'BubbleSlide'
$script:BubbleBrushDefault = $script:Bubble.Background
$script:BubbleBorderDefault = $script:Bubble.BorderBrush
$script:BubbleTailDefault = if ($null -ne $script:BubbleTail) { $script:BubbleTail.Fill } else { $null }
$script:CountColorDefault = $script:CountText.Foreground
$script:MetaColorDefault = $script:MetaText.Foreground
if ($null -ne $script:GlassNoise) {
  try {
    $noisePath = Join-Path $script:AppDir 'assets\glass-noise.png'
    if (Test-Path -LiteralPath $noisePath) {
      $noiseImg = Load-Bitmap $noisePath
      $noiseBrush = New-Object Windows.Media.ImageBrush
      $noiseBrush.ImageSource = $noiseImg
      $noiseBrush.TileMode = 'Tile'
      $noiseBrush.Viewport = New-Object Windows.Rect(0, 0, 128, 128)
      $noiseBrush.ViewportUnits = 'Absolute'
      $noiseBrush.Stretch = 'Fill'
      $script:GlassNoise.Fill = $noiseBrush
    }
  } catch { }
}
$script:GlassTitleBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 22, 33, 61))
$script:GlassTaskBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 43, 56, 85))
$script:GlassCountBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 82, 98, 127))
$script:GlassMetaBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 94, 111, 140))
$script:GlassBarTrackBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 220, 229, 242))


$script:TitleText = Find-Name 'TitleText'
$script:CountText = Find-Name 'CountText'
$script:TaskText = Find-Name 'TaskText'
$script:MetaText = Find-Name 'MetaText'
$script:BarTrack = Find-Name 'BarTrack'
$script:TitleColorDefault = $script:TitleText.Foreground
$script:TaskColorDefault = $script:TaskText.Foreground
$script:CountColorDefault = $script:CountText.Foreground
$script:MetaColorDefault = $script:MetaText.Foreground
$script:BarTrackColorDefault = $script:BarTrack.Background
$script:BubbleTailStrokeDefault = if ($null -ne $script:BubbleTail) { $script:BubbleTail.Stroke } else { $null }
$script:BarFill = Find-Name 'BarFill'
$script:Dot = Find-Name 'Dot'
$script:FishHost = Find-Name 'FishHost'
$script:FishCanvas = Find-Name 'FishCanvas'
$script:JumpY = Find-Name 'JumpY'
$script:JumpScale = Find-Name 'JumpScale'
$script:TailRotate = Find-Name 'TailRotate'
$script:FinRotate = Find-Name 'FinRotate'
$script:EyeScaleL = Find-Name 'EyeScaleL'
$script:EyeScaleR = Find-Name 'EyeScaleR'
$script:SparkleLayer = Find-Name 'SparkleLayer'
$script:DoneBadge = Find-Name 'DoneBadge'
$script:Mouth = Find-Name 'Mouth'
$script:NormalMouthGeom = [Windows.Media.Geometry]::Parse('M 156 118 C 162 126 172 127 180 119')
$script:SadMouthGeom = [Windows.Media.Geometry]::Parse('M 156 126 C 162 117 172 117 180 126')
function Set-Mouth([bool]$sad) {
  try { $script:Mouth.Data = if ($sad) { $script:SadMouthGeom } else { $script:NormalMouthGeom } } catch { }
}
$script:HappyMouth = Find-Name 'HappyMouth'
$script:HappyEyes = Find-Name 'HappyEyes'
$script:EyeL = Find-Name 'EyeL'
$script:EyeR = Find-Name 'EyeR'

$script:SbBob = $script:Window.Resources['Bob']
$script:SbSway = $script:Window.Resources['Sway']
$script:MascotImage = Find-Name 'MascotImage'
$script:MascotScale = Find-Name 'MascotScale'
$script:GroundShadow = Find-Name 'GroundShadow'
$script:HoverScale = Find-Name 'HoverScale'
$script:ErrorMark = Find-Name 'ErrorMark'
function Set-Alert([bool]$on) {
  if ($null -ne $script:ErrorMark) { $script:ErrorMark.Opacity = if ($on) { 1.0 } else { 0.0 } }
}

# ── 形象资源 ─────────────────────────────────────────────────────────────
$script:SpriteMode = ($script:Mascot -eq 'chibi')
$script:Sprites = @{}
$script:CurrentSprite = $null
$script:FrameIndex = 0
$script:SpriteDir = Join-Path $script:AppDir 'assets\whale'

function Load-Bitmap([string]$path) {
  $bmp = New-Object Windows.Media.Imaging.BitmapImage
  $bmp.BeginInit()
  $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
  $bmp.UriSource = New-Object System.Uri($path, [System.UriKind]::Absolute)
  $bmp.EndInit()
  $bmp.Freeze()
  return $bmp
}

if ($script:SpriteMode -and $null -ne $script:MascotImage) {
  foreach ($name in @('idle', 'working', 'celebrate', 'error', 'sleep', 'think')) {
    $list = @()
    for ($i = 0; $i -lt 8; $i++) {
      $fp = Join-Path $script:SpriteDir ("{0}_{1}.png" -f $name, $i)
      if (-not (Test-Path -LiteralPath $fp)) { break }
      try { $list += Load-Bitmap $fp } catch { }
    }
    if ($list.Count -gt 0) { $script:Sprites[$name] = $list }
  }
  Write-DebugLog ("chibi sprites: " + (($script:Sprites.Keys | Sort-Object) -join ','))
} elseif ($null -ne $script:MascotImage) {
  try {
    $imgPath = Join-Path $script:AppDir 'assets\whale.png'
    if (-not (Test-Path -LiteralPath $imgPath)) { $imgPath = Join-Path $script:AppDir 'assets\whale\idle_0.png' }
    if (Test-Path -LiteralPath $imgPath) { $script:MascotImage.Source = Load-Bitmap $imgPath }
  } catch { Write-DebugLog ("mascot image load failed: " + $_.Exception.Message) }
}

$script:FrameTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:FrameTimer.Interval = [TimeSpan]::FromMilliseconds(220)
$script:FrameTimer.Add_Tick({
  if (-not $script:SpriteMode -or $null -eq $script:CurrentSprite) { return }
  $frames = $script:Sprites[$script:CurrentSprite]
  if ($null -eq $frames -or $frames.Count -le 1) { return }
  $script:FrameIndex = ($script:FrameIndex + 1) % $frames.Count
  try { $script:MascotImage.Source = $frames[$script:FrameIndex] } catch { }
})

function Set-Sprite([string]$name, [int]$intervalMs) {
  if (-not $script:SpriteMode -or $null -eq $script:MascotImage) { return }
  if ($script:CurrentSprite -eq $name) { return }
  $frames = $script:Sprites[$name]
  if ($null -eq $frames -or $frames.Count -eq 0) { return }
  $script:CurrentSprite = $name
  $script:FrameIndex = 0
  try { $script:MascotImage.Source = $frames[0] } catch { }
  try {
    $script:MascotImage.InvalidateMeasure()
    $script:MascotImage.InvalidateArrange()
    $script:Window.UpdateLayout()
  } catch { }
  $script:FrameTimer.Interval = [TimeSpan]::FromMilliseconds($intervalMs)
  if ($frames.Count -gt 1) {
    if (-not $script:FrameTimer.IsEnabled) { $script:FrameTimer.Start() }
  } else {
    $script:FrameTimer.Stop()
  }
}
$script:SbTail = $script:Window.Resources['TailWag']
$script:SbFin = $script:Window.Resources['FinFlap']
$script:SbBlink = $script:Window.Resources['Blink']
$script:SbCelebrate = $script:Window.Resources['Celebrate']
$script:SbSparkle = $script:Window.Resources['Sparkle']
$script:SbBubbles = $script:Window.Resources['Bubbles']
$script:SbDot = $script:Window.Resources['DotPulse']

# ── 声音 ─────────────────────────────────────────────────────────────────
$script:Player = $null
try {
  if (Test-Path -LiteralPath $script:ChimePath) {
    $script:Player = New-Object System.Media.SoundPlayer $script:ChimePath
    $script:Player.Load()
  }
} catch { }

function Play-Chime {
  if (-not $script:SoundOn) { return }
  try { if ($null -ne $script:Player) { $script:Player.Play() } } catch { }
}

# ── 后端进程 ─────────────────────────────────────────────────────────────
$script:CoreProc = $null
$script:CoreRestarts = 0
$script:LastStateWrite = [DateTime]::MinValue

function Get-NodePath {
  $candidates = @()
  if ($env:DSH_HOME) {
    $candidates += (Join-Path $env:DSH_HOME 'dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe')
  }
  if ($env:USERPROFILE) {
    $candidates += (Join-Path $env:USERPROFILE '.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe')
  }
  $cmd = Get-Command node -ErrorAction SilentlyContinue
  if ($cmd) { $candidates += $cmd.Source }
  foreach ($c in $candidates) {
    if (-not $c -or -not (Test-Path -LiteralPath $c)) { continue }
    try {
      $probe = & $c -e "const z=require('zlib'); process.stdout.write(process.versions.node + ' ' + typeof z.zstdDecompressSync)" 2>$null
      if ($LASTEXITCODE -ne 0 -or $probe -notmatch '^(\d+)\.(\d+)') { continue }
      $major = [int]$Matches[1]; $minor = [int]$Matches[2]
      if ($major -lt 22 -or ($major -eq 22 -and $minor -lt 15)) { Write-DebugLog ("node too old: $c $probe"); continue }
      if ($probe -notmatch 'function') { Write-DebugLog ("node missing zstd: $c $probe"); continue }
      return $c
    } catch { }
  }
  return $null
}

function Start-Core {
  if ($NoCore -or $Preview) { return }
  if ($null -ne $script:CoreProc -and -not $script:CoreProc.HasExited) { return }
  if ($script:CoreRestarts -ge 5) { return }
  try {
    Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'node.exe' -and $_.CommandLine -like "*$script:CorePath*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  } catch { }
  $node = Get-NodePath
  if ($null -eq $node) { return }
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $node
    $psi.Arguments = '"{0}" --state "{1}" --config "{2}"' -f $script:CorePath, $script:StatePath, $script:ConfigPath
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = $script:AppDir
    $script:CoreProc = [System.Diagnostics.Process]::Start($psi)
    $script:CoreRestarts++
    $script:CoreStartedAt = [DateTime]::Now
    $script:LastReconnectAt = [DateTime]::Now
    Write-DebugLog ("core started pid={0}" -f $script:CoreProc.Id)
  } catch { }
}

function Stop-Core {
  try {
    if ($null -ne $script:CoreProc -and -not $script:CoreProc.HasExited) {
      $script:CoreProc.Kill()
    }
  } catch { }
}

Start-Core

# ── 大小 ─────────────────────────────────────────────────────────────────
$script:BaseW = 400
$script:BaseH = 470
$script:BaseImg = 270
$script:TopInset = 29.5
$script:Gap = 31.5
$script:ShadowW = 120
$script:ShadowH = 14
if ($script:Mascot -eq 'fish') {
  $script:BaseW = 380
  $script:BaseH = 432
  $script:BaseImg = 210
  $script:TopInset = 0
  $script:Gap = 30
  $script:ShadowW = 150
  $script:ShadowH = 18
}
if ($script:Mascot -eq 'whale') {
  $script:BaseH = 570
  $script:BaseImg = 370
  $script:TopInset = 0
  $script:Gap = 30
  $script:ShadowW = 130
  $script:ShadowH = 16
}

function Get-MascotSize([double]$s) {
  $imgH = $script:BaseImg * $s
  $h = $script:BaseH + ($imgH - $script:BaseImg)
  $w = [Math]::Max($script:BaseW, [Math]::Ceiling($script:BaseW * $s))
  $visibleTop = $h - $imgH + $script:TopInset * $s
  $margin = $h - ($visibleTop - $script:Gap)
  return [pscustomobject]@{ W = [double]$w; H = [double]$h; Margin = [double]$margin }
}

function Set-MascotVisual([double]$s) {
  if ($null -ne $script:MascotScale) {
    try { $script:MascotScale.ScaleX = $s; $script:MascotScale.ScaleY = $s } catch { }
  }
  if ($script:Mascot -ne 'fish' -and $null -ne $script:BubbleHost) {
    $m = Get-MascotSize $s
    try { $script:BubbleHost.Margin = [Windows.Thickness]::new(0, 0, 0, [double]$m.Margin) } catch { }
  }
  if ($null -ne $script:GroundShadow) {
    try {
      $script:GroundShadow.Width = $script:ShadowW * $s
      $script:GroundShadow.Height = $script:ShadowH * $s
    } catch { }
  }
}

function Resize-MascotWindow {
  $oldRight = [double]$script:Window.Left + [double]$script:Window.Width
  $oldBottom = [double]$script:Window.Top + [double]$script:Window.Height
  $m = Get-MascotSize $script:Scale
  $script:Window.Width = $m.W
  $script:Window.Height = $m.H
  $script:Window.Left = $oldRight - $m.W
  $script:Window.Top = $oldBottom - $m.H
  $script:Window.Left = [Math]::Max($script:WorkArea.Left, [Math]::Min($script:Window.Left, $script:WorkArea.Right - $m.W))
  $script:Window.Top = [Math]::Max($script:WorkArea.Top, [Math]::Min($script:Window.Top, $script:WorkArea.Bottom - $m.H))
}

function Apply-MascotScale([double]$s, [bool]$save) {
  if ($script:Mascot -eq 'fish') { return }
  $s = [Math]::Max(0.7, [Math]::Min(1.4, $s))
  $script:Scale = $s
  Set-MascotVisual $s
  if ($null -ne $script:SizePctButton) {
    try { $script:SizePctButton.Text = ([int][Math]::Round($s * 100)).ToString() + '%' } catch { }
  }
  # 菜单打开时先只缩放画面，等菜单关闭再移动/缩放窗口，避免菜单跟着跳走
  if ($null -ne $script:Menu -and $script:Menu.Visible) {
    $script:PendingResize = $true
    return
  }
  Resize-MascotWindow
  if ($save) { Save-WindowPos }
  Write-DebugLog ("mascot scale -> " + [int][Math]::Round($s * 100) + "%")
}

# ── 窗口位置 ─────────────────────────────────────────────────────────────
$script:WorkArea = [System.Windows.SystemParameters]::WorkArea
$metrics = Get-MascotSize $script:Scale
$script:Window.Width = $metrics.W
$script:Window.Height = $metrics.H
$winW = [double]$script:Window.Width
$winH = [double]$script:Window.Height

$defaultLeft = $script:WorkArea.Right - $winW - 18
$defaultTop = $script:WorkArea.Bottom - $winH - 6

$initialLeft = $defaultLeft
$initialTop = $defaultTop
$restored = $false
try {
  if ($null -ne $script:Ui.left -and $null -ne $script:Ui.top) {
    $l = [double]$script:Ui.left
    $t = [double]$script:Ui.top
    # 虚拟桌面（含多显示器）里至少还要露出一部分，才按关闭前的原坐标恢复；
    # 不强行把右边缘贴回屏幕内，避免每次启动都往左挪。
    $v = [System.Windows.Forms.SystemInformation]::VirtualScreen
    if (($l + $winW) -gt ($v.Left + 40) -and $l -lt ($v.Right - 40) -and
        ($t + $winH) -gt ($v.Top + 40) -and $t -lt ($v.Bottom - 40)) {
      $initialLeft = $l
      $initialTop = $t
      $restored = $true
    }
  }
} catch { }
if (-not $restored) {
  $initialLeft = [Math]::Max($script:WorkArea.Left, [Math]::Min($initialLeft, $script:WorkArea.Right - $winW))
  $initialTop = [Math]::Max($script:WorkArea.Top, [Math]::Min($initialTop, $script:WorkArea.Bottom - $winH))
}

$script:Window.Left = $initialLeft
$script:Window.Top = $initialTop
Set-MascotVisual $script:Scale

function Save-WindowPos {
  try {
    $script:Ui | Add-Member -NotePropertyName left -NotePropertyValue ([double]$script:Window.Left) -Force
    $script:Ui | Add-Member -NotePropertyName top -NotePropertyValue ([double]$script:Window.Top) -Force
    $script:Ui | Add-Member -NotePropertyName collapsed -NotePropertyValue ([bool]$script:Collapsed) -Force
    $script:Ui | Add-Member -NotePropertyName sound -NotePropertyValue ([bool]$script:SoundOn) -Force
    $script:Ui | Add-Member -NotePropertyName pinned -NotePropertyValue ([string]$script:PinnedSessionId) -Force
    $script:Ui | Add-Member -NotePropertyName scale -NotePropertyValue ([double]$script:Scale) -Force
    $script:Ui | Add-Member -NotePropertyName notify -NotePropertyValue ([bool]$script:NotifyOn) -Force
    $script:Ui | Add-Member -NotePropertyName topmost -NotePropertyValue ([bool]$script:Topmost) -Force
    $script:Ui | Add-Member -NotePropertyName material -NotePropertyValue ([string]$script:Material) -Force
    Save-JsonFile $script:UiPath $script:Ui
  } catch { }
}

# ── 界面状态 ─────────────────────────────────────────────────────────────
$script:LastSignature = ''
$script:LastCompletionId = $null
$script:SeenCompletionIds = @{}
$script:FirstStateSeen = $false
$script:IdleSince = $null
$script:AutoHidden = $false
$script:CurrentState = $null
$script:CurrentUrl = ''
$script:LastActivity = ''

function Show-Bubble {
  if ($script:AutoHidden) { return }
  $script:BubbleHost.Visibility = [Windows.Visibility]::Visible
  try {
    $anim = New-Object Windows.Media.Animation.DoubleAnimation
    $anim.From = 12.0; $anim.To = 0.0
    $anim.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(260))
    $anim.EasingFunction = (New-Object Windows.Media.Animation.CubicEase)
    $script:BubbleSlide.BeginAnimation([Windows.Media.Animation.TranslateTransform]::YProperty, $anim)
    $fade = New-Object Windows.Media.Animation.DoubleAnimation
    $fade.From = 0.0; $fade.To = 1.0
    $fade.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(240))
    $script:BubbleHost.BeginAnimation([Windows.UIElement]::OpacityProperty, $fade)
  } catch { }
}

function Hide-Bubble {
  $script:BubbleHost.Visibility = [Windows.Visibility]::Collapsed
}

function Set-DotColor([string]$color) {
  try { $script:Dot.Fill = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($color)) } catch { }
}

function Set-BarColor([bool]$done) {
  try {
    if ($done) { $script:BarFill.Background = $script:Window.Resources['BarDoneBrush'] }
    else { $script:BarFill.Background = $script:Window.Resources['BarBrush'] }
  } catch { }
}

function Set-Progress([double]$ratio, [bool]$done) {
  $track = 314.0
  try { if ($script:BarTrack.ActualWidth -gt 10) { $track = $script:BarTrack.ActualWidth } } catch { }
  if ($ratio -lt 0) { $ratio = 0 }
  if ($ratio -gt 1) { $ratio = 1 }
  $script:BarFill.Width = [Math]::Round($track * $ratio, 1)
  Set-BarColor $done
}

function Set-Compact([bool]$compact) {
  $vis = if ($compact) { [Windows.Visibility]::Collapsed } else { [Windows.Visibility]::Visible }
  $script:TaskText.Visibility = $vis
  $script:MetaText.Visibility = $vis
}

function Set-DesiredFrameRates {
  foreach ($sb in @($script:SbBob, $script:SbCelebrate, $script:SbSparkle, $script:SbBubbles, $script:SbDot, $script:SbBlink, $script:SbSway, $script:SbTail, $script:SbFin)) {
    if ($null -ne $sb) {
      try { [System.Windows.Media.Animation.Timeline]::SetDesiredFrameRate($sb, 30) } catch { }
    }
  }
}

function Set-LoopAnimations([bool]$on) {
  if ($on -and $script:WindowHidden) { return }
  foreach ($sb in @($script:SbSway, $script:SbTail, $script:SbFin, $script:SbBob)) {
    if ($null -eq $sb) { continue }
    try {
      if ($on) { $sb.Begin($script:Window, $true) } else { $sb.Stop($script:Window) }
    } catch { }
  }
}

function Start-Loops {
  Set-DesiredFrameRates
  Set-LoopAnimations $true
}

function Toggle-Bubbles([bool]$on) {
  try {
    if ($on) { $script:SbBubbles.Begin($script:Window, $true) } else { $script:SbBubbles.Stop($script:Window) }
  } catch { }
}

function Toggle-DotPulse([bool]$on) {
  try {
    if ($on) { $script:SbDot.Begin($script:Window, $true) } else { $script:SbDot.Stop($script:Window); $script:Dot.Opacity = 1.0 }
  } catch { }
}

function Start-Celebrate {
  try { $script:SbCelebrate.Begin($script:Window, $true) } catch { }
  try { $script:SbSparkle.Begin($script:Window, $true) } catch { }
  try { $script:DoneBadge.Opacity = 1.0 } catch { }
  try {
    $script:HappyEyes.Opacity = 1.0
    $script:HappyMouth.Opacity = 1.0
    $script:Mouth.Opacity = 0.0
    $script:EyeL.Opacity = 0.0
    $script:EyeR.Opacity = 0.0
  } catch { }
}

function Stop-Celebrate {
  try { $script:SbCelebrate.Stop($script:Window) } catch { }
  try { $script:SbSparkle.Stop($script:Window) } catch { }
  try { $script:DoneBadge.Opacity = 0.0 } catch { }
  try {
    if ($script:HappyEyes.Opacity -gt 0) {
      $script:HappyEyes.Opacity = 0.0
      $script:HappyMouth.Opacity = 0.0
      $script:Mouth.Opacity = 1.0
      $script:EyeL.Opacity = 1.0
      $script:EyeR.Opacity = 1.0
    }
  } catch { }
}

# ── 托盘提醒 ─────────────────────────────────────────────────────────────
$script:Tray = $null
$script:TraySoundItem = $null
$script:HotkeyRegistered = $false
$script:HotkeyHwnd = [IntPtr]::Zero
$script:HotkeySource = $null
$script:HotkeyHandler = $null
$script:HotkeyId = 0x4A01

function Hide-FishWindow {
  if ($null -eq $script:Tray -and -not $script:HotkeyRegistered) {
    try { [void][System.Windows.MessageBox]::Show('托盘图标和全局热键都不可用，躲起来后将无法恢复；已取消。', 'DSH 大肥鱼', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) } catch { }
    return
  }
  $script:WindowHidden = $true
  Set-LoopAnimations $false
  try { $script:Window.Hide() } catch { }
}

function Show-FishWindow {
  $script:WindowHidden = $false
  try {
    $script:Window.Show()
    $script:Window.Activate()
  } catch { }
}

function Toggle-FishWindow {
  if ($null -eq $script:Window) { return }
  try {
    if ($script:Window.IsVisible) {
      Hide-FishWindow
      Write-DebugLog 'hotkey hide'
    } else {
      Show-FishWindow
      Write-DebugLog 'hotkey show'
    }
  } catch {
    Write-DebugLog ('toggle error: ' + $_.Exception.Message)
  }
}

function Register-Hotkey {
  if ($script:HotkeyRegistered) { return }
  try {
    $params = New-Object System.Windows.Interop.HwndSourceParameters('DSHFishHotkey')
    $params.WindowStyle = 0
    $source = New-Object System.Windows.Interop.HwndSource($params)
    if ($null -eq $source -or $source.Handle -eq [IntPtr]::Zero) {
      Write-DebugLog 'hotkey window failed'
      return
    }
    $script:HotkeySource = $source
    $hwnd = $source.Handle
    $ok = [DshFishWin]::RegisterHotKey($hwnd, $script:HotkeyId, 0x0003, 0x48)
    if (-not $ok) {
      Write-DebugLog 'hotkey register failed'
      try { $source.Dispose() } catch { }
      $script:HotkeySource = $null
      return
    }
    $script:HotkeyRegistered = $true
    $script:HotkeyHwnd = $hwnd
    $script:HotkeyHandler = [System.Windows.Interop.HwndSourceHook]{
      param($h, $msg, $w, $l, [ref]$handled)
      if ($msg -eq 0x0312 -and $w -eq $script:HotkeyId) {
        Write-DebugLog 'hotkey message'
        Toggle-FishWindow
        $handled.Value = $true
      }
      return [IntPtr]::Zero
    }
    [void]$source.AddHook($script:HotkeyHandler)
    Write-DebugLog 'hotkey Ctrl+Alt+H registered'
  } catch {
    Write-DebugLog ('hotkey error: ' + $_.Exception.Message)
  }
}

function Unregister-Hotkey {
  try { if ($null -ne $script:HotkeySource -and $null -ne $script:HotkeyHandler) { $script:HotkeySource.RemoveHook($script:HotkeyHandler) } } catch { }
  try { if ($script:HotkeyRegistered -and $script:HotkeyHwnd -ne [IntPtr]::Zero) { [void][DshFishWin]::UnregisterHotKey($script:HotkeyHwnd, $script:HotkeyId) } } catch { }
  try { if ($null -ne $script:HotkeySource) { $script:HotkeySource.Dispose() } } catch { }
  $script:HotkeyRegistered = $false
  $script:HotkeyHwnd = [IntPtr]::Zero
  $script:HotkeySource = $null
  $script:HotkeyHandler = $null
}

function Init-Tray {
  if ($null -ne $script:Tray) { return }
  if ($null -ne $script:Config -and $script:Config.tray -eq $false) { Write-DebugLog 'tray disabled by config'; return }
  Write-DebugLog ("tray init: icon exists=" + (Test-Path -LiteralPath $script:IconPath))
  try {
    $script:Tray = New-Object System.Windows.Forms.NotifyIcon
    if (Test-Path -LiteralPath $script:IconPath) {
      $script:Tray.Icon = New-Object System.Drawing.Icon($script:IconPath)
    } else {
      $script:Tray.Icon = [System.Drawing.SystemIcons]::Application
    }
    $script:Tray.Text = 'DSH 大肥鱼'
    $script:Tray.Visible = $true
    $script:Tray.Add_DoubleClick({ Open-Dsh })

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $menu.ShowImageMargin = $false
    $menu.ShowCheckMargin = $false
    $menu.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
    $menu.ForeColor = [System.Drawing.Color]::FromArgb(242, 246, 255)
    $menu.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
    try { $menu.Renderer = New-Object DshFishRenderer (New-Object DshFishMenuColors) } catch { }
    $miOpen = $menu.Items.Add('打开 DSH')
    $miOpen.Add_Click({ Open-Dsh })
    $miPet = $menu.Items.Add('摸摸头')
    $miPet.Add_Click({ Pet-Mascot })
    $miSizeTray = $menu.Items.Add('自定义大小…')
    $miSizeTray.Add_Click({ Show-SizeInput $null })
    $miBigTray = $menu.Items.Add('放大一点')
    $miBigTray.Add_Click({ Apply-MascotScale ($script:Scale + 0.1) $true })
    $miSmallTray = $menu.Items.Add('缩小一点')
    $miSmallTray.Add_Click({ Apply-MascotScale ($script:Scale - 0.1) $true })
    $miToggle = $menu.Items.Add('显示 / 隐藏大肥鱼')
    $miToggle.Add_Click({ Toggle-FishWindow })
    $miDetail = $menu.Items.Add('显示 / 隐藏详情')
    $miDetail.Add_Click({ Toggle-Collapsed })
    $miPinTray = $menu.Items.Add('把图标固定到任务栏…')
    $miPinTray.Add_Click({ Open-TraySettings })
    $soundLabel = if ($script:SoundOn) { '提醒音：开' } else { '提醒音：关' }
    $miSound = $menu.Items.Add($soundLabel)
    $script:TraySoundItem = $miSound
    $miSound.Add_Click({
      $script:SoundOn = -not $script:SoundOn
      if ($script:SoundOn) { $miSound.Text = '提醒音：开' } else { $miSound.Text = '提醒音：关' }
      $script:Ui | Add-Member -NotePropertyName sound -NotePropertyValue ([bool]$script:SoundOn) -Force
      Save-WindowPos
    })
    $miReset = $menu.Items.Add('重置位置')
    $miReset.Add_Click({ Reset-Position })
    $miReadme = $menu.Items.Add('打开说明')
    $miReadme.Add_Click({ try { Start-Process (Join-Path $script:AppDir 'README.md') | Out-Null } catch { } })
    $miUpdateTray = $menu.Items.Add('检查更新')
    $miUpdateTray.Add_Click({ Check-Update })
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $miExit = $menu.Items.Add('退出大肥鱼')
    $miExit.Add_Click({ Exit-FishWidget })
    foreach ($it in $menu.Items) {
      if ($it -is [System.Windows.Forms.ToolStripMenuItem]) {
        $it.ForeColor = [System.Drawing.Color]::FromArgb(242, 246, 255)
        $it.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
      }
    }
    $script:Tray.ContextMenuStrip = $menu
    $menu.Add_Opened({ Set-RoundedMenu $menu 8 })
    try { Set-MenuTheme $menu $script:Material } catch { }
    $script:Tray.Add_BalloonTipClicked({ Open-Dsh })
    Write-DebugLog ("tray visible=" + $script:Tray.Visible + " text=" + $script:Tray.Text)
  } catch { Write-DebugLog ("tray init failed: " + $_.Exception.Message) }
}

function Notify-Completion([string]$title, [string]$body) {
  if (-not $script:NotifyOn) { return }
  try {
    if ($null -ne $script:Tray) {
      $script:Tray.ShowBalloonTip(6000, $title, $body, [System.Windows.Forms.ToolTipIcon]::None)
      return
    }
    # tray=false 时用临时托盘图标发通知，避免 notify 被静默禁用。
    $icon = New-Object System.Windows.Forms.NotifyIcon
    $icon.Icon = [System.Drawing.SystemIcons]::Information
    $icon.Visible = $true
    $icon.ShowBalloonTip(6000, $title, $body, [System.Windows.Forms.ToolTipIcon]::None)
    $script:TempNotifyIcon = $icon
    if ($null -eq $script:TempNotifyTimer) {
      $script:TempNotifyTimer = New-Object System.Windows.Threading.DispatcherTimer
      $script:TempNotifyTimer.Interval = [TimeSpan]::FromSeconds(8)
      $script:TempNotifyTimer.Add_Tick({
        try {
          $script:TempNotifyTimer.Stop()
          if ($null -ne $script:TempNotifyIcon) { $script:TempNotifyIcon.Visible = $false; $script:TempNotifyIcon.Dispose() }
        } catch { }
        $script:TempNotifyIcon = $null
      })
    }
    if (-not $script:TempNotifyTimer.IsEnabled) { $script:TempNotifyTimer.Start() }
  } catch { }
}

# ── 打开 / 聚焦 DSH ──────────────────────────────────────────────────────
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class DshFishWin {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr hWnd, bool altTab);
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, int flags);
  [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
  [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
  [DllImport("user32.dll")] public static extern bool SetLayeredWindowAttributes(IntPtr hwnd, uint crKey, byte bAlpha, uint dwFlags);
}
"@

function Open-Dsh {
  Write-DebugLog 'Open-Dsh'
  $handles = @()
  try {
    foreach ($p in [System.Diagnostics.Process]::GetProcesses()) {
      try {
        if ($p.MainWindowHandle -ne [IntPtr]::Zero -and
            ($p.ProcessName -like '*DeepSeek*' -or $p.ProcessName -like '*Harness*' -or $p.ProcessName -like '*dsh*')) {
          $handles += , @($p.MainWindowHandle, $p.Id)
        }
      } catch { }
    }
  } catch { }
  Write-DebugLog ("found {0} candidate windows" -f $handles.Count)
  foreach ($h in $handles) {
    try {
      $hwnd = [IntPtr]$h[0]
      if ([DshFishWin]::IsIconic($hwnd)) { [void][DshFishWin]::ShowWindow($hwnd, 9) }
      else { [void][DshFishWin]::ShowWindow($hwnd, 5) }
      [void][DshFishWin]::SwitchToThisWindow($hwnd, $true)
      $ok = [DshFishWin]::SetForegroundWindow($hwnd)
      if (-not $ok) {
        # 允许后台进程抢占前台的经典 Alt 技巧
        [void][DshFishWin]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
        [void][DshFishWin]::SetForegroundWindow($hwnd)
        [void][DshFishWin]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
      }
      Write-DebugLog ("focused hwnd={0}" -f $hwnd)
      return
    } catch { }
  }
  try {
    if ($script:CurrentUrl -and (Test-AllowedDshUrl $script:CurrentUrl)) {
      Start-Process $script:CurrentUrl | Out-Null
      Write-DebugLog ("fallback open {0}" -f $script:CurrentUrl)
    } elseif ($script:CurrentUrl) {
      Write-DebugLog ("blocked dshUrl {0}" -f $script:CurrentUrl)
    }
  } catch { }
}

function Set-Pin([string]$id) {
  $script:PinnedSessionId = $id
  try {
    $script:Ui | Add-Member -NotePropertyName pinned -NotePropertyValue $id -Force
    Save-JsonFile $script:UiPath $script:Ui
  } catch { }
  Write-DebugLog ("pin session: '" + $id + "'")
}

function Test-WindowOnScreen {
  try {
    if ($null -eq $script:Window) { return $false }
    $l = [double]$script:Window.Left
    $t = [double]$script:Window.Top
    $w = [double]$script:Window.ActualWidth
    $h = [double]$script:Window.ActualHeight
    if ($w -le 0) { $w = [double]$script:Window.Width }
    if ($h -le 0) { $h = [double]$script:Window.Height }
    if ($w -le 0 -or $h -le 0) { return $false }
    $sx = 1.0; $sy = 1.0
    try {
      $source = [System.Windows.PresentationSource]::FromVisual($script:Window)
      if ($null -ne $source -and $null -ne $source.CompositionTarget) {
        $m = $source.CompositionTarget.TransformToDevice
        if ($m.M11 -gt 0) { $sx = $m.M11 }
        if ($m.M22 -gt 0) { $sy = $m.M22 }
      }
    } catch { }
    foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
      $a = $s.WorkingArea
      $al = $a.Left / $sx; $at = $a.Top / $sy
      $ar = $a.Right / $sx; $ab = $a.Bottom / $sy
      $ix = [Math]::Min($l + $w, $ar) - [Math]::Max($l, $al)
      $iy = [Math]::Min($t + $h, $ab) - [Math]::Max($t, $at)
      if ($ix -ge 40 -and $iy -ge 40) { return $true }
    }
  } catch { }
  return $false
}

function Ensure-OnScreen {
  if (-not (Test-WindowOnScreen)) { Reset-Position }
}

function Exit-FishWidget {
  try { Set-Content -LiteralPath (Join-Path $script:AppDir 'quit.flag') -Value (Get-Date).ToString('o') -Encoding UTF8 } catch { }
  $script:Window.Close()
}

function Reset-Position {
  try {
    $w = [double]$script:Window.Width
    $h = [double]$script:Window.Height
    $script:Window.Left = $script:WorkArea.Right - $w - 18
    $script:Window.Top = $script:WorkArea.Bottom - $h - 6
    Save-WindowPos
  } catch { }
}

function Pet-Mascot {
  $script:PetUntil = [DateTime]::Now.AddSeconds(2.2)
  try { $script:SbCelebrate.Begin($script:Window) } catch { }
  Play-Chime
  Write-DebugLog 'pet'
}

function Set-Hover([bool]$on) {
  if ($null -eq $script:HoverScale) { return }
  $to = if ($on) { 1.05 } else { 1.0 }
  try {
    foreach ($prop in @([Windows.Media.ScaleTransform]::ScaleXProperty, [Windows.Media.ScaleTransform]::ScaleYProperty)) {
      $anim = New-Object Windows.Media.Animation.DoubleAnimation
      $anim.To = $to
      $anim.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(150))
      $anim.EasingFunction = New-Object Windows.Media.Animation.CubicEase
      $script:HoverScale.BeginAnimation($prop, $anim)
    }
  } catch { }
}

# ── 交互 ─────────────────────────────────────────────────────────────────
$script:Drag = $null

function Begin-Drag($sender, $e) {
  if ($e.ChangedButton -ne [Windows.Input.MouseButton]::Left) { return }
  $beforeLeft = [double]$script:Window.Left
  $beforeTop = [double]$script:Window.Top
  try { $script:Window.DragMove() } catch { return }
  $moved = (([Math]::Abs($script:Window.Left - $beforeLeft) + [Math]::Abs($script:Window.Top - $beforeTop)) -gt 1)
  if ($moved) {
    Write-DebugLog 'native drag moved'
    Save-WindowPos
    return
  }
  if ($script:ClickTimer.IsEnabled) {
    $script:ClickTimer.Stop()
    Show-Balance
    return
  }
  $script:ClickTimer.Start()
}

$script:ClickTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ClickTimer.Interval = [TimeSpan]::FromMilliseconds([System.Windows.Forms.SystemInformation]::DoubleClickTime)
$script:ClickTimer.Add_Tick({
  $script:ClickTimer.Stop()
  Toggle-Collapsed
})

function End-Drag($sender, $e) {
  if ($null -eq $script:Drag) { return }
  try { $script:Drag.Sender.ReleaseMouseCapture() } catch { }
  $moved = $script:Drag.Moved
  $script:Drag = $null
  Write-DebugLog ("End-Drag moved={0} clicks={1}" -f $moved, $e.ClickCount)
  if ($moved) { Save-WindowPos; return }
  if ($script:ClickTimer.IsEnabled) {
    # 240ms 内的第二次点击 = 双击
    $script:ClickTimer.Stop()
    Show-Balance
    return
  }
  $script:ClickTimer.Start()
}

# ── 模型余额 ─────────────────────────────────────────────────────────────
$script:BalanceShowing = $false
$script:BalanceBusy = $false
$script:BalanceJob = $null
$script:BalanceStarted = [DateTime]::Now
$script:BalanceTitle = '模型余额'
$script:BalanceModel = ''
$script:BalanceKind = ''

$script:BalanceRestore = New-Object System.Windows.Threading.DispatcherTimer
$script:BalanceRestore.Interval = [TimeSpan]::FromSeconds(3)
$script:BalanceRestore.Add_Tick({
  $script:BalanceRestore.Stop()
  $script:BalanceShowing = $false
})





function Toggle-Collapsed {
  if ($script:BubbleHost.Visibility -ne [Windows.Visibility]::Visible) {
    $script:IdleSince = [DateTime]::Now
    Show-Bubble
    return
  }
  $script:Collapsed = -not $script:Collapsed
  Set-Compact $script:Collapsed
  Save-WindowPos
  $script:LastSignature = ''
}

foreach ($target in @($script:FishHost, $script:Bubble)) {
  $target.Add_MouseLeftButtonDown({ param($s, $e) Begin-Drag $s $e })
  $target.Add_MouseRightButtonUp({
    param($s, $e)
    Show-Bubble
    Show-ContextMenu
    $e.Handled = $true
  })
}

$script:FishHost.Cursor = [Windows.Input.Cursors]::Hand
$script:FishHost.Add_MouseEnter({ Set-Hover $true })
$script:FishHost.Add_MouseLeave({ Set-Hover $false })

# 键盘入口：F10 / 菜单键打开右键菜单，后续可用方向键操作
$script:Window.Add_KeyDown({
  param($s, $e)
  if ($e.Key -eq [Windows.Input.Key]::F10 -or $e.Key -eq [Windows.Input.Key]::Apps) {
    Show-ContextMenu
    $e.Handled = $true
  }
})

# 右键菜单（WinForms，深色、无图标栏）
try {
  Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
public class DshFishMenuColors : ProfessionalColorTable {
  private static Color Bg = Color.FromArgb(18, 26, 50);
  private static Color Line = Color.FromArgb(52, 68, 110);
  private static Color Sel = Color.FromArgb(52, 72, 118);
  public override Color ToolStripDropDownBackground { get { return Bg; } }
  public override Color ImageMarginGradientBegin { get { return Bg; } }
  public override Color ImageMarginGradientMiddle { get { return Bg; } }
  public override Color ImageMarginGradientEnd { get { return Bg; } }
  public override Color MenuBorder { get { return Line; } }
  public override Color MenuItemBorder { get { return Sel; } }
  public override Color MenuItemSelected { get { return Sel; } }
  public override Color MenuItemSelectedGradientBegin { get { return Sel; } }
  public override Color MenuItemSelectedGradientEnd { get { return Sel; } }
  public override Color SeparatorDark { get { return Line; } }
  public override Color SeparatorLight { get { return Line; } }
}
public class DshFishRenderer : ToolStripProfessionalRenderer {
  public Color ArrowColor = Color.FromArgb(242, 246, 255);
  public bool Glass = false;
  public DshFishRenderer(ProfessionalColorTable table) : base(table) { }
  protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e) {
    if (!Glass) { base.OnRenderToolStripBackground(e); return; }
    Rectangle r = e.AffectedBounds;
    if (r.Width <= 0 || r.Height <= 0) return;
    using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(r.X, r.Y, r.Width, r.Height), Color.FromArgb(92, 98, 134), Color.FromArgb(62, 68, 100), 90f)) {
      e.Graphics.FillRectangle(b, r);
    }
  }
  protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e) {
    if (!Glass) { base.OnRenderToolStripBorder(e); return; }
    using (Pen p = new Pen(Color.FromArgb(154, 163, 200), 1)) {
      e.Graphics.DrawRectangle(p, 0, 0, Math.Max(0, e.ToolStrip.Width - 1), Math.Max(0, e.ToolStrip.Height - 1));
    }
  }
  protected override void OnRenderArrow(ToolStripArrowRenderEventArgs e) {
    Rectangle r = e.ArrowRectangle;
    if (r.Width <= 0 || r.Height <= 0) { base.OnRenderArrow(e); return; }
    using (SolidBrush b = new SolidBrush(ArrowColor)) {
      Point[] pts = new Point[] {
        new Point(r.Left + 2, r.Top + 1),
        new Point(r.Right - 1, r.Top + (r.Height / 2)),
        new Point(r.Left + 2, r.Bottom - 1)
      };
      e.Graphics.FillPolygon(b, pts);
    }
  }
}
public class DshFishMenuColorsLight : ProfessionalColorTable {
  private static Color Bg = Color.FromArgb(244, 248, 252);
  private static Color Line = Color.FromArgb(175, 189, 210);
  private static Color Sel = Color.FromArgb(220, 229, 242);
  public override Color ToolStripDropDownBackground { get { return Bg; } }
  public override Color ImageMarginGradientBegin { get { return Bg; } }
  public override Color ImageMarginGradientMiddle { get { return Bg; } }
  public override Color ImageMarginGradientEnd { get { return Bg; } }
  public override Color MenuBorder { get { return Line; } }
  public override Color MenuItemBorder { get { return Sel; } }
  public override Color MenuItemSelected { get { return Sel; } }
  public override Color MenuItemSelectedGradientBegin { get { return Sel; } }
  public override Color MenuItemSelectedGradientEnd { get { return Sel; } }
  public override Color SeparatorDark { get { return Line; } }
  public override Color SeparatorLight { get { return Line; } }
}
public class DshFishMenuColorsGlass : ProfessionalColorTable {
  private static Color Bg = Color.FromArgb(78, 84, 120);
  private static Color Line = Color.FromArgb(154, 163, 200);
  private static Color Sel = Color.FromArgb(102, 110, 154);
  public override Color ToolStripDropDownBackground { get { return Bg; } }
  public override Color ImageMarginGradientBegin { get { return Bg; } }
  public override Color ImageMarginGradientMiddle { get { return Bg; } }
  public override Color ImageMarginGradientEnd { get { return Bg; } }
  public override Color MenuBorder { get { return Line; } }
  public override Color MenuItemBorder { get { return Sel; } }
  public override Color MenuItemSelected { get { return Sel; } }
  public override Color MenuItemSelectedGradientBegin { get { return Sel; } }
  public override Color MenuItemSelectedGradientEnd { get { return Sel; } }
  public override Color SeparatorDark { get { return Line; } }
  public override Color SeparatorLight { get { return Line; } }
}
"@ -ReferencedAssemblies System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue
} catch { }

$script:Menu = New-Object System.Windows.Forms.ContextMenuStrip
$script:Menu.ShowImageMargin = $false
$script:Menu.ShowCheckMargin = $false
$script:Menu.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
$script:Menu.ForeColor = [System.Drawing.Color]::FromArgb(242, 246, 255)
$script:Menu.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
$script:Menu.Padding = New-Object System.Windows.Forms.Padding(4)
try {
  $script:Menu.Renderer = New-Object DshFishRenderer (New-Object DshFishMenuColors)
} catch { Write-DebugLog ('menu renderer init error: ' + $_.Exception.Message) }

$script:Menu.Add_Opened({
  Set-RoundedMenu $script:Menu 8
  foreach ($it in $script:Menu.Items) {
    if ($it.DropDownItems.Count -gt 0) {
      try {
        $dd = $it.DropDown
        if ($null -ne $dd) {
          Set-MenuTheme $dd $script:Material
          $handler = { Set-RoundedMenu $dd 8 }.GetNewClosure()
          $dd.Add_Opened($handler)
        }
      } catch {
        Write-DebugLog ('submenu theme error: ' + $_.Exception.Message)
      }
    }
  }
})

function Set-MenuControlTheme($ctrl, $bg, $fg, $line, $sel) {
  if ($null -eq $ctrl) { return }
  try { $ctrl.BackColor = $bg } catch { }
  if ($ctrl -is [System.Windows.Forms.Label] -or $ctrl -is [System.Windows.Forms.Button]) {
    try { $ctrl.ForeColor = $fg } catch { }
  }
  if ($ctrl -is [System.Windows.Forms.Button]) {
    try {
      $ctrl.FlatAppearance.BorderColor = $line
      $ctrl.FlatAppearance.MouseOverBackColor = $sel
      $ctrl.FlatAppearance.MouseDownBackColor = $sel
    } catch { }
  }
  foreach ($child in $ctrl.Controls) { Set-MenuControlTheme $child $bg $fg $line $sel }
}

function Set-MenuItemsTheme($items, $itemBg, $bg, $fg, $dim, $line, $sel, $renderer) {
  foreach ($it in $items) {
    if ($it -is [System.Windows.Forms.ToolStripSeparator]) { continue }
    try {
      $it.BackColor = $itemBg
      $it.ForeColor = if ($it.Enabled) { $fg } else { $dim }
    } catch { }
    if ($it -is [System.Windows.Forms.ToolStripControlHost] -and $null -ne $it.Control) {
      Set-MenuControlTheme $it.Control $bg $fg $line $sel
    }
    if ($it.DropDownItems.Count -gt 0) {
      $it.add_DropDownOpening({
        try { Set-MenuTheme $it.DropDown $script:Material } catch { Write-DebugLog ('submenu theme error: ' + $_.Exception.Message) }
        try {
          $dd = $it.DropDown
          $handler = { Set-RoundedMenu $dd 8 }.GetNewClosure()
          $dd.Add_Opened($handler)
        } catch { Write-DebugLog ('submenu open hook error: ' + $_.Exception.Message) }
      })
      Set-MenuItemsTheme $it.DropDownItems $itemBg $bg $fg $dim $line $sel $renderer
    }
  }
}

function Set-LayeredMenu($menu, [double]$opacity) {
  try {
    $h = $menu.Handle
    if ($h -eq [IntPtr]::Zero) { return }
    $ex = [DshFishWin]::GetWindowLong($h, -20)
    [void][DshFishWin]::SetWindowLong($h, -20, ($ex -bor 0x80000))
    $alpha = [byte][Math]::Max(20, [Math]::Min(255, [int]($opacity * 255)))
    [void][DshFishWin]::SetLayeredWindowAttributes($h, 0, $alpha, 2)
    [void][DshFishWin]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x0001 -bor 0x0002 -bor 0x0040)
  } catch {
    Write-DebugLog ('layered menu error: ' + $_.Exception.Message)
  }
}

function Set-RoundedMenu($menu, [int]$radius = 8) {
  try {
    if ($null -eq $menu -or $menu.Width -le 0 -or $menu.Height -le 0) { return }
    if ($menu.Width -le 40 -or $menu.Height -le 10) {
      try { $menu.BeginInvoke([Action]{ Set-RoundedMenu $menu $radius }) | Out-Null } catch { }
      return
    }
    $w = $menu.Width; $h = $menu.Height; $d = $radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc($w - $d - 1, 0, $d, $d, 270, 90)
    $path.AddArc($w - $d - 1, $h - $d - 1, $d, $d, 0, 90)
    $path.AddArc(0, $h - $d - 1, $d, $d, 90, 90)
    $path.CloseFigure()
    $menu.Region = New-Object System.Drawing.Region($path)
    $path.Dispose()
    Write-DebugLog ("rounded menu " + $menu.Width + "x" + $menu.Height)
    if ($script:Material -eq 'glass') { Set-LayeredMenu $menu 0.70 } else { Set-LayeredMenu $menu 1.0 }
  } catch { }
}

function Set-MenuTheme($menu, [string]$material) {
  if ($null -eq $menu) { return }
  $bg = [System.Drawing.Color]::FromArgb(18, 26, 50)
  $fg = [System.Drawing.Color]::FromArgb(242, 246, 255)
  $dim = [System.Drawing.Color]::FromArgb(150, 166, 205)
  $line = [System.Drawing.Color]::FromArgb(52, 68, 110)
  $sel = [System.Drawing.Color]::FromArgb(52, 72, 118)
  $table = New-Object DshFishMenuColors
  if ($material -eq 'white') {
    $bg = [System.Drawing.Color]::FromArgb(244, 248, 252)
    $fg = [System.Drawing.Color]::FromArgb(22, 33, 61)
    $dim = [System.Drawing.Color]::FromArgb(94, 111, 140)
    $line = [System.Drawing.Color]::FromArgb(175, 189, 210)
    $sel = [System.Drawing.Color]::FromArgb(220, 229, 242)
    $table = New-Object DshFishMenuColorsLight
  } elseif ($material -eq 'glass') {
    $bg = [System.Drawing.Color]::FromArgb(78, 84, 120)
    $fg = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $dim = [System.Drawing.Color]::FromArgb(218, 222, 232)
    $line = [System.Drawing.Color]::FromArgb(154, 163, 200)
    $sel = [System.Drawing.Color]::FromArgb(102, 110, 154)
    $table = New-Object DshFishMenuColorsGlass
  }
  $renderer = New-Object DshFishRenderer -ArgumentList $table
  $renderer.ArrowColor = $fg
  $renderer.Glass = ($material -eq 'glass')
  $menu.Renderer = $renderer
  $menu.BackColor = $bg
  $menu.ForeColor = $fg
  $itemBg = if ($material -eq 'glass') { [System.Drawing.Color]::Transparent } else { $bg }
  Set-MenuItemsTheme $menu.Items $itemBg $bg $fg $dim $line $sel $renderer
}

function Add-ContextItem([string]$text, [scriptblock]$action, [bool]$enabled = $true) {
  $it = New-Object System.Windows.Forms.ToolStripMenuItem
  $it.Text = $text
  $it.Enabled = $enabled
  if ($enabled) { $it.ForeColor = [System.Drawing.Color]::FromArgb(242, 246, 255) }
  else { $it.ForeColor = [System.Drawing.Color]::FromArgb(150, 166, 205) }
  $it.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
  $it.Padding = New-Object System.Windows.Forms.Padding(8, 4, 10, 4)
  if ($null -ne $action) { $it.Add_Click($action) }
  [void]$script:Menu.Items.Add($it)
  return $it
}

function New-DarkButton([string]$text, [int]$w, [scriptblock]$action) {
  $b = New-Object System.Windows.Forms.Button
  $b.Text = $text
  $b.Width = $w
  $b.Height = 24
  $b.FlatStyle = 'Flat'
  $b.UseVisualStyleBackColor = $false
  $b.BackColor = [System.Drawing.Color]::FromArgb(26, 36, 66)
  $b.ForeColor = [System.Drawing.Color]::FromArgb(234, 241, 255)
  $b.FlatAppearance.BorderSize = 1
  $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(64, 86, 140)
  $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(52, 72, 118)
  $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(64, 88, 140)
  $b.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
  $b.Cursor = [System.Windows.Forms.Cursors]::Hand
  $b.Add_Click($action)
  return $b
}

function Show-SizeInput([System.Windows.Forms.Button]$btn) {
  try {
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
    $cur = [int][Math]::Round($script:Scale * 100)
    $value = [Microsoft.VisualBasic.Interaction]::InputBox('输入缩放比例（70 - 140）：', 'DSH 大肥鱼 · 自定义大小', ([string]$cur))
    if ([string]::IsNullOrWhiteSpace($value)) { return }
    $n = 0
    if (-not [int]::TryParse($value.Trim().TrimEnd('%'), [ref]$n)) { return }
    Apply-MascotScale ($n / 100.0) $true
    if ($null -ne $btn) { $btn.Text = ([int][Math]::Round($script:Scale * 100)).ToString() + '%' }
  } catch { }
}

function Add-SizeRow {
  if ($script:Mascot -eq 'fish') {
    [void](Add-ContextItem '大小：固定（矢量鱼模式）' $null $false)
    return
  }

  $panel = New-Object System.Windows.Forms.TableLayoutPanel
  $panel.ColumnCount = 4
  $panel.RowCount = 1
  $panel.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
  $panel.Padding = New-Object System.Windows.Forms.Padding(8, 3, 8, 3)
  $panel.Margin = New-Object System.Windows.Forms.Padding(0)
  $panel.Size = New-Object System.Drawing.Size(224, 34)
  [void]$panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 56)))
  [void]$panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
  [void]$panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 64)))
  [void]$panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
  [void]$panel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))

  $lbl = New-Object System.Windows.Forms.Label
  $lbl.Text = '大小：'
  $lbl.AutoSize = $false
  $lbl.Dock = [System.Windows.Forms.DockStyle]::Fill
  $lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
  $lbl.ForeColor = [System.Drawing.Color]::FromArgb(200, 212, 245)
  $lbl.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
  [void]$panel.Controls.Add($lbl, 0, 0)

  $btnMinus = New-DarkButton '－' 30 { Apply-MascotScale ($script:Scale - 0.1) $true }
  $btnMinus.Dock = [System.Windows.Forms.DockStyle]::Fill
  $btnMinus.Margin = New-Object System.Windows.Forms.Padding(1, 1, 1, 1)
  [void]$panel.Controls.Add($btnMinus, 1, 0)

  $btnPct = New-DarkButton ((([int][Math]::Round($script:Scale * 100)).ToString()) + '%') 64 { Show-SizeInput $script:SizePctButton }
  $btnPct.Dock = [System.Windows.Forms.DockStyle]::Fill
  $btnPct.Margin = New-Object System.Windows.Forms.Padding(1, 1, 1, 1)
  $script:SizePctButton = $btnPct
  [void]$panel.Controls.Add($btnPct, 2, 0)

  $btnPlus = New-DarkButton '＋' 30 { Apply-MascotScale ($script:Scale + 0.1) $true }
  $btnPlus.Dock = [System.Windows.Forms.DockStyle]::Fill
  $btnPlus.Margin = New-Object System.Windows.Forms.Padding(1, 1, 1, 1)
  [void]$panel.Controls.Add($btnPlus, 3, 0)

  try {
    $rowHost = New-Object System.Windows.Forms.ToolStripControlHost -ArgumentList $panel
  } catch {
    Write-DebugLog ("host ctor failed: " + $_.Exception.Message)
    return
  }
  $rowHost.AutoSize = $false
  $rowHost.Size = New-Object System.Drawing.Size(224, 34)
  $rowHost.Margin = New-Object System.Windows.Forms.Padding(0)
  $rowHost.Padding = New-Object System.Windows.Forms.Padding(0)
  $rowHost.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
  [void]$script:Menu.Items.Add($rowHost)

}

$script:Menu.Add_Closed({
  if ($script:PendingResize) {
    $script:PendingResize = $false
    try { Resize-MascotWindow } catch { }
    Save-WindowPos
  }
})

function Open-TraySettings {
  try { Start-Process 'ms-settings:taskbar' | Out-Null } catch { }
  try {
    [void][System.Windows.MessageBox]::Show("Windows 设置已打开。`n`n请进入：个性化 → 任务栏 → 其他系统托盘图标，`n找到带蓝色鲸鱼娘图标的「Windows PowerShell」，把它打开，`n图标就会常驻在右下角。", 'DSH 大肥鱼')
  } catch { }
}

function Test-Autostart {
  try {
    $v = (Get-ItemProperty -Path $script:RunKey -Name 'DshFishBuddy' -ErrorAction Stop).DshFishBuddy
    return [bool]$v
  } catch { return $false }
}

function Toggle-Autostart {
  try {
    if (Test-Autostart) {
      Remove-ItemProperty -Path $script:RunKey -Name 'DshFishBuddy' -Force -ErrorAction SilentlyContinue
    } else {
      $root = $env:SystemRoot
      if (-not $root) { $root = 'C:\Windows' }
      $wscript = Join-Path $root 'System32\wscript.exe'
      $vbs = Join-Path $script:AppDir 'bin\fish-widget.vbs'
      $cmd = '"' + $wscript + '" "' + $vbs + '"'
      Set-ItemProperty -Path $script:RunKey -Name 'DshFishBuddy' -Value $cmd -Force
    }
  } catch {
    Write-DebugLog ('autostart error: ' + $_.Exception.Message)
    try { [void][System.Windows.MessageBox]::Show(('设置开机自启失败：`n' + $_.Exception.Message), 'DSH 大肥鱼', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) } catch { }
  }
}

function Toggle-Notify {
  $script:NotifyOn = -not $script:NotifyOn
  $script:Ui | Add-Member -NotePropertyName notify -NotePropertyValue ([bool]$script:NotifyOn) -Force
  Save-WindowPos
}

function Toggle-Topmost {
  $script:Topmost = -not $script:Topmost
  try { $script:Window.Topmost = [bool]$script:Topmost } catch { }
  $script:Ui | Add-Member -NotePropertyName topmost -NotePropertyValue ([bool]$script:Topmost) -Force
  Save-WindowPos
}

function Restart-Core {
  try {
    Stop-Core
    $script:CoreProc = $null
    Start-Sleep -Milliseconds 450
    $script:CoreRestarts = 0
    Start-Core
    if ($null -ne $script:Tray) {
      try { $script:Tray.ShowBalloonTip(2200, 'DSH 大肥鱼', '后端已重启', [System.Windows.Forms.ToolTipIcon]::None) } catch { }
    }
  } catch { }
}

function Open-Log {
  try {
    $log = Join-Path $script:AppDir 'logs\widget.log'
    if (Test-Path -LiteralPath $log) {
      Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $log + '"') | Out-Null
    } else {
      Start-Process -FilePath (Join-Path $script:AppDir 'logs') | Out-Null
    }
  } catch { }
}

function Open-AppDir {
  try { Start-Process -FilePath $script:AppDir | Out-Null } catch { }
}

function Open-ConfigFile {
  try { Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $script:ConfigPath + '"') | Out-Null } catch { }
}




function Show-About {
  $text = "DSH 大肥鱼 v$script:Version`n`n桌面鲸鱼娘进度挂件 for DeepSeek Harness`n`nMIT License`nhttps://github.com/PCYBlurF/dsh-fish-buddy`n`n非官方同人项目"
  [void][System.Windows.MessageBox]::Show($text, '关于 DSH 大肥鱼', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

function Add-SubItem($parent, [string]$text, [scriptblock]$action) {
  $it = New-Object System.Windows.Forms.ToolStripMenuItem
  $it.Text = $text
  $it.ForeColor = [System.Drawing.Color]::FromArgb(242, 246, 255)
  $it.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
  $it.Padding = New-Object System.Windows.Forms.Padding(8, 4, 10, 4)
  if ($null -ne $action) { $it.Add_Click($action) }
  [void]$parent.DropDownItems.Add($it)
  return $it
}

function Add-SettingsMenu {
  $set = New-Object System.Windows.Forms.ToolStripMenuItem
  $set.Text = '设置'
  $set.ForeColor = [System.Drawing.Color]::FromArgb(242, 246, 255)
  $set.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
  $set.Padding = New-Object System.Windows.Forms.Padding(8, 4, 10, 4)
  $set.DropDown.ShowImageMargin = $false
  $set.DropDown.ShowCheckMargin = $false
  $set.DropDown.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
  $set.DropDown.ForeColor = [System.Drawing.Color]::FromArgb(242, 246, 255)
  $set.DropDown.Font = $script:Menu.Font
  try { $set.DropDown.Renderer = $script:Menu.Renderer } catch { }

  $auto = if (Test-Autostart) { '开机自启：开' } else { '开机自启：关' }
  [void](Add-SubItem $set $auto { Toggle-Autostart })
  [void]$set.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  $notify = if ($script:NotifyOn) { '桌面通知：开' } else { '桌面通知：关' }
  [void](Add-SubItem $set $notify { Toggle-Notify })
  $top = if ($script:Topmost) { '总在最前：开' } else { '总在最前：关' }
  [void](Add-SubItem $set $top { Toggle-Topmost })
  [void]$set.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  [void](Add-SubItem $set '重启后端' { Restart-Core })
  [void](Add-SubItem $set '打开日志' { Open-Log })
  [void](Add-SubItem $set '打开安装目录' { Open-AppDir })
  [void](Add-SubItem $set '打开配置文件' { Open-ConfigFile })
  [void]$set.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  [void](Add-SubItem $set '检查更新' { Check-Update })
  [void](Add-SubItem $set '关于' { Show-About })
  [void]$script:Menu.Items.Add($set)
}

$script:GlassBorder = New-Object Windows.Media.LinearGradientBrush
$script:GlassBorder.StartPoint = New-Object Windows.Point(0, 0)
$script:GlassBorder.EndPoint = New-Object Windows.Point(1, 1)
[void]$script:GlassBorder.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(170, 175, 190, 212)), 0))
[void]$script:GlassBorder.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(70, 125, 145, 172)), 0.45))
[void]$script:GlassBorder.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(150, 205, 218, 236)), 1))
$script:GlassTail = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(248, 250, 252, 255))
$script:GlassTextShadow = New-Object Windows.Media.Effects.DropShadowEffect
$script:GlassTextShadow.Color = [Windows.Media.Colors]::Black
$script:GlassTextShadow.BlurRadius = 4
$script:GlassTextShadow.ShadowDepth = 0
$script:GlassTextShadow.Opacity = 0.6
$script:GlassFallback = New-Object Windows.Media.LinearGradientBrush
$script:GlassFallback.StartPoint = New-Object Windows.Point(0, 0)
$script:GlassFallback.EndPoint = New-Object Windows.Point(0.35, 1)
[void]$script:GlassFallback.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(90, 255, 255, 255)), 0))
[void]$script:GlassFallback.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(80, 16, 26, 48)), 0.4))
[void]$script:GlassFallback.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(150, 16, 26, 48)), 1))

function Get-BubbleRect {
  if ($null -eq $script:Bubble -or -not $script:Window.IsVisible -or -not $script:Bubble.IsVisible) {
    return ''
  }
  try {
    $dpi = [Windows.Media.VisualTreeHelper]::GetDpi($script:Bubble)
    $pt = $script:Bubble.PointToScreen([Windows.Point]::new(0, 0))
    $w = [int]($script:Bubble.ActualWidth * $dpi.DpiScaleX)
    $h = [int]($script:Bubble.ActualHeight * $dpi.DpiScaleY)
    if ($w -lt 20 -or $h -lt 20) { return '' }
    return ("{0},{1},{2},{3}" -f [int]$pt.X, [int]$pt.Y, $w, $h)
  } catch { Write-DebugLog ("rect error: " + $_.Exception.Message); return '' }
}

function Get-MascotRect {
  if ($null -eq $script:MascotImage -or -not $script:Window.IsVisible -or -not $script:MascotImage.IsVisible) {
    return ''
  }
  try {
    $dpi = [Windows.Media.VisualTreeHelper]::GetDpi($script:MascotImage)
    $pt = $script:MascotImage.PointToScreen([Windows.Point]::new(0, 0))
    $w = [int]($script:MascotImage.ActualWidth * $dpi.DpiScaleX)
    $h = [int]($script:MascotImage.ActualHeight * $dpi.DpiScaleY)
    if ($w -lt 20 -or $h -lt 20) { return '' }
    return ("{0},{1},{2},{3}" -f [int]$pt.X, [int]$pt.Y, $w, $h)
  } catch {
    return ''
  }
}

function Register-HitTest {
  if ($script:HitHookRegistered) { return }
  try {
    $helper = New-Object System.Windows.Interop.WindowInteropHelper($script:Window)
    $hwnd = $helper.Handle
    if ($hwnd -eq [IntPtr]::Zero) { return }
    $source = [System.Windows.Interop.HwndSource]::FromHwnd($hwnd)
    if ($null -eq $source) { return }
    $script:HitSource = $source
    $script:HitHook = [System.Windows.Interop.HwndSourceHook]{
      param($h, $msg, $w, $l, [ref]$handled)
      if ($msg -ne 0x84) { return [IntPtr]::Zero }
      $x = [int]($l -band 0xFFFF); if ($x -ge 0x8000) { $x -= 0x10000 }
      $y = [int](($l -shr 16) -band 0xFFFF); if ($y -ge 0x8000) { $y -= 0x10000 }
      $hitKey = "{0},{1},{2},{3},{4},{5}" -f [int]$script:Window.Left, [int]$script:Window.Top, [int]$script:Window.Width, [int]$script:Window.Height, [int]$script:Bubble.IsVisible, [int]$script:MascotImage.IsVisible
      if ($hitKey -ne $script:HitKey) {
        $script:HitKey = $hitKey
        $script:HitRects = @((Get-BubbleRect), (Get-MascotRect)) | Where-Object { $_ }
      }
      $inside = $false
      foreach ($rect in $script:HitRects) {
        if ([string]::IsNullOrEmpty($rect)) { continue }
        $p = $rect.Split(',')
        if ($p.Count -lt 4) { continue }
        $rx = [int]$p[0]; $ry = [int]$p[1]; $rw = [int]$p[2]; $rh = [int]$p[3]
        if ($x -ge $rx -and $x -le ($rx + $rw) -and $y -ge $ry -and $y -le ($ry + $rh)) { $inside = $true; break }
      }
      $handled.Value = $true
      if ($inside) { return [IntPtr]::Zero }
      return [IntPtr](-1)
    }
    [void]$source.AddHook($script:HitHook)
    $script:HitHookRegistered = $true
    Write-DebugLog 'hit-test hook installed'
  } catch {
    Write-DebugLog ('hit-test error: ' + $_.Exception.Message)
  }
}

$script:GlassLive = New-Object Windows.Media.LinearGradientBrush
$script:GlassLive.StartPoint = New-Object Windows.Point(0, 0)
$script:GlassLive.EndPoint = New-Object Windows.Point(0.35, 1)
[void]$script:GlassLive.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(252, 255, 255, 255)), 0))
[void]$script:GlassLive.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(246, 244, 249, 255)), 0.25))
[void]$script:GlassLive.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(242, 234, 241, 251)), 0.6))
[void]$script:GlassLive.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(250, 255, 255, 255)), 1))
$script:GlassBorder = New-Object Windows.Media.LinearGradientBrush
$script:GlassBorder.StartPoint = New-Object Windows.Point(0, 0)
$script:GlassBorder.EndPoint = New-Object Windows.Point(1, 1)
[void]$script:GlassBorder.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(235, 255, 255, 255)), 0))
[void]$script:GlassBorder.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(90, 255, 255, 255)), 0.45))
[void]$script:GlassBorder.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(190, 255, 255, 255)), 1))
$script:GlassTail = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(248, 250, 252, 255))
$script:GlassTextShadow = New-Object Windows.Media.Effects.DropShadowEffect
$script:GlassTextShadow.Color = [Windows.Media.Colors]::Black
$script:GlassTextShadow.BlurRadius = 4
$script:GlassTextShadow.ShadowDepth = 0
$script:GlassTextShadow.Opacity = 0.6
$script:GlassCountBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 213, 224, 255))
$script:GlassMetaBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 194, 208, 239))

$script:GlassWhite = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 244, 248, 252))
$script:GlassClear = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(51, 242, 246, 251))
$script:GlassBorderWhite = New-Object Windows.Media.LinearGradientBrush
$script:GlassBorderWhite.StartPoint = New-Object Windows.Point(0, 0)
$script:GlassBorderWhite.EndPoint = New-Object Windows.Point(1, 1)
[void]$script:GlassBorderWhite.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(170, 175, 190, 212)), 0))
[void]$script:GlassBorderWhite.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(70, 125, 145, 172)), 0.45))
[void]$script:GlassBorderWhite.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(150, 205, 218, 236)), 1))
$script:GlassBorderClear = New-Object Windows.Media.LinearGradientBrush
$script:GlassBorderClear.StartPoint = New-Object Windows.Point(0, 0)
$script:GlassBorderClear.EndPoint = New-Object Windows.Point(1, 1)
[void]$script:GlassBorderClear.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(235, 255, 255, 255)), 0))
[void]$script:GlassBorderClear.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(90, 255, 255, 255)), 0.45))
[void]$script:GlassBorderClear.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList ([Windows.Media.Color]::FromArgb(190, 255, 255, 255)), 1))
$script:GlassTailWhite = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 244, 248, 252))
$script:GlassTailClear = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(51, 242, 246, 251))
$script:GlassTitleBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 22, 33, 61))
$script:GlassTaskBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 43, 56, 85))
$script:GlassCountBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 82, 98, 127))
$script:GlassMetaBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 94, 111, 140))
$script:GlassBarTrackBrush = New-Object Windows.Media.SolidColorBrush -ArgumentList ([Windows.Media.Color]::FromArgb(255, 220, 229, 242))
$script:GlassTextShadow = New-Object Windows.Media.Effects.DropShadowEffect
$script:GlassTextShadow.Color = [Windows.Media.Colors]::Black
$script:GlassTextShadow.BlurRadius = 4
$script:GlassTextShadow.ShadowDepth = 0
$script:GlassTextShadow.Opacity = 0.6

function Apply-Material {
  if ($null -eq $script:Bubble -or $null -eq $script:GlassTint) { return }
  $white = $script:Material -eq 'white'
  $clear = $script:Material -eq 'glass'
  if ($white -or $clear) {
    $script:Bubble.Background = if ($white) { $script:GlassWhite } else { $script:GlassClear }
    $script:Bubble.BorderBrush = if ($white) { $script:GlassBorderWhite } else { $script:GlassBorderClear }
    if ($null -ne $script:BubbleTail) {
      $script:BubbleTail.Fill = if ($white) { $script:GlassTailWhite } else { $script:GlassTailClear }
      $script:BubbleTail.Stroke = if ($white) { $script:GlassBorderWhite } else { $script:GlassBorderClear }
      $script:BubbleTail.StrokeThickness = 1
    }
    $script:GlassTint.Visibility = [Windows.Visibility]::Collapsed
    if ($null -ne $script:GlassNoise) {
      $script:GlassNoise.Visibility = [Windows.Visibility]::Collapsed
      $script:GlassNoise.Opacity = if ($clear) { 0.3 } else { 0.85 }
    }
    if ($white) {
      if ($null -ne $script:BubbleContent) { $script:BubbleContent.Effect = $null }
      if ($null -ne $script:TitleText) { $script:TitleText.Foreground = $script:GlassTitleBrush }
      if ($null -ne $script:TaskText) { $script:TaskText.Foreground = $script:GlassTaskBrush }
      if ($null -ne $script:CountText) { $script:CountText.Foreground = $script:GlassCountBrush }
      if ($null -ne $script:MetaText) { $script:MetaText.Foreground = $script:GlassMetaBrush }
      if ($null -ne $script:BarTrack) { $script:BarTrack.Background = $script:GlassBarTrackBrush }
    } else {
      if ($null -ne $script:BubbleContent) { $script:BubbleContent.Effect = $script:GlassTextShadow }
      if ($null -ne $script:TitleText) { $script:TitleText.Foreground = $script:TitleColorDefault }
      if ($null -ne $script:TaskText) { $script:TaskText.Foreground = $script:TaskColorDefault }
      if ($null -ne $script:CountText) { $script:CountText.Foreground = $script:CountColorDefault }
      if ($null -ne $script:MetaText) { $script:MetaText.Foreground = $script:MetaColorDefault }
      if ($null -ne $script:BarTrack) { $script:BarTrack.Background = $script:BarTrackColorDefault }
    }
  } else {
    $script:Bubble.Background = $script:BubbleBrushDefault
    $script:Bubble.BorderBrush = $script:BubbleBorderDefault
    if ($null -ne $script:BubbleTail) {
      $script:BubbleTail.Fill = $script:BubbleTailDefault
      $script:BubbleTail.Stroke = $script:BubbleTailStrokeDefault
      $script:BubbleTail.StrokeThickness = 0
    }
    $script:GlassTint.Visibility = [Windows.Visibility]::Collapsed
    if ($null -ne $script:GlassNoise) { $script:GlassNoise.Visibility = [Windows.Visibility]::Collapsed }
    if ($null -ne $script:BubbleContent) { $script:BubbleContent.Effect = $null }
    if ($null -ne $script:TitleText) { $script:TitleText.Foreground = $script:TitleColorDefault }
    if ($null -ne $script:TaskText) { $script:TaskText.Foreground = $script:TaskColorDefault }
    if ($null -ne $script:CountText) { $script:CountText.Foreground = $script:CountColorDefault }
    if ($null -ne $script:MetaText) { $script:MetaText.Foreground = $script:MetaColorDefault }
    if ($null -ne $script:BarTrack) { $script:BarTrack.Background = $script:BarTrackColorDefault }
  }
}

function Show-ContextMenu {
  Write-DebugLog 'show context menu'
  $script:Menu.Items.Clear()
  [void](Add-ContextItem '打开 DSH' { Open-Dsh })
  [void](Add-ContextItem '摸摸头' { Pet-Mascot })
  try { Add-SizeRow } catch { Write-DebugLog ("Add-SizeRow failed: " + $_.Exception.Message) }
  if ($script:Mascot -eq 'chibi') {
    $mat = New-Object System.Windows.Forms.ToolStripMenuItem
    $mat.Text = '材质'
    $mat.ForeColor = [System.Drawing.Color]::FromArgb(242, 246, 255)
    $mat.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
    $mat.Padding = New-Object System.Windows.Forms.Padding(8, 4, 10, 4)
    $mat.DropDown.ShowImageMargin = $false
    $mat.DropDown.ShowCheckMargin = $false
    $mat.DropDown.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
    $mat.DropDown.ForeColor = [System.Drawing.Color]::FromArgb(242, 246, 255)
    $mat.DropDown.Font = $script:Menu.Font
    try { $mat.DropDown.Renderer = $script:Menu.Renderer } catch { }
    foreach ($opt in @(@('default', '深蓝色'), @('white', '白色磨砂'), @('glass', '透明玻璃'))) {
      $label = if ($script:Material -eq $opt[0]) { '✓ ' + $opt[1] } else { '   ' + $opt[1] }
      $mi = New-Object System.Windows.Forms.ToolStripMenuItem
      $mi.Text = $label
      $mi.ForeColor = [System.Drawing.Color]::FromArgb(242, 246, 255)
      $mi.BackColor = [System.Drawing.Color]::FromArgb(18, 26, 50)
      $mi.Padding = New-Object System.Windows.Forms.Padding(8, 4, 10, 4)
      $mi.Tag = $opt[0]
      $mi.Add_Click({ param($snd, $ev) Set-Material ([string]$snd.Tag) })
      [void]$mat.DropDownItems.Add($mi)
    }
    try { $mat.Add_MouseEnter({ $mat.ShowDropDown() }) } catch { }
    [void]$script:Menu.Items.Add($mat)
  }
  [void]$script:Menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  if ($script:PinnedSessionId) { [void](Add-ContextItem '会话：自动（最近任务）' { Set-Pin '' }) }
  else { [void](Add-ContextItem '✓ 会话：自动（最近任务）' { Set-Pin '' }) }
  $count = 0
  foreach ($v in @($script:CurrentSessions)) {
    if ($count -ge 4) { break }
    $id = [string](Get-Prop $v 'id')
    if (-not $id) { continue }
    $title = [string](Get-Prop $v 'title')
    if ($title.Length -gt 22) { $title = $title.Substring(0, 22) + '…' }
    $dot = '○'
    if ([bool](Get-Prop $v 'running')) { $dot = '●' }
    if ($id -eq $script:PinnedSessionId) { $label = "✓ 会话：$dot $title" } else { $label = "  会话：$dot $title" }
    $it = Add-ContextItem $label $null
    $it.Tag = $id
    $it.Add_Click({ param($snd, $ev) Set-Pin ([string]$snd.Tag) })
    $count++
  }
  [void]$script:Menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  [void](Add-ContextItem '显示 / 隐藏详情' { Toggle-Collapsed })
  if ($script:SoundOn) { [void](Add-ContextItem '提醒音：开' { Toggle-Sound }) }
  else { [void](Add-ContextItem '提醒音：关' { Toggle-Sound }) }
  [void](Add-ContextItem '把图标固定到任务栏…' { Open-TraySettings })
  [void](Add-ContextItem '重置位置' { Reset-Position })
  [void](Add-ContextItem '打开说明' { try { Start-Process (Join-Path $script:AppDir 'README.md') | Out-Null } catch { } })
  [void](Add-SettingsMenu)
  [void]$script:Menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  [void](Add-ContextItem '干脆躲起来（托盘恢复）' { Hide-FishWindow })
  [void](Add-ContextItem '退出大肥鱼' { Exit-FishWidget })
  try { Set-MenuTheme $script:Menu $script:Material } catch { Write-DebugLog ('menu theme error: ' + $_.Exception.Message) }
  try { $script:Menu.Show([System.Windows.Forms.Cursor]::Position) } catch { Write-DebugLog ('menu show error: ' + $_.Exception.Message) }
}

function Set-Material([string]$m) {
  if ($m -ne 'default' -and $m -ne 'white' -and $m -ne 'glass') { return }
  $script:Material = $m
  $script:Ui | Add-Member -NotePropertyName material -NotePropertyValue ([string]$m) -Force
  Save-WindowPos
  Apply-Material
  try {
    if ($null -ne $script:Tray -and $null -ne $script:Tray.ContextMenuStrip) {
      Set-MenuTheme $script:Tray.ContextMenuStrip $script:Material
    }
  } catch { }
}

function Toggle-Sound {
  $script:SoundOn = -not $script:SoundOn
  $script:Ui | Add-Member -NotePropertyName sound -NotePropertyValue ([bool]$script:SoundOn) -Force
  if ($null -ne $script:TraySoundItem) {
    try { $script:TraySoundItem.Text = if ($script:SoundOn) { '提醒音：开' } else { '提醒音：关' } } catch { }
  }
  Save-WindowPos
}

# 滚轮切换折叠
$script:Window.Add_MouseWheel({
  param($s, $e)
  if ($e.Delta -lt 0 -and -not $script:Collapsed) { Toggle-Collapsed }
  elseif ($e.Delta -gt 0 -and $script:Collapsed) { Toggle-Collapsed }
})

# ── 眨眼 ─────────────────────────────────────────────────────────────────
$script:BlinkTimer = New-Object System.Windows.Threading.DispatcherTimer
if ($null -ne $script:SbBlink) {
  $script:BlinkTimer.Interval = [TimeSpan]::FromSeconds(4.0)
  $script:BlinkTimer.Add_Tick({
    try { $script:SbBlink.Begin($script:Window) } catch { }
    $script:BlinkTimer.Interval = [TimeSpan]::FromMilliseconds((Get-Random -Minimum 2400 -Maximum 6200))
  })
  $script:BlinkTimer.Start()
}

# ── 状态渲染 ─────────────────────────────────────────────────────────────
function Apply-State($st) {
  if ($null -eq $st) { return }
  $script:CurrentState = $st
  $script:ActiveSessions = [int](Get-Prop $st 'activeSessions')
  $url = Get-Prop $st 'dshUrl'
  if ($url) { $script:CurrentUrl = [string]$url }

  $phase = [string](Get-Prop $st 'phase')
  if (-not $phase) { $phase = 'idle' }
  $session = Get-Prop $st 'session'
  $script:CurrentSessions = @(Get-Prop $st 'sessions')
  if ($script:PinnedSessionId) {
    $found = $null
    foreach ($v in $script:CurrentSessions) {
      if ([string](Get-Prop $v 'id') -eq $script:PinnedSessionId) { $found = $v; break }
    }
    if ($null -ne $found) {
      $session = $found
      try { $st.session = $found } catch { }
    } else {
      # core 会把 pinned 放进 sessions；暂时没拿到时保留 pin，避免静默取消固定。
      Write-DebugLog ('pinned session not in current sessions: ' + $script:PinnedSessionId)
    }
  }
  $now = [double](Get-Prop $st 'now')
  if (-not $now) { $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }

  # 新完成 → 庆祝 / 提醒（支持同一 tick 多个会话完成）
  $completions = @(Get-Prop $st 'completions')
  if ($completions.Count -eq 0) {
    $single = Get-Prop $st 'completion'
    if ($null -ne $single) { $completions = @($single) }
  }
  $newSeen = @{}
  foreach ($completion in $completions) {
    $cid = [string](Get-Prop $completion 'id')
    if (-not $cid) { continue }
    $newSeen[$cid] = 1
    if ($script:SeenCompletionIds.ContainsKey($cid)) { continue }
    $isFirst = -not $script:FirstStateSeen
    if (-not $isFirst -and [string](Get-Prop $completion 'reason') -eq 'completed') {
      $title = [string](Get-Prop $completion 'title')
      $dur = [double](Get-Prop $completion 'durationMs')
      Write-DebugLog ("completion celebrate: " + $cid)
      Start-Celebrate
      Play-Chime
      Notify-Completion 'DSH 大肥鱼 · 任务完成' ("$title · 用时 $(Format-Duration $dur)")
    }
  }
  $script:SeenCompletionIds = $newSeen
  $script:FirstStateSeen = $true

  $script:LastRenderAt = [DateTime]::Now
  $script:DisplayedSession = $session
  $script:DisplayedRunning = [bool](Get-Prop $session 'running')
  if ($null -eq $session) {
    Render-Idle
    return
  }

  $running = [bool](Get-Prop $session 'running')
  $lastTurn = Get-Prop $session 'lastTurn'
  $reason = if ($null -ne $lastTurn) { [string](Get-Prop $lastTurn 'reason') } else { '' }
  $endedAt = if ($null -ne $lastTurn) { [double](Get-Prop $lastTurn 'endedAt') } else { 0 }
  $sinceEnd = if ($endedAt -gt 0) { $now - $endedAt } else { [double]::MaxValue }

  if (-not $running) {
    if ($reason -eq 'completed' -and $sinceEnd -lt 90000) { Render-Done $session $lastTurn; return }
    if ($reason -eq 'error' -and $sinceEnd -lt 60000) { Render-Error $session $lastTurn; return }
    if (($reason -eq 'aborted' -or $reason -eq 'interrupted') -and $sinceEnd -lt 30000) { Render-Aborted $session $lastTurn; return }
    Render-Idle
    return
  }

  Render-Working $session $now
}

function Set-BubbleVisible([bool]$visible) {
  if ($visible -and -not $script:AutoHidden) {
    if ($script:BubbleHost.Visibility -ne [Windows.Visibility]::Visible) { Show-Bubble }
  } else {
    Hide-Bubble
  }
}

function Render-Idle {
  if ($script:BalanceShowing) { return }
  $script:LastSignature = ''
  Set-LoopAnimations $false
  Toggle-Bubbles $false
  Toggle-DotPulse $false
  Stop-Celebrate
  Set-Mouth $false
  Set-Alert $false
  Set-DotColor '#5C6B95'
  if ($null -eq $script:IdleSince) { $script:IdleSince = [DateTime]::Now }
  $idleFor = ([DateTime]::Now - $script:IdleSince).TotalSeconds
  if ([DateTime]::Now -lt $script:PetUntil) { Set-Sprite 'celebrate' 150 }
  elseif ($idleFor -gt 25) { Set-Sprite 'sleep' 1500 }
  else { Set-Sprite 'idle' 1100 }
  if ($idleFor -gt 12) {
    Hide-Bubble
  } else {
    Set-BubbleVisible $true
    $script:TitleText.Text = 'DSH 大肥鱼'
    $script:CountText.Text = ''
    $script:BarTrack.Visibility = [Windows.Visibility]::Collapsed
    Set-Compact $script:Collapsed
    $script:TaskText.Text = '待命中，有任务就交给我吧～'
    $script:MetaText.Text = '双击看模型余额'
  }
  if ($null -ne $script:Tray) { $script:Tray.Text = 'DSH 大肥鱼 · 待命中' }
}

function Render-Working($session, [double]$now) {
  if ($script:BalanceShowing) { return }
  $script:IdleSince = $null
  Set-LoopAnimations $true
  Toggle-Bubbles $true
  Toggle-DotPulse $true
  Stop-Celebrate
  Set-Mouth $false
  Set-Alert $false
  if ([DateTime]::Now -lt $script:PetUntil) { Set-Sprite 'celebrate' 150 } else { Set-Sprite 'working' 170 }
  Set-DotColor '#7C93FF'
  Set-BubbleVisible $true

  $title = [string](Get-Prop $session 'title')
  if (-not $title) { $title = '新的任务' }
  $script:TitleText.Text = $title

  $progress = Get-Prop $session 'progress'
  $total = 0; $done = 0; $ratio = 0.0
  if ($null -ne $progress) {
    $total = [int](Get-Prop $progress 'total')
    $done = [int](Get-Prop $progress 'completed')
    if ($total -gt 0) { $ratio = $done / $total }
  }
  $script:BarTrack.Visibility = if ($total -gt 0) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
  $active = [int]$script:ActiveSessions
  $countLabel = if ($total -gt 0) { "$done/$total" } else { '' }
  if ($active -gt 1) { $countLabel = if ($countLabel) { "$countLabel · ${active}个任务" } else { "$active 个任务" } }
  if ($total -gt 0) {
    Set-Progress $ratio $false
    $script:CountText.Text = $countLabel
  } else {
    $script:CountText.Text = $countLabel
  }

  $todos = Get-Prop $session 'todos'
  $current = if ($null -ne $progress) { [string](Get-Prop $progress 'current') } else { '' }
  $activity = Get-Prop $session 'activity'
  $detail = ''
  $actText = ''
  if ($null -ne $activity) {
    $actText = [string](Get-Prop $activity 'text')
    $detail = [string](Get-Prop $activity 'detail')
  }

  if ($current) {
    $script:TaskText.Text = '正在：' + $current
  } elseif ($detail) {
    $script:TaskText.Text = "$actText · $detail"
  } elseif ($actText) {
    $script:TaskText.Text = $actText
  } else {
    $script:TaskText.Text = '思考中…'
  }
  $script:LastActivity = $script:TaskText.Text

  $started = [double](Get-Prop $session 'turnStartedAt')
  $elapsed = if ($started -gt 0) { $now - $started } else { 0 }
  $step = [int](Get-Prop $session 'step')
  $meta = '已用 ' + (Format-Duration $elapsed)
  if ($step -gt 0) { $meta += " · 第 $step 步" }
  $goal = Get-Prop $session 'goal'
  if ($null -ne $goal) {
    $rounds = [int](Get-Prop $goal 'rounds')
    if ($rounds -gt 0) { $meta += " · 目标 R$rounds" }
  }
  $script:MetaText.Text = $meta

  Set-Compact $script:Collapsed

  if ($null -ne $script:Tray) {
    $tray = 'DSH 大肥鱼 · 工作中'
    if ($total -gt 0) { $tray += " $done/$total" }
    $script:Tray.Text = $tray
  }
}

function Render-Done($session, $lastTurn) {
  if ($script:BalanceShowing) { return }
  Set-LoopAnimations $false
  Toggle-Bubbles $false
  Toggle-DotPulse $false
  Set-Mouth $false
  Set-Alert $false
  $endedFor = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - [double](Get-Prop $lastTurn 'endedAt')
  if (([DateTime]::Now -lt $script:PetUntil) -or $endedFor -lt 7000) { Set-Sprite 'celebrate' 150 } else { Set-Sprite 'idle' 1100 }
  Set-DotColor '#3DDC97'
  Set-BubbleVisible $true
  $script:IdleSince = $null

  $title = [string](Get-Prop $session 'title')
  $script:TitleText.Text = '任务完成啦！'
  $progress = Get-Prop $session 'progress'
  $total = 0; $done = 0
  if ($null -ne $progress) { $total = [int](Get-Prop $progress 'total'); $done = [int](Get-Prop $progress 'completed') }
  $script:BarTrack.Visibility = if ($total -gt 0) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
  if ($total -gt 0) {
    Set-Progress ([Math]::Min(1.0, $done / [Math]::Max(1, $total))) $true
    $script:CountText.Text = "$done/$total"
  } else {
    $script:CountText.Text = ''
  }
  $script:TaskText.Text = $title
  $dur = if ($null -ne $lastTurn) { [double](Get-Prop $lastTurn 'durationMs') } else { 0 }
  $script:MetaText.Text = '用时 ' + (Format-Duration $dur) + ' · 双击看余额'
  Set-Compact $script:Collapsed
  if ($null -ne $script:Tray) { $script:Tray.Text = 'DSH 大肥鱼 · 任务完成' }
}

function Render-Error($session, $lastTurn) {
  if ($script:BalanceShowing) { return }
  Set-LoopAnimations $false
  Toggle-Bubbles $false
  Toggle-DotPulse $false
  Stop-Celebrate
  Set-Mouth $true
  Set-Alert $true
  Set-Sprite 'error' 260
  Set-DotColor '#FF6B6B'
  Set-BubbleVisible $true
  $script:IdleSince = $null
  $script:TitleText.Text = '呜…出错了'
  $script:CountText.Text = ''
  $script:BarTrack.Visibility = [Windows.Visibility]::Collapsed
  $err = [string](Get-Prop $session 'errorMessage')
  if (-not $err) { $err = '任务执行失败' }
  if ($err.Length -gt 60) { $err = $err.Substring(0, 59) + '…' }
  $script:TaskText.Text = $err
  $script:MetaText.Text = '双击查看模型余额'
  Set-Compact $script:Collapsed
  if ($null -ne $script:Tray) { $script:Tray.Text = 'DSH 大肥鱼 · 出错了' }
}

function Render-Aborted($session, $lastTurn) {
  if ($script:BalanceShowing) { return }
  Set-LoopAnimations $false
  Toggle-Bubbles $false
  Toggle-DotPulse $false
  Stop-Celebrate
  Set-Mouth $false
  Set-Alert $false
  Set-Sprite 'think' 900
  Set-DotColor '#F0B35C'
  Set-BubbleVisible $true
  $script:IdleSince = $null
  $script:TitleText.Text = '任务已停止'
  $script:CountText.Text = ''
  $script:BarTrack.Visibility = [Windows.Visibility]::Collapsed
  $script:TaskText.Text = [string](Get-Prop $session 'title')
  $script:MetaText.Text = '等你回来继续～'
  Set-Compact $script:Collapsed
  if ($null -ne $script:Tray) { $script:Tray.Text = 'DSH 大肥鱼 · 已停止' }
}

# ── 读取状态 ─────────────────────────────────────────────────────────────
$script:LastGoodState = $null
$script:LastAppliedState = $null
$script:LastStateMtime = [DateTime]::MinValue
$lastReadFailure = $false

function Read-State {
  try {
    $fi = Get-Item -LiteralPath $script:StatePath -ErrorAction Stop
    if ($fi.LastWriteTimeUtc -eq $script:LastStateMtime -and $null -ne $script:LastGoodState) {
      return $script:LastGoodState
    }
    $st = Read-JsonFile $script:StatePath
    if ($null -eq $st) { return $null }
    if ($null -eq (Get-Prop $st 'v') -or $null -eq (Get-Prop $st 'phase')) { return $null }
    $script:LastStateMtime = $fi.LastWriteTimeUtc
    return $st
  } catch { }
  return $null
}


function Get-PreviewState([string]$phase) {
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $todos = @(
    @{ content = '读取 DSH 会话与任务状态'; status = 'completed' },
    @{ content = '设计大肥鱼桌面形象与动画'; status = 'completed' },
    @{ content = '接入实时进度气泡与完成提醒'; status = 'in_progress' },
    @{ content = '处理多会话与子代理状态'; status = 'pending' },
    @{ content = '打包为 DSH 插件并自启'; status = 'pending' }
  )
  $session = [pscustomobject]@{
    id = 'preview'; title = '把这段视频剪成 3 分钟小短片'; running = $true; turn = 1
    turnStartedAt = $now - 83000; step = 7; steps = 7
    activity = [pscustomobject]@{ kind = 'tool'; text = '执行 vision_tool'; detail = '分析第 4 段素材的转场节奏' }
    progress = [pscustomobject]@{ total = 5; completed = 2; inProgress = 1; pending = 2; current = '接入实时进度气泡与完成提醒' }
    todos = $todos; goal = $null; lastTurn = $null; errorMessage = $null
  }
  if ($phase -eq 'done') {
    $session.running = $false
    $session.progress = [pscustomobject]@{ total = 5; completed = 5; inProgress = 0; pending = 0; current = $null }
    $session.lastTurn = [pscustomobject]@{ turn = 1; reason = 'completed'; endedAt = $now - 4000; durationMs = 132000 }
  }
  if ($phase -eq 'error') {
    $session.running = $false
    $session.errorMessage = '网络连接超时，请检查代理设置'
    $session.lastTurn = [pscustomobject]@{ turn = 1; reason = 'error'; endedAt = $now - 3000; durationMs = 40000 }
  }
  $completion = $null
  if ($phase -eq 'done') {
    $completion = [pscustomobject]@{ id = 'preview-1'; at = $now - 4000; title = $session.title; reason = 'completed'; durationMs = 132000 }
  }
  return [pscustomobject]@{
    v = 1; now = $now; phase = $(if ($phase -eq 'done') { 'done' } elseif ($phase -eq 'error') { 'done' } elseif ($phase -eq 'idle') { 'idle' } else { 'working' })
    dshUrl = 'http://127.0.0.1:11821'; activeSessions = 1; session = $(if ($phase -eq 'idle') { $null } else { $session })
    completion = $completion; sessions = @()
  }
}

# ── 主循环 ───────────────────────────────────────────────────────────────
$script:PreviewState = $null
$script:PreviewCelebrated = $false
if ($Preview) { $script:PreviewState = Get-PreviewState $Preview }

$script:Tick = New-Object System.Windows.Threading.DispatcherTimer
$script:Tick.Interval = [TimeSpan]::FromMilliseconds(400)
$script:Tick.Add_Tick({
  try {
    if ($null -ne $script:BalanceJob) { Update-BalanceJob }
    if ($null -ne $script:UpdateJob) { Update-CheckJob }
    if ($Preview) {
      Apply-State $script:PreviewState
      if ($Preview -eq 'done' -and -not $script:PreviewCelebrated) {
        $script:PreviewCelebrated = $true
        Start-Celebrate
        Play-Chime
      }
      return
    }

    if ($null -ne $script:CoreProc -and $script:CoreProc.HasExited -and $script:CoreRestarts -lt 4) {
      Start-Core
    }

    if (-not $NoCore) {
      $age = 999.0
      try { $age = ([DateTime]::Now - (Get-Item -LiteralPath $script:StatePath).LastWriteTime).TotalSeconds } catch { }
      $sinceStart = 999.0
      try { $sinceStart = ([DateTime]::Now - $script:CoreStartedAt).TotalSeconds } catch { }
      # 稳定运行 60 秒后重置重启预算，避免预算耗尽后永久卡在“正在重新连接”。
      if ($null -ne $script:CoreProc -and -not $script:CoreProc.HasExited -and $script:CoreRestarts -gt 0 -and $age -lt $script:StaleSeconds -and $sinceStart -gt 60) {
        $script:CoreRestarts = 0
        Write-DebugLog 'core stable, restart budget reset'
      }
      if ($age -gt $script:StaleSeconds -and $sinceStart -gt $script:CoreWarmupSeconds) {
        if (([DateTime]::Now - $script:LastReconnectAt).TotalSeconds -gt $script:StaleSeconds) {
          $script:LastReconnectAt = [DateTime]::Now
          Write-DebugLog ("state stale {0:N1}s, restart core" -f $age)
          Stop-Core
          Start-Core
        }
        Set-BubbleVisible $true
        Set-Mouth $false
        Set-Alert $false
        Set-Sprite 'think' 900
        Set-DotColor '#F0B35C'
        $script:TitleText.Text = '正在重新连接…'
        $script:CountText.Text = ''
        $script:BarTrack.Visibility = [Windows.Visibility]::Collapsed
        $script:TaskText.Text = '进度后端断开了，正在自动恢复'
        $script:MetaText.Text = '一直这样可运行 stop-fish.cmd 后重新启动'
        return
      }
    }

    $st = Read-State
    if ($null -ne $st) {
      $script:LastGoodState = $st
      if (-not [object]::ReferenceEquals($st, $script:LastAppliedState)) {
        $script:LastAppliedState = $st
        Apply-State $st
      }
    } elseif ($null -eq $script:LastGoodState) {
      Set-BubbleVisible $true
      Set-Mouth $false
      Set-Alert $false
      Set-Sprite 'think' 900
      Set-DotColor '#5C6B95'
      $script:TitleText.Text = 'DSH 大肥鱼'
      $script:TaskText.Text = '正在连接 DSH…'
      $script:MetaText.Text = '首次启动会慢一点'
      $script:BarTrack.Visibility = [Windows.Visibility]::Collapsed
    }

    # 工作中每帧刷新计时
    if ($script:DisplayedRunning -and $null -ne $script:DisplayedSession -and -not $script:BalanceShowing) {
      $started = [double](Get-Prop $script:DisplayedSession 'turnStartedAt')
      if ($started -gt 0) {
        $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $elapsed = $nowMs - $started
        $meta = '已用 ' + (Format-Duration $elapsed)
        $step = [int](Get-Prop $script:DisplayedSession 'step')
        if ($step -gt 0) { $meta += " · 第 $step 步" }
        $goal = Get-Prop $script:DisplayedSession 'goal'
        if ($null -ne $goal -and [int](Get-Prop $goal 'rounds') -gt 0) { $meta += " · 目标 R$([int](Get-Prop $goal 'rounds'))" }
        $script:MetaText.Text = $meta
      }
    }
  } catch { }
})

# ── 启动 ─────────────────────────────────────────────────────────────────
try { Start-Loops } catch { }
Set-Compact $script:Collapsed
Set-BubbleVisible $true
$script:Window.Add_Loaded({
  try {
    $script:TitleText.Text = 'DSH 大肥鱼'
    $script:TaskText.Text = '正在连接 DSH…'
    Show-Bubble
    if ($script:Material -eq 'white' -or $script:Material -eq 'glass') { Apply-Material }
    Ensure-OnScreen
    Register-HitTest
    Register-Hotkey
  } catch { }
})
$script:Window.Add_LocationChanged({
  # 拖动结束保存位置；用节流避免频繁写盘
  if ($null -eq $script:Drag) { Save-WindowPos }
})
$script:Window.Add_Closed({
  Unregister-Hotkey
  try { Remove-Item -LiteralPath $script:PidPath -Force -ErrorAction SilentlyContinue } catch { }
  Stop-Core
  try { if ($null -ne $script:Tray) { $script:Tray.Visible = $false; $script:Tray.Dispose() } } catch { }
  try { $script:Mutex.ReleaseMutex() } catch { }
})
$script:Window.Add_Closing({
  try { Save-WindowPos } catch { }
  try { $script:Tick.Stop() } catch { }
  try { $script:BlinkTimer.Stop() } catch { }
  try { $script:FrameTimer.Stop() } catch { }
  try { $script:BalanceRestore.Stop() } catch { }
  try { if ($null -ne $script:BalanceJob) { Stop-Job -Job $script:BalanceJob -ErrorAction SilentlyContinue; Remove-Job -Job $script:BalanceJob -Force -ErrorAction SilentlyContinue } } catch { }
})

Write-DebugLog 'widget starting'
Init-Tray
$script:Tick.Start()

if ($Shot) {
  $shotTimer = New-Object System.Windows.Threading.DispatcherTimer
  $shotTimer.Interval = [TimeSpan]::FromMilliseconds($ShotDelay)
  $shotTimer.Add_Tick({
    try {
      $w = [int]$script:Window.ActualWidth
      $h = [int]$script:Window.ActualHeight
      $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
      $rtb.Render($script:Window)
      $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
      $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
      $fs = [System.IO.File]::Create($Shot)
      $enc.Save($fs)
      $fs.Close()
    } catch { }
    $script:Window.Close()
  })
  $shotTimer.Start()
}

[void]$script:Window.ShowDialog()
