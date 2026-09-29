param([string]$Source, [string]$Destination)
$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
$root = (Resolve-Path (Join-Path $project '../..')).Path
if (!$Source) { $Source = Join-Path $root '素材/UI拆分资产/00-共享资产' }
if (!$Destination) { $Destination = Join-Path $project 'assets/ui' }
$map = @{
  "01-背景"="bg"; "02-Logo"="logo"; "03-面板"="panel"; "04-按钮"="button"; "05-图标"="icon"; "06-头像"="avatar"; "07-身份徽记"="role"; "08-装饰"="decor"; "09-道具图标"="item"; "10-事件图标"="event"; "11-HUD控件"="hud"; "12-局内精灵"="sprite"; "13-地图卡"="mapcard"
}
if (!(Test-Path -LiteralPath $Source)) { Write-Host "asset source not present; nothing to sync"; exit 0 }
foreach ($dir in Get-ChildItem -LiteralPath $Source -Directory) {
  $name = if ($map.ContainsKey($dir.Name)) { $map[$dir.Name] } else { $dir.Name -replace '^[0-9]+[-_]', '' }
  $target = Join-Path $Destination $name
  # Mirror: drop stale files (e.g. quarantined placeholders) before copying the current masters.
  if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
  New-Item -ItemType Directory -Force $target | Out-Null
  Get-ChildItem -LiteralPath $dir.FullName -Force | Copy-Item -Destination $target -Recurse -Force
}
Write-Host "Synced shared UI assets to $Destination"

