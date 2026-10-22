#requires -Version 5.1
<#
  Install the DSH fish widget into the Desktop profile.

  - writes a managed plugin block into
    %DSH_HOME%\profiles\desktop\cordis.patch.yml (backup first)
  - starts the widget
  - restart DSH once afterwards: the plugin will auto-start it on boot

  The repository can live anywhere; the absolute path is written into the patch.
#>
param(
  [switch]$NoStart
)

$ErrorActionPreference = 'Stop'

$repo = $PSScriptRoot
$dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
$profileDir = Join-Path $dshHome 'profiles\desktop'
$patch = Join-Path $profileDir 'cordis.patch.yml'

if (-not (Test-Path -LiteralPath $patch)) {
  Write-Host "找不到 desktop profile 配置：" -ForegroundColor Red
  Write-Host "  $patch" -ForegroundColor Red
  Write-Host "请先安装并启动一次 DSH Desktop（或设置 DSH_HOME 环境变量）。"
  exit 1
}

Write-Host "DSH 大肥鱼安装器"
Write-Host "  仓库目录：$repo"
Write-Host "  配置文件：$patch"

$begin = '# >>> dsh-fish-buddy >>>'
$end = '# <<< dsh-fish-buddy <<<'
$text = [System.IO.File]::ReadAllText($patch)

# strip a previous managed block
$bi = $text.IndexOf($begin)
if ($bi -ge 0) {
  $ei = $text.IndexOf($end, $bi)
  if ($ei -lt 0) {
    Write-Host "配置文件中的 dsh-fish-buddy 块不完整（只有开始标记，缺少结束标记）：" -ForegroundColor Red
    Write-Host "  $patch" -ForegroundColor Red
    Write-Host "为避免截断配置，安装已中止；请手动修复该块后重试。" -ForegroundColor Red
    exit 1
  }
  $ei += $end.Length
  $text = $text.Substring(0, $bi).TrimEnd() + "`n" + $text.Substring($ei).TrimStart()
}

# strip the legacy marker block from earlier manual installs (at EOF)
$legacy = '# ' + [char]0x2500 + [char]0x2500 + ' DSH ' + [char]0x5C0F + [char]0x9C7C
$li = $text.IndexOf($legacy)
if ($li -ge 0) { $text = $text.Substring(0, $li).TrimEnd() + "`n" }

# stop any running instance only after the profile passed validation,
# so a broken managed block never costs the user a running widget
$stop = Join-Path $repo 'bin\stop-fish.ps1'
if (Test-Path -LiteralPath $stop) { & $stop | Out-Null }

$backup = "$patch.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 6))
Copy-Item -LiteralPath $patch -Destination $backup -Force

$pluginUri = ([uri](Join-Path $repo 'plugin\index.mjs')).AbsoluteUri
$widgetDir = $repo -replace '\\', '/'
$pluginYaml = $pluginUri -replace "'", "''"
$widgetYaml = $widgetDir -replace "'", "''"
$block = @"
$begin
- insert:
    - id: dsh-fish-buddy
      name: '$pluginYaml'
      config:
        widgetDir: '$widgetYaml'
$end
"@

$newText = $text.TrimEnd() + "`n`n" + $block + "`n"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$tmp = "$patch.tmp-" + [guid]::NewGuid().ToString('N')
[System.IO.File]::WriteAllText($tmp, $newText, $utf8)
try {
  [System.IO.File]::Replace($tmp, $patch, $null)
} catch {
  Move-Item -LiteralPath $tmp -Destination $patch -Force
}
Write-Host "  已写入插件配置（备份：$backup）" -ForegroundColor Green

if (-not $NoStart) {
  $vbs = Join-Path $repo 'bin\fish-widget.vbs'
  if (Test-Path -LiteralPath $vbs) {
    Start-Process -FilePath 'wscript.exe' -ArgumentList "`"$vbs`"" -WindowStyle Hidden
  }
}

Write-Host ""
Write-Host "安装完成。请重启一次 DSH，插件会在启动时自动拉起大肥鱼。" -ForegroundColor Green
Write-Host "手动启动：start-fish.cmd    停止：stop-fish.cmd    卸载：uninstall.cmd"
