$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
docker compose -f docker-compose.test.yml down -v
docker compose -f docker-compose.test.yml up -d --build
