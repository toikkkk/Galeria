# Naskah Voice Over GALERIA: "DAY 1, bikin galeri dari nol"

Total 23 kalimat, ±55-65 detik bila dibaca santai. Satu baris = satu rekaman = satu subtitle.
Kata **tebal** = kata yang ditekan (di video diwarnai kuning).

## Cara membacakan
- Nada: santai, datar sedikit sarkastik (seperti bercerita ke teman). Bukan nada iklan yang ceria.
- Kalimat pendek: beri jeda ±0,3 detik di antara kalimat. Jangan buru-buru.
- Tekan satu kata tebal di tiap kalimat, sisanya biasa.
- Titik = turun. Tanda tanya = naik sedikit, lalu diam sebentar ("Cari event? ... Nggak tahu di mana.").
- Rekam tiap kalimat TERPISAH, boleh diulang sampai enak. Hening di awal/akhir berkas tidak masalah (saya pangkas).

## Naskah

| No | Berkas | Kalimat | Catatan membaca |
|---|---|---|---|
| 1 | l00 | Hari pertama. | Tenang, pelan. |
| 2 | l01 | Aku **seniman.** | Datar, sedikit bangga. |
| 3 | l02 | Lukisanku **banyak.** | Datar. |
| 4 | l03 | Tapi nggak punya **tempat jualan.** | "Tapi" naik, "tempat jualan" turun lesu. |
| 5 | l04 | Cari event? Nggak tahu di mana. | Bingung, jeda setelah "event?". |
| 6 | l05 | Bikin komunitas? **Belum ada.** | Jeda setelah "komunitas?". |
| 7 | l06 | Info lelang? Apalagi. | Pasrah. |
| 8 | l07 | Sampai ketemu **GALERIA.** | Cerah sedikit. Sebut "ga-le-ri-a". |
| 9 | l08 | Unggah satu karya. | Santai, cepat. |
| 10 | l09 | Dicek otomatis: ada **duplikat**? Atau **kemungkinan buatan AI**? | Dua pertanyaan, jeda kecil. Jelas, jangan terdengar pasti. |
| 11 | l10 | Lolos? Dapat **sertifikat digital keaslian.** | Naik di "Lolos?", lalu tegas. |
| 12 | l11 | Tapi ini bukan buat ngecek lukisan palsu secara fisik, ya. | Hati-hati, jelas. WAJIB dibaca (batasan fitur). |
| 13 | l12 | Event, komunitas, lelang. | Tiga hal, jeda kecil tiap koma. |
| 14 | l13 | Semuanya di **satu aplikasi.** | Puas. |
| 15 | l14 | Sekarang, giliran pembeli. | Ganti topik, jeda setelah "Sekarang,". |
| 16 | l15 | Naksir lukisan, tapi nggak tahu **muat nggak** di kamar. | Galau. |
| 17 | l16 | Tinggal **foto.** | Pendek, tegas. |
| 18 | l17 | Visual Search carikan karya yang **mirip.** | Percaya diri. "Visual Search" dibaca Inggris. |
| 19 | l18 | Lalu coba pasang lewat **AR.** | Dibaca "A-R" (ei-ar). |
| 20 | l19 | Ukurannya **pas** sama aslinya. | Puas. |
| 21 | l20 | Hari pertama. Karya satu. | Jeda sebentar di antara dua kalimat. |
| 22 | l21 | Besok? Kita lihat. | Santai, sedikit menggantung. |
| 23 | l22 | GALERIA. Temukan, lihat, miliki. | Penutup. Tiga kata terakhir pelan, jelas. |

## Format berkas
Simpan di folder `promo-video\public\audio\` dengan nama persis `l00` sampai `l22`
(contoh: `l00.mp3`, `l01.wav`, `l22.m4a`). Format boleh .mp3, .wav, atau .m4a.
Kalau 23 berkas sulit, beri tahu saya: bisa satu rekaman panjang lalu saya potong (butuh jeda jelas antar kalimat).

## Memasang ke video (setelah semua berkas ada)
```powershell
cd "C:\Users\thori\Downloads\Semester 5\projek galeria\promo-video"
python tools/ukur_audio.py
npx remotion render src/index.ts Promo out/galeria_promo.mp4 --codec=h264 --crf=18
```
`ukur_audio.py` mengukur durasi tiap rekamanmu supaya subtitle dan adegan mengikuti kecepatan bicaramu.
Berkas `l00..l22` yang sekarang ada di folder itu adalah suara contoh (edge-tts); akan tertimpa rekamanmu.

## Aturan kejujuran (jangan diubah)
- Katakan "sertifikat digital keaslian", jangan "hak paten".
- Kalimat 11 dan 12 (batasan: bukan cek lukisan palsu, hanya cek duplikasi unggahan) wajib ada.
- Jangan menambah klaim di luar naskah (chatbot, login Google, akurasi sekian persen).
