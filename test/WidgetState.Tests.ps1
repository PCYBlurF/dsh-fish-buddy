function Get-Prop($obj, [string]$name) {
  if ($null -eq $obj) { return $null }
  $p = $obj.PSObject.Properties[$name]
  if ($null -eq $p) { return $null }
  return $p.Value
}

. (Join-Path $PSScriptRoot '..\bin\widget-state.ps1')

Describe 'Get-WidgetPhase' {
  It 'working' {
    Get-WidgetPhase ([pscustomobject]@{ running = $true }) 1000000 | Should -Be 'working'
  }
  It 'done within 90s' {
    $s = [pscustomobject]@{ running = $false; lastTurn = [pscustomobject]@{ reason = 'completed'; endedAt = 950000 } }
    Get-WidgetPhase $s 1000000 | Should -Be 'done'
  }
  It 'error within 60s' {
    $s = [pscustomobject]@{ running = $false; lastTurn = [pscustomobject]@{ reason = 'error'; endedAt = 950000 } }
    Get-WidgetPhase $s 1000000 | Should -Be 'error'
  }
  It 'interrupted within 30s' {
    $s = [pscustomobject]@{ running = $false; lastTurn = [pscustomobject]@{ reason = 'interrupted'; endedAt = 980000 } }
    Get-WidgetPhase $s 1000000 | Should -Be 'aborted'
  }
  It 'idle after windows' {
    $s = [pscustomobject]@{ running = $false; lastTurn = [pscustomobject]@{ reason = 'completed'; endedAt = 0 } }
    Get-WidgetPhase $s 1000000 | Should -Be 'idle'
  }
}
