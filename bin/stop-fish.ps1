# Stop the DSH fish widget and its progress core.
$app = Join-Path $env:USERPROFILE '.dsh\fish-buddy'
$self = $PID

$widgets = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
  $_.ProcessId -ne $self -and $_.CommandLine -and $_.CommandLine -match '-File\s+"?.*fish-widget\.ps1'
}
foreach ($p in $widgets) {
  try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch { }
}

$cores = Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object {
  $_.CommandLine -and $_.CommandLine -match 'fish-core\.mjs'
}
foreach ($p in $cores) {
  try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch { }
}

Remove-Item (Join-Path $app 'widget.pid') -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $app 'core.pid') -Force -ErrorAction SilentlyContinue
Write-Output "DSH fish stopped"
