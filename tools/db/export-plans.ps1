# Exportuje mapove plany ze Supabase do supabase/data/plans.sql.
# Connection string se nacita ze stejneho DPAPI tajemstvi jako migrace.

param(
  [string]$OutputFile = (Join-Path $PSScriptRoot "..\..\supabase\data\plans.sql")
)

$ErrorActionPreference = "Stop"

$secretFile = Join-Path $env:APPDATA "achtungdiekm\db-url.secret"
if (-not (Test-Path $secretFile)) {
  Write-Error "Pripojeni nenalezeno ($secretFile). Spust nejdriv: .\set-secret.ps1"
  exit 1
}

$sec = ConvertTo-SecureString (Get-Content $secretFile)
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$url = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

$py = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$exporter = Join-Path $PSScriptRoot "export-plans.py"

if (-not (Test-Path $py)) {
  Write-Error "Chybi Python prostredi. Postup je v tools/db/README.md."
  exit 1
}

$env:DATABASE_URL = $url
try {
  & $py $exporter $OutputFile
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Remove-Item Env:\DATABASE_URL -ErrorAction SilentlyContinue
}
