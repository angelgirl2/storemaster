Set-Location (Join-Path $PSScriptRoot '..')
docker compose -f docker-compose.test.yml down
