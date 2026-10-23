# DSH 大肥鱼 · 模型余额

function Get-ActiveModel {
  $provider = ''
  $model = ''
  try {
    if ($null -ne $script:CurrentState) {
      $session = $script:CurrentState.session
      if ($null -ne $session) {
        $provider = [string]$session.provider
        $model = [string]$session.llmModel
      }
    }
  } catch { }
  if (-not $provider) {
    try {
      $home = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
      $profile = Join-Path $home 'profiles\desktop\cordis.patch.yml'
      if (Test-Path -LiteralPath $profile) {
        $txt = Get-Content -LiteralPath $profile -Raw
        if ($txt -match '(?s)- id: agent-default-model.*?provider:\s*([^\s]+).*?model:\s*([^\s]+)') {
          $provider = $Matches[1]
          $model = $Matches[2]
        }
      }
    } catch { }
  }
  if (-not $provider) { $provider = 'deepseek-official' }
  if (-not $model) { $model = 'deepseek-flash' }
  return [pscustomobject]@{ Provider = $provider; Model = $model }
}

function Set-BalanceBubble([string]$title, [string]$text, [string]$meta, [string]$dot) {
  $script:BalanceShowing = $true
  $script:TitleText.Text = $title
  $script:TaskText.Text = $text
  $script:MetaText.Text = $meta
  $script:CountText.Text = ''
  $script:BarTrack.Visibility = [Windows.Visibility]::Collapsed
  Set-Compact $false
  Set-DotColor $dot
  Set-BubbleVisible $true
  try {
    $script:BalanceRestore.Stop()
    $script:BalanceRestore.Start()
  } catch { }
}

function Show-Balance {
  if ($script:BalanceBusy) { return }
  $active = Get-ActiveModel
  $provider = [string]$active.Provider
  $model = [string]$active.Model
  $script:BalanceModel = $model
  $script:BalanceKind = ''
  $endpoint = ''
  $credName = ''
  $title = ''
  switch -Regex ($provider) {
    'deepseek' {
      $endpoint = 'https://api.deepseek.com/user/balance'
      $credName = 'DEEPSEEK_API_KEY'
      $title = 'DeepSeek 余额'
      $script:BalanceKind = 'deepseek'
    }
    'openrouter' {
      $endpoint = 'https://openrouter.ai/api/v1/credits'
      $credName = 'OPENROUTER_API_KEY'
      $title = 'OpenRouter 余额'
      $script:BalanceKind = 'openrouter'
    }
    'moonshot|kimi' {
      $endpoint = 'https://api.moonshot.cn/v1/users/me/balance'
      $title = 'Moonshot 余额'
      $script:BalanceKind = 'moonshot'
      if ($provider -match 'kimi') {
        $credName = 'KIMI_API_KEY'
        if (-not (Get-DshCredential $credName)) { $credName = 'MOONSHOT_API_KEY' }
      } else {
        $credName = 'MOONSHOT_API_KEY'
      }
    }
    default {
      Set-BalanceBubble ($provider + ' 余额') '该 provider 暂无余额接口' ('当前模型：' + $model) '#FFB454'
      return
    }
  }
  $script:BalanceTitle = $title
  $key = Get-DshCredential $credName
  if (-not $key) {
    Set-BalanceBubble $title ('未找到 ' + $credName) ('当前模型：' + $model) '#FF6B6B'
    return
  }
  $script:BalanceBusy = $true
  Set-BalanceBubble $title '查询中…' ($model + ' · 正在连接') '#7C93FF'
  try {
    $script:BalanceStarted = [DateTime]::Now
    $script:BalanceJob = Start-Job -ScriptBlock {
      param($apiKey, $url)
      try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $r = Invoke-RestMethod -Uri $url -Headers @{ Authorization = ('Bearer ' + $apiKey); Accept = 'application/json' } -TimeoutSec 12
        return ($r | ConvertTo-Json -Depth 6 -Compress)
      } catch {
        return ('ERR:' + $_.Exception.Message)
      }
    } -ArgumentList $key, $endpoint
  } catch {
    $script:BalanceBusy = $false
    Set-BalanceBubble $title ('查询失败：' + $_.Exception.Message) '双击重试' '#FF6B6B'
  }
}

function Update-BalanceJob {
  if ($null -eq $script:BalanceJob) {
    return
  }
  $title = $script:BalanceTitle
  $model = $script:BalanceModel
  $state = [string]$script:BalanceJob.State
  if ($state -eq 'Running' -or $state -eq 'NotStarted') {
    if (([DateTime]::Now - $script:BalanceStarted).TotalSeconds -gt 20) {
      try { Stop-Job -Job $script:BalanceJob -ErrorAction SilentlyContinue } catch { }
      try { Remove-Job -Job $script:BalanceJob -Force -ErrorAction SilentlyContinue } catch { }
      $script:BalanceJob = $null
      $script:BalanceBusy = $false
      Set-BalanceBubble $title '查询超时' '双击重试' '#FF6B6B'
    }
    return
  }
  $out = ''
  try {
    $out = (@(Receive-Job -Job $script:BalanceJob -ErrorAction Stop) | Where-Object { $_ -is [string] } | Select-Object -Last 1)
  } catch {
    $out = 'ERR:' + $_.Exception.Message
  }
  try { Remove-Job -Job $script:BalanceJob -Force -ErrorAction SilentlyContinue } catch { }
  $script:BalanceJob = $null
  $script:BalanceBusy = $false
  if (-not $out) { $out = 'ERR:空响应' }
  if ($out -like 'ERR:*') {
    $msg = $out.Substring(4).Trim()
    if ($msg.Length -gt 60) { $msg = $msg.Substring(0, 60) + '…' }
    Set-BalanceBubble $title ('查询失败：' + $msg) '双击重试' '#FF6B6B'
    return
  }
  try {
    $data = $out | ConvertFrom-Json
    $text = ''
    $meta = ''
    $ok = $true
    switch ($script:BalanceKind) {
      'deepseek' {
        if ($null -eq $data.is_available -or $null -eq $data.balance_infos) { throw 'DeepSeek 响应缺少 balance_infos/is_available' }
        $infos = @($data.balance_infos)
        if ($infos.Count -eq 0) { throw 'DeepSeek 响应 balance_infos 为空' }
        $parts = @()
        foreach ($b in $infos) {
          $cur = [string]$b.currency
          $sym = if ($cur -eq 'CNY') { '¥' } elseif ($cur -eq 'USD') { '$' } else { $cur + ' ' }
          $parts += ($sym + [string]$b.total_balance)
        }
        $text = if ($parts.Count -gt 0) { $parts -join '  ·  ' } else { '暂无余额信息' }
        $ok = ($data.is_available -eq $true)
        $meta = $model + ' · ' + $(if ($ok) { '可用' } else { '不可用' }) + ' · 双击刷新'
      }
      'openrouter' {
        if ($null -eq $data.data -or $null -eq $data.data.total_credits -or $null -eq $data.data.total_usage) { throw 'OpenRouter 响应缺少 total_credits/total_usage' }
        $credits = [double]$data.data.total_credits
        $usage = [double]$data.data.total_usage
        $left = $credits - $usage
        $text = '$' + $left.ToString('0.00')
        $ok = ($left -gt 0)
        $meta = $model + ' · 剩余 · 双击刷新'
      }
      'moonshot' {
        if ($null -eq $data.data -or $null -eq $data.data.available_balance) { throw 'Moonshot 响应缺少 available_balance' }
        $text = '¥' + [string]$data.data.available_balance
        $meta = $model + ' · 可用 · 双击刷新'
      }
      default {
        $text = '暂无余额信息'
        $ok = $false
        $meta = $model
      }
    }
    $dot = if ($ok) { '#3DDC97' } else { '#FF6B6B' }
    Set-BalanceBubble $title $text $meta $dot
  } catch {
    Set-BalanceBubble $title '解析余额失败' '双击重试' '#FF6B6B'
  }
}
