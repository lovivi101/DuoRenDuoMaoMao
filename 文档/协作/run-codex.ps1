param(
  [Parameter(Mandatory)] [string]$Task,      # 任务文件路径（.md）
  [Parameter(Mandatory)] [string]$Name,      # 任务名，用于日志
  [string]$Workdir = "E:\Game_Work\AI 游戏\多人躲猫猫",
  [int]$MaxAttempts = 30
)
$ErrorActionPreference = 'Continue'
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force $logDir | Out-Null
$models = @('gpt-6-sol','gpt-5.6-sol','gpt-6-sol','gpt-6-luna')
$body = Get-Content $Task -Raw -Encoding UTF8
$doneFile = Join-Path $logDir "$Name.last.txt"

for ($i = 0; $i -lt $MaxAttempts; $i++) {
  $model = $models[$i % $models.Count]
  $retryNote = ""
  if ($i -gt 0) {
    $retryNote = "`n`n【重试说明】这是第 $($i+1) 次执行（上次因模型容量或中断失败）。先检查磁盘上已经完成的产出，跳过已合格的部分，只补做未完成的部分。`n"
  }
  $prompt = $body + $retryNote + "`n`n【执行方式】这是非交互执行，没有人会回答问题：不要调用 request_user_input 或向用户提问，遇到不确定的地方按任务书与常识自行决策并在最终回复里说明。" + "`n`n【结束约定】全部完成并自检通过后，最后一条回复的第一行必须是 TASK_DONE，随后列出产出摘要与已知问题。"
  $log = Join-Path $logDir "$Name.attempt$($i+1).$model.log"
  "[$(Get-Date -Format s)] attempt $($i+1) model=$model" | Tee-Object -FilePath (Join-Path $logDir "$Name.status.log") -Append
  Remove-Item $doneFile -ErrorAction SilentlyContinue
  $prompt | codex exec -m $model -c model_reasoning_effort="high" --skip-git-repo-check -s danger-full-access -C $Workdir -o $doneFile - *> $log
  $last = if (Test-Path $doneFile) { Get-Content $doneFile -Raw -Encoding UTF8 } else { "" }
  if ($last -match '^\s*TASK_DONE') {
    "[$(Get-Date -Format s)] DONE attempt $($i+1)" | Tee-Object -FilePath (Join-Path $logDir "$Name.status.log") -Append
    exit 0
  }
  $tail = Get-Content $log -Tail 5 -ErrorAction SilentlyContinue | Out-String
  "[$(Get-Date -Format s)] not done: $tail" | Out-File -Append -FilePath (Join-Path $logDir "$Name.status.log") -Encoding UTF8
  Start-Sleep -Seconds ([Math]::Min(300, 20 * [Math]::Pow(2, [Math]::Min($i, 4))))
}
"[$(Get-Date -Format s)] GAVE UP" | Out-File -Append -FilePath (Join-Path $logDir "$Name.status.log") -Encoding UTF8
exit 1


