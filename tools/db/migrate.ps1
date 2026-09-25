# migrate.ps1 — spustí SQL soubor(y) proti databázi. Heslo načte zašifrovaně z DPAPI.
# Použití:  .\migrate.ps1 ..\..\supabase\schema.sql ..\..\supabase\import_graph.sql

param(
  [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
  [string[]]$SqlFiles
)

$ErrorActionPreference = "Stop"

$secretFile = Join-Path $env:APPDATA "achtungdiekm\db-url.secret"
if (-not (Test-Path $secretFile)) {
  Write-Error "Tajemstvi nenalezeno ($secretFile). Spust nejdriv: .\set-secret.ps1"
  exit 1
}

# Dešifrování DPAPI -> plaintext URL jen do paměti.
$sec  = ConvertTo-SecureString (Get-Content $secretFile)
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$url  = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

$py = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$migrate = Join-Path $PSScriptRoot "migrate.py"

$env:DATABASE_URL = $url
try {
  & $py $migrate @SqlFiles
} finally {
  Remove-Item Env:\DATABASE_URL -ErrorAction SilentlyContinue
}
