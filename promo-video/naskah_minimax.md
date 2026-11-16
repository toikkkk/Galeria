# Naskah untuk MiniMax Audio (Text to Speech) — GALERIA "DAY 1" (versi 2, 26 kalimat)

PENTING: naskah ini menggantikan versi 23 kalimat. Ada 3 kalimat baru sebagai peralihan seniman -> kolektor
(l14 sampai l17). Kalau kamu sudah generate versi lama, generate ulang dengan blok di bawah.

## Pengaturan yang disarankan
- Model: Speech 2.8 HD (atau 2.6 HD kalau 2.8 tidak ada). Pilih HD, bukan Turbo.
- Bahasa / Language boost: **Indonesian**.
- Suara: pilih yang terdengar santai/natural, bukan suara "announcer".
- Speed 1.0 (coba 0.95 kalau terburu-buru). Emotion: neutral / calm.
- Penanda jeda `<#detik#>` (0,01-99,99 dtk) harus di antara dua teks yang diucapkan, jangan ditumpuk.
  (Penanda ini dari dokumentasi pihak ketiga; coba satu kalimat dulu. Kalau terbaca sebagai teks, hapus semua `<#...#>`.)

## OPSI A (disarankan): satu kali tempel, saya yang memotong per kalimat
Jeda `<#1.5#>` memisahkan antar-kalimat (supaya mudah dipotong otomatis); jeda `<#0.4#>` kecil di dalam kalimat.
Simpan hasilnya sebagai `promo-video\public\audio\panjang.mp3`, lalu kabari saya.

```
Hari pertama.<#1.5#>Aku seniman.<#1.5#>Lukisanku banyak.<#1.5#>Tapi nggak punya tempat jualan.<#1.5#>Cari event?<#0.4#>Nggak tahu di mana.<#1.5#>Bikin komunitas?<#0.4#>Belum ada.<#1.5#>Info lelang?<#0.4#>Apalagi.<#1.5#>Sampai ketemu Galeria.<#1.5#>Unggah satu karya.<#1.5#>Dicek otomatis:<#0.4#>ada duplikat?<#0.4#>Atau kemungkinan buatan A I?<#1.5#>Lolos?<#0.4#>Dapat sertifikat digital keaslian.<#1.5#>Tapi ini bukan buat ngecek lukisan palsu secara fisik, ya.<#1.5#>Event,<#0.3#>komunitas,<#0.3#>lelang.<#1.5#>Semuanya di satu aplikasi.<#1.5#>Tapi sebagus apa pun karyanya,<#0.4#>masih kurang satu hal.<#1.5#>Orang yang mau memilikinya.<#1.5#>Kenalin,<#0.4#>kolektor.<#1.5#>Dia juga punya masalah.<#1.5#>Naksir lukisan,<#0.3#>tapi nggak tahu muat nggak di kamar.<#1.5#>Tinggal foto.<#1.5#>Visual Search carikan karya yang mirip.<#1.5#>Lalu coba pasang lewat A R.<#1.5#>Ukurannya pas sama aslinya.<#1.5#>Hari pertama.<#0.6#>Karya satu.<#1.5#>Besok?<#0.4#>Kita lihat.<#1.5#>Galeria.<#0.5#>Temukan,<#0.3#>lihat,<#0.3#>miliki.
```

Ejaan: "Galeria" (bukan huruf besar) dibaca satu kata; "A R" dipisah agar dibaca huruf per huruf.
Ada 26 kalimat (25 jeda panjang).

## OPSI B: 26 berkas terpisah
Simpan sebagai `l00.mp3` sampai `l25.mp3` di `promo-video\public\audio\`.

| Berkas | Teks untuk MiniMax |
|---|---|
| l00 | Hari pertama. |
| l01 | Aku seniman. |
| l02 | Lukisanku banyak. |
| l03 | Tapi nggak punya tempat jualan. |
| l04 | Cari event?<#0.4#>Nggak tahu di mana. |
| l05 | Bikin komunitas?<#0.4#>Belum ada. |
| l06 | Info lelang?<#0.4#>Apalagi. |
| l07 | Sampai ketemu Galeria. |
| l08 | Unggah satu karya. |
| l09 | Dicek otomatis:<#0.4#>ada duplikat?<#0.4#>Atau kemungkinan buatan A I? |
| l10 | Lolos?<#0.4#>Dapat sertifikat digital keaslian. |
| l11 | Tapi ini bukan buat ngecek lukisan palsu secara fisik, ya. |
| l12 | Event,<#0.3#>komunitas,<#0.3#>lelang. |
| l13 | Semuanya di satu aplikasi. |
| l14 | Tapi sebagus apa pun karyanya,<#0.4#>masih kurang satu hal. |
| l15 | Orang yang mau memilikinya. |
| l16 | Kenalin,<#0.4#>kolektor. |
| l17 | Dia juga punya masalah. |
| l18 | Naksir lukisan,<#0.3#>tapi nggak tahu muat nggak di kamar. |
| l19 | Tinggal foto. |
| l20 | Visual Search carikan karya yang mirip. |
| l21 | Lalu coba pasang lewat A R. |
| l22 | Ukurannya pas sama aslinya. |
| l23 | Hari pertama.<#0.6#>Karya satu. |
| l24 | Besok?<#0.4#>Kita lihat. |
| l25 | Galeria.<#0.5#>Temukan,<#0.3#>lihat,<#0.3#>miliki. |

## Nada per bagian
- l00-l06: datar, sedikit lesu (masalah seniman). l07: mulai cerah.
- l08-l13: puas, jelas. l09-l11: pelan dan jelas (cek AI dan batasan sertifikat WAJIB terbaca jelas).
- l14-l15: menggantung, seperti membuka cerita baru. l16: ramah, memperkenalkan orang.
- l17-l19: sedikit galau lalu tegas. l20-l22: percaya diri. l23-l25: hangat, penutup pelan.

## Setelah audio jadi
- Opsi A: kabari saya, saya potong otomatis jadi l00..l25 lalu render ulang video.
- Opsi B: `python tools/ukur_audio.py`, lalu
  `npx remotion render src/index.ts Promo out/galeria_promo.mp4 --codec=h264 --crf=18`

## Aturan kejujuran (jangan diubah)
- "sertifikat digital keaslian", bukan "hak paten".
- Kalimat l09 dan l11 wajib ada: sistem mengecek duplikat dan MEMPERKIRAKAN kemungkinan buatan AI (bukan kepastian), dan BUKAN cek keaslian fisik lukisan.
- Jangan ubah "kemungkinan buatan AI" menjadi "pasti buatan AI" atau "mendeteksi AI 100%".
