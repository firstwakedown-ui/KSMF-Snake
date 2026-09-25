# set-secret.ps1 — jednorázově uloží connection string k databázi ZAŠIFROVANĚ (Windows DPAPI).
# Tajemství se uloží mimo repozitář, do %APPDATA%\achtungdiekm\db-url.secret,
# a dešifrovat ho může jen tvůj Windows účet na tomto počítači.

$ErrorActionPreference = "Stop"

$dir = Join-Path $env:APPDATA "achtungdiekm"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$secretFile = Join-Path $dir "db-url.secret"

Write-Host ""
Write-Host "Vlož connection string (URI) ze Supabase:" -ForegroundColor Cyan
Write-Host "  Dashboard -> Project Settings -> Database -> Connection string -> URI"
Write-Host "  Doporuceno: zalozka 'Session pooler' (IPv4, port 5432)."
Write-Host "  V URI nahrad [YOUR-PASSWORD] svym skutecnym heslem k DB."
Write-Host ""
Write-Host "Vstup se NEzobrazi a ulozi se zasifrovane (DPAPI)." -ForegroundColor Yellow

$sec = Read-Host -AsSecureString "DATABASE_URL"
$enc = ConvertFrom-SecureString $sec   # DPAPI (user-scope), bez klice
Set-Content -Path $secretFile -Value $enc -Encoding ASCII

Write-Host ""
Write-Host "Ulozeno (sifrovane) do: $secretFile" -ForegroundColor Green
Write-Host "Hotovo. Pouzij: .\migrate.ps1 <soubor.sql>"
