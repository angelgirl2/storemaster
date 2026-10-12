param(
  [string]$Root = "$HOME\Desktop\store"
)
$ErrorActionPreference = 'Stop'

Write-Host "StoreMaster unified sync" -ForegroundColor Cyan
Write-Host "Target: $Root"

$user = Join-Path $Root 'store_master_offline'
$admin = Join-Path $Root 'store_master_admin'
$shared = Join-Path $Root 'shared'

foreach ($p in @($user,$admin,$shared)) {
  if (-not (Test-Path $p)) { throw "مسیر پیدا نشد: $p" }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $Root "_backup_before_shared_sync_$stamp"
New-Item -ItemType Directory -Path $backup | Out-Null

# Backup old duplicated shared folders if they exist
foreach ($project in @($user,$admin)) {
  $oldShared = Join-Path $project 'shared'
  if (Test-Path $oldShared) {
    Copy-Item $oldShared (Join-Path $backup ((Split-Path $project -Leaf) + '_shared')) -Recurse -Force
    Remove-Item $oldShared -Recurse -Force
  }
}

Write-Host "کپی پروژه و shared جدید..." -ForegroundColor Yellow
Copy-Item (Join-Path $PSScriptRoot 'shared\*') $shared -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot 'store_master_offline\lib\*') (Join-Path $user 'lib') -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot 'store_master_admin\lib\*') (Join-Path $admin 'lib') -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot 'store_master_offline\pubspec.yaml') (Join-Path $user 'pubspec.yaml') -Force
Copy-Item (Join-Path $PSScriptRoot 'store_master_admin\pubspec.yaml') (Join-Path $admin 'pubspec.yaml') -Force

Write-Host "انجام شد. پشتیبان در: $backup" -ForegroundColor Green
Write-Host "حالا در هر پروژه flutter pub get و flutter analyze را اجرا کنید."
