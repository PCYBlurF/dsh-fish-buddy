#requires -Version 5.1
<#
  Remove the DSH fish widget from the Desktop profile and stop it.
  This does not delete the repository directory (it may be a git clone).
#>
param(
  [switch]$KeepAutoStart
)

$ErrorActionPreference = 'Stop'

$repo = $PSScriptRoot
$dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
$patch = Join-Path $dshHome 'profiles\desktop\cordis.patch.yml'

$begin = '# >>> dsh-fish-buddy >>>'
$end = '# <<< dsh-fish-buddy <<<'
$changed = $false

if (Test-Path -LiteralPath $patch) {
  $text = [System.IO.File]::ReadAllText($patch)

  $bi = $text.IndexOf($begin)
  if ($bi -ge 0) {
    $ei = $text.IndexOf($end, $bi)
    if ($ei -lt 0) {
      Write-Host "配置文件中的 dsh-fish-buddy 块不完整（只有开始标记，缺少结束标记）：" -ForegroundColor Red
      Write-Host "  $patch" -ForegroundColor Red
      Write-Host "为避免截断配置，卸载已中止；请手动修复该块后重试。" -ForegroundColor Red
      exit 1
    }
    $ei += $end.Length
    $text = $text.Substring(0, $bi).TrimEnd() + "`n" + $text.Substring($ei).TrimStart()
    $changed = $true
  }

  # legacy marker block from earlier manual installs (at EOF)
  $legacy = '# ' + [char]0x2500 + [char]0x2500 + ' DSH ' + [char]0x5C0F + [char]0x9C7C
  $li = $text.IndexOf($legacy)
  if ($li -ge 0) {
    $text = $text.Substring(0, $li).TrimEnd() + "`n"
    $changed = $true
  }

  if ($changed) {
    $backup = "$patch.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 6))
    Copy-Item -LiteralPath $patch -Destination $backup -Force
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $tmp = "$patch.tmp-" + [guid]::NewGuid().ToString('N')
    [System.IO.File]::WriteAllText($tmp, $text.TrimEnd() + "`n", $utf8)
    try {
      [System.IO.File]::Replace($tmp, $patch, $null)
    } catch {
      Move-Item -LiteralPath $tmp -Destination $patch -Force
    }
    Write-Host "已移除插件配置（备份：$backup）" -ForegroundColor Green
  } else {
    Write-Host "未找到 dsh-fish-buddy 配置块，profile 未修改。"
  }
} else {
  Write-Host "找不到 desktop profile 配置：$patch"
}

$stop = Join-Path $repo 'bin\stop-fish.ps1'
if (Test-Path -LiteralPath $stop) { & $stop | Out-Null }

if (-not $KeepAutoStart) {
  try {
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'DshFishBuddy' -Force -ErrorAction SilentlyContinue
  } catch { }
}

Write-Host "已停止挂件。重启 DSH 后插件彻底移除。" -ForegroundColor Green
Write-Host "目录仍然保留：$repo（如不需要可直接删除）"
