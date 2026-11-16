<#
  MULAI DEMO GALERIA -- satu perintah untuk menyalakan semuanya.

  Dari folder proyek (projek galeria):
      .\mulai_demo.ps1                 menyalakan tunnel + backend, menampilkan alamat dan status
      .\mulai_demo.ps1 -BangunApk      + membangun galeria.apk dengan alamat tunnel yang baru
      .\mulai_demo.ps1 -Dashboard      + memperbarui dashboard web (Vercel) ke alamat yang baru
      .\mulai_demo.ps1 -BangunApk -Dashboard   semuanya

  Yang dikerjakan skrip ini, berurutan:
    1. Mematikan tunnel dan backend lama (bila masih menyala).
    2. Menyalakan tunnel gratis (cloudflared) dan membaca alamat https://....trycloudflare.com yang baru.
    3. Menulis alamat itu ke backend\.env (GAMBAR_PROXY_BASE) SEBELUM backend dinyalakan, jadi tidak perlu restart lagi.
    4. Menyalakan backend (jendela baru), lalu menunggu sampai backend dan tunnel benar-benar menjawab.
    5. Memberi tahu apakah APK di HP perlu dibangun ulang (alamat tunnel berubah tiap dinyalakan).

  Jendela backend dan tunnel yang terbuka JANGAN ditutup selama demo.
#>
param(
  [switch]$BangunApk,
  [switch]$Dashboard,
  [switch]$Cloudflare   # paksa tunnel gratis cloudflared (alamat berganti tiap dinyalakan), walau ngrok sudah siap
)

$root = $PSScriptRoot
$backend = Join-Path $root 'backend'
$envFile = Join-Path $backend '.env'
$simpan = Join-Path $env:LOCALAPPDATA 'GaleriaDemo'
$logTunnel = Join-Path $simpan 'tunnel.log'
$fileUrlApk = Join-Path $simpan 'url_apk_terakhir.txt'

function Baca-Bebas([string]$Path) {
  # baca file yang sedang ditulis proses lain (log cloudflared)
  $fs = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
  try { (New-Object IO.StreamReader($fs)).ReadToEnd() } finally { $fs.Dispose() }
}

function Ambil-UrlTunnel([string]$LogPath, [int]$TimeoutDetik = 45) {
  $batas = (Get-Date).AddSeconds($TimeoutDetik)
  while ((Get-Date) -lt $batas) {
    if (Test-Path $LogPath) {
      try { $teks = Baca-Bebas $LogPath } catch { $teks = $null }
      if ($teks) {
        $m = [regex]::Matches($teks, 'https://(?!api\.)[a-z0-9-]+\.trycloudflare\.com')
        if ($m.Count -gt 0) { return $m[0].Value }
      }
    }
    Start-Sleep -Milliseconds 700
  }
  return $null
}

function Set-EnvKey([string]$Path, [string]$Key, [string]$Value) {
  $baris = [IO.File]::ReadAllLines($Path)
  $ketemu = $false
  $baru = foreach ($b in $baris) {
    if ($b -match ('^\s*' + [regex]::Escape($Key) + '\s*=')) { $ketemu = $true; "$Key=$Value" } else { $b }
  }
  if (-not $ketemu) { $baru = @($baru) + "$Key=$Value" }
  [IO.File]::WriteAllLines($Path, [string[]]$baru, (New-Object Text.UTF8Encoding($false)))
}

function Cek-Url([string]$Url) {
  # header ngrok: tanpa ini ngrok membalas halaman peringatan (HTML) untuk klien yang dikira browser
  try { return ((Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 8 -Headers @{ 'ngrok-skip-browser-warning' = '1' }).StatusCode -eq 200) } catch { return $false }
}

function Cari-Ngrok {
  $c = (Get-Command ngrok -ErrorAction SilentlyContinue).Source
  if ($c) { return $c }
  $kandidat = @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Filter 'ngrok.exe' -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName)
  $kandidat += (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\ngrok.exe')
  foreach ($k in $kandidat) { if ($k -and (Test-Path $k)) { return $k } }
  return $null
}

function Ngrok-SiapToken {
  # authtoken tersimpan di ngrok.yml setelah `ngrok config add-authtoken ...`
  foreach ($f in @((Join-Path $env:LOCALAPPDATA 'ngrok\ngrok.yml'), (Join-Path $env:USERPROFILE '.ngrok2\ngrok.yml'))) {
    if ((Test-Path $f) -and (Select-String -Path $f -Pattern 'authtoken' -Quiet)) { return $true }
  }
  return $false
}

function Ambil-UrlNgrok([int]$TimeoutDetik = 40) {
  # ngrok menyediakan API lokal di 127.0.0.1:4040
  $batas = (Get-Date).AddSeconds($TimeoutDetik)
  while ((Get-Date) -lt $batas) {
    try {
      $t = (Invoke-RestMethod 'http://127.0.0.1:4040/api/tunnels' -TimeoutSec 3).tunnels | Where-Object { $_.public_url -like 'https://*' } | Select-Object -First 1
      if ($t) { return $t.public_url }
    } catch { }
    Start-Sleep -Milliseconds 700
  }
  return $null
}

function Tunggu-Url([string]$Url, [int]$TimeoutDetik) {
  $batas = (Get-Date).AddSeconds($TimeoutDetik)
  while ((Get-Date) -lt $batas) {
    if (Cek-Url $Url) { return $true }
    Start-Sleep -Seconds 2
  }
  return $false
}

# bila skrip ini di-"dot-source" (untuk uji fungsi), berhenti di sini
if ($MyInvocation.InvocationName -eq '.') { return }

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $simpan | Out-Null

# --- prasyarat -------------------------------------------------------------------------------
$py = Join-Path $backend '.venv\Scripts\python.exe'
if (-not (Test-Path $py)) { throw "Python backend tidak ditemukan: $py" }
if (-not (Test-Path $envFile)) { throw "backend\.env tidak ditemukan." }

# Pilih jenis tunnel: ngrok (alamat TETAP) bila terpasang + authtoken sudah diisi, kalau tidak cloudflared (alamat berganti).
$ngrok = if ($Cloudflare) { $null } else { Cari-Ngrok }
$pakaiNgrok = $false
if ($ngrok) {
  if (Ngrok-SiapToken) { $pakaiNgrok = $true }
  else {
    Write-Host "ngrok terpasang tetapi authtoken belum diisi -> memakai cloudflared (alamat berubah tiap dinyalakan)." -ForegroundColor Yellow
    Write-Host "Isi sekali:  ngrok config add-authtoken TOKEN-DARI-DASHBOARD-NGROK" -ForegroundColor Yellow
  }
}
$cf = (Get-Command cloudflared -ErrorAction SilentlyContinue).Source
if (-not $cf) { $cf = 'C:\Program Files (x86)\cloudflared\cloudflared.exe' }
if (-not $pakaiNgrok -and -not (Test-Path $cf)) { throw "Tidak ada tunnel yang bisa dipakai. Pasang ngrok (winget install Ngrok.Ngrok) atau cloudflared (winget install Cloudflare.cloudflared)." }

# --- 1. matikan yang lama -----------------------------------------------------------------------
Write-Host "1/5  Mematikan tunnel & backend lama (kalau ada)..." -ForegroundColor Cyan
Get-Process -Name cloudflared, ngrok -ErrorAction SilentlyContinue | Stop-Process -Force
Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
  $p = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
  if ($p -and $p.ProcessName -match 'python') { Stop-Process -Id $p.Id -Force }
}
Start-Sleep -Seconds 2

# --- 2. tunnel -------------------------------------------------------------------------------------
if ($pakaiNgrok) {
  Write-Host "2/5  Menyalakan tunnel ngrok (alamat tetap)..." -ForegroundColor Cyan
  Start-Process -FilePath $ngrok -ArgumentList @('http', '8000') -WindowStyle Minimized | Out-Null
  $url = Ambil-UrlNgrok 40
  if (-not $url) { throw "Alamat ngrok tidak muncul dalam 40 detik. Buka http://127.0.0.1:4040 untuk melihat penyebabnya (mis. authtoken salah atau sesi ngrok lain masih aktif di akunmu)." }
} else {
  Write-Host "2/5  Menyalakan tunnel cloudflared (alamat berubah tiap dinyalakan)..." -ForegroundColor Cyan
  if (Test-Path $logTunnel) { Remove-Item $logTunnel -Force }
  Start-Process -FilePath $cf -ArgumentList @('tunnel', '--url', 'http://localhost:8000', '--logfile', $logTunnel) -WindowStyle Minimized | Out-Null
  $url = Ambil-UrlTunnel $logTunnel 45
  if (-not $url) { throw "Alamat tunnel tidak muncul dalam 45 detik. Periksa koneksi internet lalu jalankan lagi." }
}
Write-Host "     Alamat: $url" -ForegroundColor Green

# --- 3. .env -----------------------------------------------------------------------------------------
Write-Host "3/5  Menulis alamat ke backend\.env (GAMBAR_PROXY_BASE)..." -ForegroundColor Cyan
Set-EnvKey $envFile 'GAMBAR_PROXY_BASE' "$url/api/gambar"

# --- 4. backend --------------------------------------------------------------------------------------
Write-Host "4/5  Menyalakan backend (jendela baru; jangan ditutup)..." -ForegroundColor Cyan
Start-Process -FilePath $py -ArgumentList @('-m', 'uvicorn', 'main:app', '--port', '8000') -WorkingDirectory $backend | Out-Null
if (-not (Tunggu-Url 'http://localhost:8000/docs' 150)) { throw "Backend belum menjawab dalam 150 detik. Lihat jendela backend untuk pesan error." }
Write-Host "     Backend menjawab." -ForegroundColor Green
Write-Host "     Menunggu tunnel bisa dijangkau dari internet..." -ForegroundColor DarkGray
$tunnelOk = Tunggu-Url "$url/docs" 60

# --- 5. APK / dashboard -----------------------------------------------------------------------------
Write-Host "5/5  Memeriksa APK..." -ForegroundColor Cyan
$urlApk = if (Test-Path $fileUrlApk) { (Get-Content $fileUrlApk -Raw).Trim() } else { '' }
if ($BangunApk) {
  & (Join-Path $root 'mobile\buat_apk.ps1') -Url $url
  Set-Content -Path $fileUrlApk -Value $url
  $urlApk = $url
}
if ($Dashboard) {
  Write-Host "     Memperbarui dashboard web (Vercel)..." -ForegroundColor Cyan
  Push-Location (Join-Path $root 'dashboard-admin\web')
  try {
    $ErrorActionPreference = 'Continue'
    npx vercel env rm VITE_API_BASE production --yes *> $null
    npx vercel env add VITE_API_BASE production --value $url --no-sensitive --yes
    npx vercel --prod
  } finally { Pop-Location; $ErrorActionPreference = 'Stop' }
}

# --- ringkasan ------------------------------------------------------------------------------------------
Write-Host ""
Write-Host "================ SIAP ================" -ForegroundColor Green
Write-Host "Alamat backend : $url   [$(if ($pakaiNgrok) { 'ngrok - alamat TETAP' } else { 'cloudflared - alamat berubah' })]"
Write-Host ("Tunnel dari internet : " + $(if ($tunnelOk) { 'MENJAWAB' } else { 'belum menjawab (tunggu sebentar lalu buka ' + $url + '/docs di browser HP)' }))
if ($urlApk -eq $url) {
  Write-Host "APK di HP      : cocok dengan alamat ini (tidak perlu dibangun ulang)." -ForegroundColor Green
} else {
  Write-Host "APK di HP      : MUNGKIN BELUM COCOK$(if (-not $pakaiNgrok) { ' (alamat tunnel berubah tiap dinyalakan)' })." -ForegroundColor Yellow
  Write-Host "                 Bangun ulang:  .\mulai_demo.ps1 -BangunApk   (atau mobile\buat_apk.ps1 -Url $url)"
}
Write-Host ""
Write-Host "Akun demo (password: Galeria2026):  kolektor01@demo.galeria.test  |  aria.wijaya@demo.galeria.test"
Write-Host "Jangan tutup jendela backend & tunnel selama demo."
