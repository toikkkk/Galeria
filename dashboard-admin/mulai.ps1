<#
Menyiapkan dan menjalankan Dashboard Admin GALERIA dengan satu perintah (idempotent, aman dijalankan berulang).

  powershell -ExecutionPolicy Bypass -File dashboard-admin\mulai.ps1
  ... -Password "pilihanmu"   # password admin bila akun belum dibuat (default: acak, dicetak)
  ... -HanyaSiapkan           # siapkan saja, jangan jalankan server

Prasyarat: Python 3.10+, Node.js, dan DATABASE_URL di backend\.env (minta ke pemilik project Neon).
#>
param([string]$Password = "", [switch]$HanyaSiapkan)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$be = Join-Path $root "backend"
$web = Join-Path $PSScriptRoot "web"
$py = Join-Path $be ".venv\Scripts\python.exe"

if (-not (Test-Path $py)) {
  Write-Host "[1/4] Membuat virtualenv backend..."
  python -m venv (Join-Path $be ".venv")
}
Write-Host "[1/4] Memasang dependensi backend (pertama kali agak lama)..."
& $py -m pip install -q -r (Join-Path $be "requirements.txt")

$envFile = Join-Path $be ".env"
if (-not (Test-Path $envFile)) { Copy-Item (Join-Path $be ".env.example") $envFile }
if (-not (Select-String -Path $envFile -Pattern '^DATABASE_URL=\S+' -Quiet)) {
  Write-Host ""
  Write-Host "DATABASE_URL di backend\.env masih kosong. Isi dulu (minta connection string Neon ke tim," -ForegroundColor Yellow
  Write-Host "ikuti format di backend\.env.example), lalu jalankan skrip ini lagi." -ForegroundColor Yellow
  exit 1
}

Write-Host "[2/4] Menyiapkan akun admin..."
Push-Location $be
if ($Password) { & $py scripts\siapkan_admin.py --password $Password } else { & $py scripts\siapkan_admin.py }
Pop-Location

Write-Host "[3/4] Menyiapkan web..."
if (-not (Test-Path (Join-Path $web ".env"))) { Copy-Item (Join-Path $web ".env.example") (Join-Path $web ".env") }
if (-not (Test-Path (Join-Path $web "node_modules"))) { Push-Location $web; npm install; Pop-Location }

if ($HanyaSiapkan) { Write-Host "[4/4] Siap. (-HanyaSiapkan: server tidak dijalankan)"; exit 0 }

Write-Host "[4/4] Menjalankan backend (:8000) dan web (:5173) di jendela baru..."
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$be'; .\.venv\Scripts\Activate.ps1; uvicorn main:app --reload"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$web'; npm run dev"
Start-Sleep 6
Start-Process "http://localhost:5173"
