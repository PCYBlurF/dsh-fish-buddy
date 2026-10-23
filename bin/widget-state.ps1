# DSH 大肥鱼 · 状态机（纯函数，便于测试）
function Get-WidgetPhase($session, [double]$now) {
  if ($null -eq $session) { return 'idle' }
  if ([bool](Get-Prop $session 'running')) { return 'working' }
  $lastTurn = Get-Prop $session 'lastTurn'
  $reason = if ($null -ne $lastTurn) { [string](Get-Prop $lastTurn 'reason') } else { '' }
  $endedAt = if ($null -ne $lastTurn) { [double](Get-Prop $lastTurn 'endedAt') } else { 0 }
  $sinceEnd = if ($endedAt -gt 0) { $now - $endedAt } else { [double]::MaxValue }
  if ($reason -eq 'completed' -and $sinceEnd -lt 90000) { return 'done' }
  if ($reason -eq 'error' -and $sinceEnd -lt 60000) { return 'error' }
  if (($reason -eq 'aborted' -or $reason -eq 'interrupted') -and $sinceEnd -lt 30000) { return 'aborted' }
  return 'idle'
}
