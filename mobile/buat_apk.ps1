<#
  Bangun APK rilis GALERIA dan beri nama berkas "galeria.apk" (bukan app-release.apk).

  Pemakaian (dari folder mobile):
      .\buat_apk.ps1 -Url https://ALAMAT-TUNNEL.trycloudflare.com

  -Url   alamat backend yang TERTANAM di APK (tunnel yang sedang aktif). Tanpa garis miring di akhir.
  Hasil: mobile\build\galeria.apk  (folder terbuka otomatis; kirim berkas ini ke HP)

  Catatan: nama berkas hasil build Flutter memang selalu app-release.apk (Flutter mencarinya dengan nama itu),
  jadi skrip ini MENYALIN hasilnya menjadi galeria.apk setelah build berhasil.
#>
param(
  [Parameter(Mandatory = $true)][string]$Url
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$Url = $Url.Trim().TrimEnd('/')
if ($Url -notmatch '^https?://') { throw "Url harus diawali http:// atau https://  (contoh: https://abc-def.trycloudflare.com)" }

Write-Host "Membangun APK rilis dengan backend: $Url" -ForegroundColor Cyan
flutter build apk --release "--dart-define=API_BASE_URL=$Url"
if ($LASTEXITCODE -ne 0) { throw "Build gagal (kode $LASTEXITCODE). Lihat pesan di atas." }

$sumber = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $sumber)) { throw "Berkas hasil build tidak ditemukan: $sumber" }

$tujuan = Join-Path $PSScriptRoot 'build\galeria.apk'
Copy-Item $sumber $tujuan -Force

# catat alamat yang tertanam di APK ini, supaya mulai_demo.ps1 bisa memberi tahu bila nanti alamat tunnel berubah
$simpan = Join-Path $env:LOCALAPPDATA 'GaleriaDemo'
New-Item -ItemType Directory -Force $simpan | Out-Null
Set-Content -Path (Join-Path $simpan 'url_apk_terakhir.txt') -Value $Url
$mb = [math]::Round((Get-Item $tujuan).Length / 1MB, 1)
Write-Host "`nSelesai: $tujuan ($mb MB)" -ForegroundColor Green
Write-Host "Kirim berkas galeria.apk ke HP (Drive / WhatsApp sebagai dokumen), lalu pasang." -ForegroundColor Green
explorer.exe (Split-Path $tujuan)
