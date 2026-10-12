$ErrorActionPreference = 'Stop'
$health = Invoke-RestMethod 'http://127.0.0.1:8080/health/ready'
if ($health.status -ne 'ready') { throw "API not ready: $($health | ConvertTo-Json -Compress)" }
Write-Host 'PASS: /health/ready'

$time = Invoke-RestMethod 'http://127.0.0.1:8080/api/v1/public/time'
if (-not $time.serverTime) { throw 'Public server time failed.' }
Write-Host 'PASS: /api/v1/public/time'

$pricing = Invoke-RestMethod 'http://127.0.0.1:8080/api/v1/licenses/pricing'
if ($null -eq $pricing.prices) { throw 'Pricing endpoint failed.' }
Write-Host 'PASS: pricing'
$swagger = Invoke-WebRequest 'http://127.0.0.1:8080/swagger/index.html' -UseBasicParsing
if ($swagger.StatusCode -ne 200) { throw 'Swagger UI failed.' }
Write-Host 'PASS: /swagger/index.html'

Write-Host 'All smoke tests passed.'
