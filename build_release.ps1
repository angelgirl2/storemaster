[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ApiUrl,
  [ValidateSet('Online','Offline')][string]$Mode = 'Online',
  [string]$AdminKey = '',
  [switch]$Android,
  [switch]$Windows,
  [switch]$SkipAnalyze
)

$ErrorActionPreference = 'Stop'
if (-not $Android -and -not $Windows) { $Android = $true; $Windows = $true }

if ($Mode -eq 'Online') {
  $uri = $null
  if (-not [Uri]::TryCreate($ApiUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
    throw 'برای Build آنلاین، ApiUrl باید آدرس HTTPS واقعی Railway باشد؛ مثال: https://your-api.up.railway.app'
  }
  if ([string]::IsNullOrWhiteSpace($AdminKey) -or $AdminKey.Length -lt 32) {
    throw 'برای ساخت License Manager آنلاین، AdminKey حداقل ۳۲ کاراکتر لازم است. آن را فقط روی رایانه مورد اعتماد ادمین نگه دارید.'
  }
}

function Invoke-Flutter([string]$Project, [string[]]$Args) {
  Write-Host "`n==> $Project : flutter $($Args -join ' ')" -ForegroundColor Cyan
  Push-Location (Join-Path $PSScriptRoot $Project)
  try {
    & flutter @Args
    if ($LASTEXITCODE -ne 0) { throw "Flutter failed in $Project (exit code $LASTEXITCODE): $($Args -join ' ')" }
  } finally { Pop-Location }
}

$apiDefine = "--dart-define=STORE_MASTER_API_URL=$ApiUrl"
$onlineDefine = if ($Mode -eq 'Online') { '--dart-define=STORE_MASTER_ONLINE_ENABLED=true' } else { '--dart-define=STORE_MASTER_ONLINE_ENABLED=false' }
$requiredDefine = '--dart-define=STORE_MASTER_ONLINE_REQUIRED=false'
$adminOnlineDefine = if ($Mode -eq 'Online') { '--dart-define=STORE_MASTER_ADMIN_ONLINE_ENABLED=true' } else { '--dart-define=STORE_MASTER_ADMIN_ONLINE_ENABLED=false' }
$adminKeyDefine = if ($Mode -eq 'Online') { "--dart-define=STORE_MASTER_ADMIN_KEY=$AdminKey" } else { '--dart-define=STORE_MASTER_ADMIN_KEY=CHANGE_THIS_ADMIN_KEY' }

foreach ($project in @('store_master_offline','store_master_admin')) {
  Invoke-Flutter $project @('pub','get')
  if (-not $SkipAnalyze) { Invoke-Flutter $project @('analyze') }
}

if ($Android) {
  foreach ($project in @('store_master_offline','store_master_admin')) {
    $ks = if ($project -eq 'store_master_offline') { 'storemasterClient.jks' } else { 'storemasterAdmin.jks' }
    $ksPath = Join-Path $PSScriptRoot "$project/android/keystore/$ks"
    $propsPath = Join-Path $PSScriptRoot "$project/android/key.properties"
    if (-not (Test-Path $ksPath) -or -not (Test-Path $propsPath)) {
      throw "Release signing files are missing for $project. Restore your original private keystore and android/key.properties locally; never commit them to GitHub."
    }
  }
  Invoke-Flutter 'store_master_offline' @('build','apk','--release',$apiDefine,$onlineDefine,$requiredDefine)
  Invoke-Flutter 'store_master_admin' @('build','apk','--release',$apiDefine,$adminOnlineDefine,$adminKeyDefine)
}
if ($Windows) {
  Invoke-Flutter 'store_master_offline' @('build','windows','--release',$apiDefine,$onlineDefine,$requiredDefine)
  Invoke-Flutter 'store_master_admin' @('build','windows','--release',$apiDefine,$adminOnlineDefine,$adminKeyDefine)
}
Write-Host "`nBuild tasks completed. Confirm generated files under each project's build/ directory." -ForegroundColor Green
if ($Mode -eq 'Online') {
  Write-Warning 'The Admin__Key is compiled into the License Manager. Only install that build on trusted admin devices; use a dedicated admin-only server key and rotate it if the app is exposed.'
}
