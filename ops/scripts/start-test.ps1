$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
Copy-Item .env.test .env -Force

docker compose -f docker-compose.test.yml up -d --build

Write-Host 'Waiting for API...'
for ($i=0; $i -lt 60; $i++) {
  try {
    $r = Invoke-WebRequest 'http://127.0.0.1:8080/health/ready' -UseBasicParsing -TimeoutSec 3
    if ($r.StatusCode -eq 200) { Write-Host 'API READY'; exit 0 }
  } catch {}
  Start-Sleep -Seconds 2
}

docker compose -f docker-compose.test.yml ps
docker compose -f docker-compose.test.yml logs --tail=120 api db
throw 'API did not become ready.'
