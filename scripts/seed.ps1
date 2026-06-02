# Seed PostgreSQL (postgres должен быть доступен, например: docker compose up -d postgres)
param(
    [int]$Sessions = 100,
    [int]$EventsPerSession = 10,
    [int]$Players = 50
)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path (Split-Path $PSScriptRoot -Parent) "backend")
if (-not $env:DB_HOST) { $env:DB_HOST = "localhost" }
if (-not $env:DB_PASSWORD) { $env:DB_PASSWORD = "postgres" }
py -3 scripts/seed_data.py --sessions $Sessions --events-per-session $EventsPerSession --players $Players
