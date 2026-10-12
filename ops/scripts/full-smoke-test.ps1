$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:8080'
$envFile = Join-Path $PSScriptRoot '..\.env.test'
$adminKey = (Get-Content $envFile | Where-Object { $_ -match '^ADMIN_KEY=' } | Select-Object -First 1).Substring(10)

function Assert-Ok($name, $value) {
  if ($null -eq $value) { throw "FAIL: $name" }
  Write-Host "PASS: $name"
}

Assert-Ok '/health' (Invoke-RestMethod "$base/health")
$ready = Invoke-RestMethod "$base/health/ready"
if ($ready.status -ne 'ready') { throw 'FAIL: readiness' }
Write-Host 'PASS: /health/ready'

$time = Invoke-RestMethod "$base/api/v1/public/time"
if (-not $time.serverTime) { throw 'FAIL: public time' }
Write-Host 'PASS: public time'

$pricing = Invoke-RestMethod "$base/api/v1/licenses/pricing"
if ($null -eq $pricing.prices) { throw 'FAIL: pricing' }
Write-Host 'PASS: pricing'

$setup = @{
  storeName = 'StoreMaster Test'
  storeType = 'RETAIL'
  businessTitle = 'StoreMaster Test Store'
  adminName = 'Owner Test'
  adminPin = '2468'
  phone = ''
  deviceId = 'SM-TEST-WINDOWS-01'
  currency = 'IRR'
  platform = 'WINDOWS'
  deviceName = 'TEST-PC'
} | ConvertTo-Json

try {
  $boot = Invoke-RestMethod "$base/api/v1/stores/bootstrap" -Method Post -ContentType 'application/json' -Body $setup
} catch {
  if ($_.Exception.Response.StatusCode.value__ -eq 409) {
    Write-Host 'INFO: bootstrap already used; continuing with existing test DB.'
    $boot = $null
  } else { throw }
}

if ($boot -ne $null) {
  if (-not $boot.storeCode -or -not $boot.userId) { throw 'FAIL: bootstrap response' }
  Write-Host 'PASS: bootstrap'
  $storeCode = $boot.storeCode
  $userId = [int]$boot.userId
} else {
  throw 'Bootstrap was already used. For a deterministic full smoke test run scripts/reset-test.ps1 and rerun this test.'
}

$loginBody = @{ storeCode=$storeCode; userId=$userId; pin='2468'; deviceId='SM-TEST-WINDOWS-01'; platform='WINDOWS'; deviceName='TEST-PC' } | ConvertTo-Json
$login = Invoke-RestMethod "$base/api/v1/auth/login" -Method Post -ContentType 'application/json' -Body $loginBody
if (-not $login.accessToken) { throw 'FAIL: login token' }
Write-Host 'PASS: online login'

$h = @{ Authorization = "Bearer $($login.accessToken)" }
$me = Invoke-RestMethod "$base/api/v1/auth/me" -Headers $h
if ([int]$me.userId -ne $userId) { throw 'FAIL: /auth/me' }
Write-Host 'PASS: /auth/me'

$record = @{
  items = @(@{ entity='smoke_test'; entityId='1'; operation='UPSERT'; payloadJson='{"ok":true}'; sourceVersion=1 })
} | ConvertTo-Json -Depth 5
$push = Invoke-RestMethod "$base/api/v1/cloud-sync/push" -Headers $h -Method Post -ContentType 'application/json' -Body $record
if (-not $push.success) { throw 'FAIL: cloud push' }
Write-Host 'PASS: cloud push'

$snap = Invoke-RestMethod "$base/api/v1/cloud-sync/snapshot" -Headers $h
if (-not ($snap.items | Where-Object { $_.entity -eq 'smoke_test' })) { throw 'FAIL: cloud snapshot' }
Write-Host 'PASS: cloud snapshot'

$users = Invoke-RestMethod "$base/api/v1/users" -Headers $h
if ($null -eq $users.items) { throw 'FAIL: users endpoint' }
Write-Host 'PASS: permissions/users endpoint'

$adminHeaders = @{ 'X-Admin-Key' = $adminKey }
$stores = Invoke-RestMethod "$base/api/v1/admin/stores" -Headers $adminHeaders
if ($null -eq $stores.items) { throw 'FAIL: admin endpoint' }
Write-Host 'PASS: admin authentication'

Write-Host ''
Write-Host 'ALL FULL SMOKE TESTS PASSED.'
