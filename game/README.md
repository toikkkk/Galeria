# Tebak Lukisan · GALERIA (game pameran)

Game kuis: pengunjung melihat sebuah lukisan, lalu menebak **pelukisnya** dan **aliran seninya**. Dibuat dengan
**Next.js 16** (App Router, TypeScript) dan **GSAP** (animasi). Tidak butuh server atau database: papan skor tersimpan
di browser perangkat pameran (localStorage).

## Menjalankan
```powershell
cd "C:\Users\thori\Downloads\Semester 5\projek galeria\game"
npm install          # sekali saja
npm run dev          # pengembangan: http://localhost:3000
```
Untuk pameran, pakai versi produksi (lebih cepat dan stabil):
```powershell
npm run build
npm start            # http://localhost:3000
```
Buka di Chrome, lalu mode layar penuh: tekan tombol di pojok kanan bawah, atau jalankan
`chrome --kiosk http://localhost:3000`.

## Cara bermain
5 lukisan acak per permainan. Tiap lukisan: lukisan terungkap, **tebak pelukis** (15 dtk), **tebak aliran** (15 dtk),
lalu kartu pengungkap berisi pelukis, aliran, dan keterangan singkat. Skor: **100 poin** per jawaban benar
+ **bonus kecepatan sampai 50** (semakin cepat semakin besar). Akhir permainan: gelar, konfeti, simpan nama ke papan skor.

Layar kembali ke judul sendiri bila tidak disentuh 60 detik (cocok untuk layar pameran tanpa petugas).
Untuk mengosongkan papan skor: buka `http://localhost:3000/?admin=1`, lalu klik "Hapus papan skor (admin)" di layar judul.

## Menambah / mengganti lukisan
1. Taruh gambar di `public/lukisan/` (disarankan **minimal 1200 px** pada sisi panjang, supaya tajam di layar besar).
2. Tambahkan satu objek di `src/data/lukisan.ts` (id, berkas, judul, pelukis, tahun, aliran, fakta).
3. `npm run cek` memeriksa berkas ada, kolom lengkap, dan pengecoh cukup. Lalu `npm run build` ulang.

Pengecoh (pelukis dan aliran yang salah) diambil dari daftar `PELUKIS_PENGECOH` dan `ALIRAN_PENGECOH` di berkas yang sama.

## Pengaturan
`src/lib/game.ts`: `RONDE` (jumlah lukisan), `WAKTU_JAWAB`, `POIN_BENAR`, `BONUS_CEPAT`, `IDLE_RESET_MS`.

## Catatan penting sebelum dipakai di pameran
- **Periksa keterangan lukisan** di `src/data/lukisan.ts` (pelukis, tahun, aliran, fakta, nilai jual). Ditulis dari
  pengetahuan umum seni rupa dan dicocokkan dengan gambar yang dipasok, bukan dari sumber museum.
- **Resolusi gambar rendah.** Beberapa gambar sumber kecil (mis. Penangkapan Diponegoro hanya 283×178 px) sehingga
  akan buram di layar besar. Ganti dengan versi beresolusi tinggi.
- Salvator Mundi: atribusi kepada Leonardo da Vinci masih diperdebatkan sebagian ahli (tertulis di keterangannya).
- Gambar "Jeritan" yang dipasok tampak sudah diberi filter/stilisasi, bukan reproduksi aslinya.

## Struktur
```
src/app/            layout, halaman, gaya (globals.css)
src/components/     Judul, Main (layar permainan), Hasil, Papan, Game (pengatur layar)
src/lib/            game.ts (aturan & skor), papanSkor.ts, konfeti.ts
src/data/lukisan.ts data lukisan + pengecoh
scripts/cek-data.mjs  pemeriksa data
public/lukisan/     gambar lukisan
```
