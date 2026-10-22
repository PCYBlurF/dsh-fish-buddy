# Stop this installation's fish widget and progress core.
# Never kill other installations' fish-core processes.
$app = Split-Path -Parent $PSScriptRoot
$self = $PID
$ids = @()
foreach ($name in @('widget.pid', 'core.pid')) {
  $file = Join-Path $app $name
  try {
    $raw = [System.IO.File]::ReadAllText($file)
    $procId = [int]($raw.Trim())
    if ($procId -gt 0 -and $procId -ne $self) { $ids += $procId }
  } catch { }
}
$ids = @($ids | Sort-Object -Unique)

foreach ($procId in $ids) {
  try { Stop-Process -Id $procId -Force -ErrorAction Stop } catch { }
}

# Fallback: only this installation's widget/core processes.
# Match the widget by its -File argument, not any -Command that merely mentions the path.
$widgets = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
  $_.ProcessId -ne $self -and $_.CommandLine -and
  $_.CommandLine -match '-File\s+"?[^"]*fish-widget\.ps1' -and
  $_.CommandLine -like ("*" + $app + "*")
}
foreach ($p in $widgets) {
  try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch { }
}
$cores = Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object {
  $_.CommandLine -and
  $_.CommandLine -like ("*" + $app + "*") -and
  $_.CommandLine -like '*fish-core.mjs*'
}
foreach ($p in $cores) {
  try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch { }
}

Remove-Item (Join-Path $app 'widget.pid') -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $app 'core.pid') -Force -ErrorAction SilentlyContinue
Write-Output "DSH fish stopped"
exit 0
