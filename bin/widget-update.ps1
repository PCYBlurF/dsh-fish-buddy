# DSH 大肥鱼 · 检查更新

function Compare-SemVer([string]$a, [string]$b) {
  $norm = {
    param($v)
    $x = $v.Trim()
    if ($x.StartsWith('v') -or $x.StartsWith('V')) { $x = $x.Substring(1) }
    return $x.Split('+')[0]
  }
  $pa = (& $norm $a).Split('-')
  $pb = (& $norm $b).Split('-')
  $na = @($pa[0].Split('.') | ForEach-Object { $n = 0; [void][int]::TryParse(($_ -replace '[^0-9].*$', ''), [ref]$n); $n })
  $nb = @($pb[0].Split('.') | ForEach-Object { $n = 0; [void][int]::TryParse(($_ -replace '[^0-9].*$', ''), [ref]$n); $n })
  for ($i = 0; $i -lt 3; $i++) {
    $x = if ($i -lt $na.Count) { $na[$i] } else { 0 }
    $y = if ($i -lt $nb.Count) { $nb[$i] } else { 0 }
    if ($x -gt $y) { return 1 }
    if ($x -lt $y) { return -1 }
  }
  $pra = if ($pa.Count -gt 1) { $pa[1] } else { '' }
  $prb = if ($pb.Count -gt 1) { $pb[1] } else { '' }
  if (-not $pra -and -not $prb) { return 0 }
  if (-not $pra) { return 1 }
  if (-not $prb) { return -1 }
  return [string]::CompareOrdinal($pra, $prb)
}

function Check-Update {
  if ($null -ne $script:UpdateJob) {
    try {
      if ($script:UpdateJob.State -eq 'Running' -or $script:UpdateJob.State -eq 'NotStarted') { return }
    } catch { }
  }
  try {
    $script:UpdateStarted = [DateTime]::Now
    $script:UpdateJob = Start-Job -ScriptBlock {
      try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/PCYBlurF/dsh-fish-buddy/releases/latest' -Headers @{ 'User-Agent' = 'dsh-fish-buddy' } -TimeoutSec 8
        return @{ ok = $true; rel = $rel }
      } catch {
        return @{ ok = $false; error = $_.Exception.Message }
      }
    }
  } catch {
    [void][System.Windows.MessageBox]::Show(('检查更新失败：`n' + $_.Exception.Message), 'DSH 大肥鱼 · 检查更新', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    return
  }
}

function Update-CheckJob {
  $title = 'DSH 大肥鱼 · 检查更新'
  if ($null -eq $script:UpdateJob) { return }
  $state = [string]$script:UpdateJob.State
  if ($state -eq 'Running' -or $state -eq 'NotStarted') {
    if (([DateTime]::Now - $script:UpdateStarted).TotalSeconds -gt 10) {
      try { Stop-Job -Job $script:UpdateJob -ErrorAction SilentlyContinue } catch { }
      try { Remove-Job -Job $script:UpdateJob -Force -ErrorAction SilentlyContinue } catch { }
      $script:UpdateJob = $null
        [void][System.Windows.MessageBox]::Show('检查更新超时，请检查网络后重试。', $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
    return
  }
  $out = $null
  try { $out = (@(Receive-Job -Job $script:UpdateJob -ErrorAction Stop) | Select-Object -Last 1) } catch { }
  try { Remove-Job -Job $script:UpdateJob -Force -ErrorAction SilentlyContinue } catch { }
  $script:UpdateJob = $null
  if ($null -eq $out -or -not $out.ok) {
    $msg = if ($null -ne $out) { [string]$out.error } else { '空响应' }
    [void][System.Windows.MessageBox]::Show(("检查更新失败：`n" + $msg), $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    return
  }
  $rel = $out.rel
  try {
    if ($rel.draft -or $rel.prerelease) {
      [void][System.Windows.MessageBox]::Show('最新 release 是预发布版本，已跳过。', $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
      return
    }
    $latest = [string]$rel.tag_name
    if (-not $latest) {
      [void][System.Windows.MessageBox]::Show('还没有发布版本。', $title)
      return
    }
    $currentVersion = Get-WidgetVersion
    $cur = 'v' + $currentVersion
    $isNew = $false
    try { $isNew = (Compare-SemVer $latest $currentVersion) -gt 0 } catch {
      [void][System.Windows.MessageBox]::Show(("无法解析版本号：$latest"), $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
      return
    }
    if ($isNew) {
      $r = [System.Windows.MessageBox]::Show(("发现新版本 $latest。`n`n当前版本 $cur`n`n是否打开下载页？"), $title, [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
      if ($r -eq [System.Windows.MessageBoxResult]::Yes) {
        $downloadUrl = [string]$rel.html_url
        if (Test-AllowedReleaseUrl $downloadUrl) {
          try { Start-Process $downloadUrl | Out-Null } catch { }
        } else {
          [void][System.Windows.MessageBox]::Show(("下载页地址未通过校验，已拒绝打开：`n$downloadUrl"), $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }
      }
    } else {
      [void][System.Windows.MessageBox]::Show(("当前已是最新版本 $cur。"), $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
  } catch {
    [void][System.Windows.MessageBox]::Show(("检查更新失败：`n" + $_.Exception.Message), $title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
  }
}
