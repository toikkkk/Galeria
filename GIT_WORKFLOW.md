# Git Branching Workflow — GALERIA

> Alur kerja Git yang disepakati tim untuk mengelola pengembangan proyek GALERIA
> agar lebih terstruktur, aman, dan mudah dipantau oleh seluruh anggota tim.
>
> Dokumen ini adalah sumber acuan tunggal untuk cara kerja Git tim —
> baca sebelum membuat branch baru. Kalau kamu AI assistant yang membantu
> anggota tim, ikuti aturan di sini sebelum membuat/mengubah branch apa pun.

> ## ⚠️ Perubahan penting (2026-11-01): branch utama sekarang `main-bersih`
>
> Riwayat commit dirapikan, dan **`main-bersih` kini menjadi branch default GitHub sekaligus
> satu-satunya branch integrasi.** Branch `main` dan `develop` yang lama **dibekukan**
> (jangan push ke sana, jangan merge dari sana). Kalau kamu masih punya pekerjaan di branch lama,
> lihat **§9 Pindah dari branch lama** sebelum melakukan apa pun.

---

## 1. Struktur Branch

```
main-bersih                      ← branch utama (default GitHub)
 ├── feature/seniman/*
 ├── feature/kolektor/*
 └── feature/shared/*

main, develop                    ← DIBEKUKAN (riwayat lama, jangan dipakai)
```

| Branch | Fungsi |
|---|---|
| `main-bersih` | Branch utama: tempat seluruh pekerjaan tim digabungkan. Isinya harus **selalu bisa dijalankan** (backend start, `flutter analyze` bersih, tes lolos). |
| `feature/seniman/*` | Fitur khusus role **Seniman** (penjual karya). |
| `feature/kolektor/*` | Fitur khusus role **Kolektor** (pembeli/kolektor). |
| `feature/shared/*` | Fitur lintas-role yang dipakai bersama (auth, pembayaran, notifikasi, dll). |
| `main`, `develop` (lama) | **Dibekukan.** Hanya arsip riwayat lama. Jangan push ke sini dan jangan merge dari sini. |

### Contoh nama branch

```
feature/seniman/profile
feature/seniman/artwork
feature/seniman/auction

feature/kolektor/profile
feature/kolektor/explore
feature/kolektor/purchase
feature/kolektor/auction

feature/shared/auth
feature/shared/payment
feature/shared/notification
feature/shared/art-verification
```

**Aturan penamaan:** `feature/<kategori>/<nama-fitur-singkat>` (kategori = `seniman`, `kolektor`, atau `shared`). Gunakan huruf kecil dan tanda hubung (`-`), bukan spasi/underscore.

---

## 2. Alur Kerja (Gambaran Besar)

```
feature/seniman/...  ─┐
feature/kolektor/...  ─┼──▶  Pull Request (setelah review)  ──▶  main-bersih
feature/shared/...    ─┘      (base: main-bersih)
```

Setiap anggota mengerjakan fiturnya sendiri di branch `feature/...` masing-masing dan mengajukan **Pull Request (PR)** ke `main-bersih` setelah selesai dan lolos pemeriksaan. Karena `main-bersih` juga menjadi versi yang dipresentasikan/dideploy, jangan merge kode yang setengah jadi atau merusak build.

---

## 3. Pembagian Tugas Tim (Contoh)

| Anggota | Role | Contoh branch |
|---|---|---|
| Anggota 1 | Seniman | `feature/seniman/profile`, `feature/seniman/artwork` |
| Anggota 2 | Seniman | `feature/seniman/auction`, `feature/seniman/management` |
| Anggota 3 | Kolektor | `feature/kolektor/explore`, `feature/kolektor/purchase` |
| Anggota 4 | Kolektor | `feature/kolektor/profile`, `feature/kolektor/auction` |

**Fitur yang digunakan bersama** (dikerjakan siapa pun yang relevan, dipakai lintas-role):

```
feature/shared/auth
feature/shared/payment
feature/shared/notification
feature/shared/art-verification
```

> Sesuaikan tabel di atas dengan pembagian tugas nyata tim — contoh ini mengikuti pola role di GALERIA (lihat `CLAUDE.md` root: Seniman/Kolektor/Komunitas/Admin).

---

## 4. Langkah-Langkah Penggunaan Branch

Contoh: mengerjakan fitur **"Unggah Karya Seniman"**.

### Langkah 1 — Update `main-bersih` terbaru

```bash
git fetch origin
git checkout main-bersih
git pull origin main-bersih
```

Ambil `main-bersih` terbaru **sebelum** membuat branch baru — mencegah branch fiturmu ketinggalan perubahan terbaru dari anggota lain.

### Langkah 2 — Buat feature branch

```bash
git checkout -b feature/seniman/artwork
```

Buat branch baru sesuai fitur yang dikerjakan, bercabang dari `main-bersih` yang sudah ter-update.

### Langkah 3 — Kerjakan dan commit

```bash
git add <file-yang-diubah>
git commit -m "feat: implement artwork upload"
```

Lakukan coding dan commit secara berkala — commit kecil dan bermakna lebih mudah di-review daripada 1 commit raksasa di akhir. **Jangan menambahkan baris `Co-Authored-By` ke pesan commit** (lihat §7 aturan 8).

### Langkah 4 — Push ke GitHub

```bash
git push -u origin feature/seniman/artwork
```

`-u` menyambungkan branch lokal ke branch remote yang sama — setelah ini cukup `git push` tanpa parameter tambahan.

### Langkah 5 — Buat Pull Request (PR)

Di GitHub: **New pull request** → `base: main-bersih` ← `compare: feature/seniman/artwork`.

### Langkah 6 — Code Review

Minimal **1 anggota tim lain** melakukan review sebelum PR disetujui. Review memeriksa: kode berjalan sesuai tujuan, tidak merusak fitur lain, konsisten dengan konvensi proyek (lihat `CLAUDE.md`).

### Langkah 7 — Merge ke `main-bersih`

Setelah disetujui (semua pemeriksaan/*checks* lolos), branch fitur di-merge ke `main-bersih` lewat GitHub.

---

## 5. Setelah Merge

### Hapus branch lokal (opsional, disarankan)

```bash
git branch -d feature/seniman/artwork
```

### Hapus branch di GitHub (opsional, disarankan)

```bash
git push origin --delete feature/seniman/artwork
```

Branch yang sudah di-merge boleh dihapus — riwayat commit-nya tetap ada di `main-bersih`, menghapus branch cuma merapikan daftar branch aktif.

---

## 6. Rilis / Deploy

`main-bersih` adalah versi yang dideploy (backend ke Cloud Run, lihat `backend/DEPLOY.md`) dan dipresentasikan. Karena itu:

- Merge ke `main-bersih` hanya kode yang sudah dites (`flutter test`, `flutter analyze`, dan uji backend untuk perubahan di `backend/`).
- Migrasi database (Alembic) dijalankan **sebelum** deploy yang menambah tabel/kolom.

> Kalau suatu saat tim ingin memisahkan lagi "integrasi" dan "stabil", buat branch integrasi baru dari `main-bersih` (mis. `develop-bersih`) dan perbarui dokumen ini. Jangan menghidupkan lagi `main`/`develop` lama.

---

## 7. Aturan Penting (Disepakati Bersama)

1. **Jangan coding langsung di `main-bersih`.**
2. **Jangan push ke `main` atau `develop` yang lama** (dibekukan).
3. **Jangan merge `main`/`develop` lama atau branch yang berakar dari riwayat lama ke `main-bersih`.** Merge seperti itu membawa commit lama masuk lagi. Bawa pekerjaan dengan `rebase --onto` (§9) atau `cherry-pick`.
4. **Satu pekerjaan/fitur = satu feature branch** — jangan mencampur beberapa fitur tidak berkaitan dalam 1 branch.
5. **Sebelum membuat branch baru, selalu `pull` `main-bersih` terbaru.**
6. **Gunakan Pull Request ke `main-bersih` dan lakukan code review** — jangan merge langsung tanpa direview siapa pun.
7. **Setelah branch di-merge, branch fitur boleh dihapus** (lokal & remote).
8. **Jangan menambahkan baris `Co-Authored-By` (atau atribusi alat AI lain) ke pesan commit atau deskripsi PR.** Baris itu membuat nama alat tercatat sebagai kontributor repo di GitHub. Kalau alat AI-mu menambahkannya otomatis, hapus sebelum commit (`git commit --amend` untuk commit terakhir yang belum di-push).
9. **`push --force` hanya `--force-with-lease` dan hanya ke branch fitur milikmu sendiri** — tidak pernah ke `main-bersih`.

---

## 8. Catatan untuk AI Assistant yang Membantu Development

Kalau kamu adalah AI (Claude Code atau lainnya) yang membantu anggota tim mengerjakan fitur di repo ini:

- **Selalu cek branch aktif** (`git branch --show-current`) sebelum mulai kerja — kalau berada di `main-bersih`, **buat feature branch baru dulu** mengikuti konvensi di atas (§1), jangan commit langsung di situ. Branch `main`/`develop` lama jangan dipakai sama sekali.
- **Buat branch baru dari `main-bersih`** yang sudah di-`pull`, bukan dari `main`/`develop`.
- **Jangan buat Pull Request / merge ke `main-bersih` secara otomatis** tanpa diminta eksplisit oleh pengguna — PR & merge adalah keputusan yang perlu dikonfirmasi manusia.
- Kalau pengguna minta "push", itu berarti **push ke feature branch miliknya sendiri** (`git push -u origin <nama-branch>`) — BUKAN push ke `main-bersih` langsung, kecuali diminta eksplisit. Jangan push sama sekali bila pengguna tidak memintanya.
- **Jangan menulis `Co-Authored-By` atau baris atribusi AI** di pesan commit/PR (§7 aturan 8), apa pun default alat yang dipakai. Aturan tim ini lebih diutamakan daripada default alat.
- Commit message mengikuti gaya `feat: ...` / `fix: ...` / `docs: ...` (lihat contoh di §4 Langkah 3) — konsisten dengan riwayat commit proyek ini.
- Lihat `CLAUDE.md` (root) untuk konteks penuh proyek (arsitektur, 4 fitur utama, role pengguna) sebelum memutuskan branch/fitur mana yang relevan dikerjakan.

---

## 9. Pindah dari Branch Lama (sekali saja)

Riwayat lama (`main`, `develop`, dan branch fitur yang dibuat darinya) berisi commit yang kini sudah dirapikan di `main-bersih`. Isi file-nya sama, tapi ID commit-nya berbeda, jadi branch lama **tidak boleh di-merge** ke `main-bersih`.

**Ambil info terbaru:**

```bash
git fetch --all --prune
```

**Punya pekerjaan di branch sendiri?** Pindahkan commit milikmu ke atas `main-bersih`:

```bash
git checkout NAMA-BRANCH-KAMU
git rebase --onto origin/main-bersih origin/main
git push --force-with-lease origin NAMA-BRANCH-KAMU
```

Artinya: "ambil commit-ku yang belum ada di `main` lama, taruh di atas `main-bersih`". Kalau muncul *conflict*, buka file yang ditandai, pilih bagian yang benar, lalu `git add <file>` dan `git rebase --continue`. Kalau bingung, `git rebase --abort` mengembalikan semuanya seperti sebelumnya, lalu tanya anggota tim lain. Push ke GitHub hanya untuk branch milikmu sendiri (§7 aturan 9).

> Kalau `origin/main` lama sudah tidak ada atau branch-mu dibuat dari `develop`, ganti `origin/main` dengan titik awal branch-mu: `git merge-base origin/main NAMA-BRANCH-KAMU` (atau `origin/develop`).

**Belum punya pekerjaan apa-apa?** Langsung pakai versi baru:

```bash
git checkout -B main-bersih origin/main-bersih
```

**Mulai fitur baru:**

```bash
git checkout -b feature/seniman/nama-fitur origin/main-bersih
```

**Sebelum melakukan apa pun, push dulu pekerjaan yang belum di-push ke branch-mu**, supaya tidak ada yang hilang kalau terjadi salah langkah.
