# Git Branching Workflow — GALERIA

> Alur kerja Git yang disepakati tim untuk mengelola pengembangan proyek GALERIA
> agar lebih terstruktur, aman, dan mudah dipantau oleh seluruh anggota tim.
>
> **Status: berlaku mulai fase development model & fitur (minggu ini & minggu
> depan).** Dokumen ini adalah sumber acuan tunggal untuk cara kerja Git tim —
> baca sebelum membuat branch baru. Kalau kamu AI assistant yang membantu
> anggota tim, ikuti aturan di sini sebelum membuat/mengubah branch apa pun.

---

## 1. Struktur Branch

```
main
 └── develop
      ├── feature/seniman/*
      ├── feature/kolektor/*
      └── feature/shared/*
```

| Branch | Fungsi |
|---|---|
| `main` | Versi stabil / release (production). **Hanya** berisi kode yang sudah teruji penuh. |
| `develop` | Branch integrasi — tempat seluruh pekerjaan tim digabungkan sebelum rilis. |
| `feature/seniman/*` | Fitur khusus role **Seniman** (penjual karya). |
| `feature/kolektor/*` | Fitur khusus role **Kolektor** (pembeli/kolektor). |
| `feature/shared/*` | Fitur lintas-role yang dipakai bersama (auth, pembayaran, notifikasi, dll). |

### Contoh nama branch

```
feature/seniman/profile
feature/seniman/artwork
feature/seniman/auction

feature/kolektor/profile
feature/kolektor/explore
feature/kolektor/purchase
feature/kolektor/auction

feature/auth
feature/payment
feature/notification
feature/art-verification
feature/ai-detection
```

**Aturan penamaan:** `feature/<kategori>/<nama-fitur-singkat>` untuk fitur khusus role, atau `feature/<nama-fitur>` langsung untuk fitur bersama (`feature/shared/*`). Gunakan huruf kecil dan tanda hubung (`-`), bukan spasi/underscore.

---

## 2. Alur Kerja (Gambaran Besar)

```
feature/seniman/...  ─┐
feature/kolektor/...  ─┼──▶  Pull Request (setelah review)  ──▶  develop  ──▶  main
feature/shared/...    ─┘        (base: develop)                (integrasi)   (stabil/release)
```

Setiap anggota mengerjakan fiturnya sendiri di branch `feature/...` masing-masing, mengajukan **Pull Request (PR)** ke `develop` setelah selesai, dan `develop` di-merge ke `main` hanya setelah seluruh fitur yang direncanakan selesai, sudah melalui testing, dan dinyatakan stabil.

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
feature/auth
feature/payment
feature/notification
feature/art-verification
```

> Sesuaikan tabel di atas dengan pembagian tugas nyata tim — contoh ini mengikuti pola role di GALERIA (lihat `CLAUDE.md` root: Seniman/Kolektor/Komunitas/Admin).

---

## 4. Langkah-Langkah Penggunaan Branch

Contoh: mengerjakan fitur **"Unggah Karya Seniman"**.

### Langkah 1 — Update `develop` terbaru

```bash
git checkout develop
git pull origin develop
```

Ambil `develop` terbaru **sebelum** membuat branch baru — mencegah branch fiturmu ketinggalan perubahan terbaru dari anggota lain.

### Langkah 2 — Buat feature branch

```bash
git checkout -b feature/seniman/artwork
```

Buat branch baru sesuai fitur yang dikerjakan, bercabang dari `develop` yang sudah ter-update.

### Langkah 3 — Kerjakan dan commit

```bash
git add .
git commit -m "feat: implement artwork upload"
```

Lakukan coding dan commit secara berkala — commit kecil dan bermakna lebih mudah di-review daripada 1 commit raksasa di akhir.

### Langkah 4 — Push ke GitHub

```bash
git push -u origin feature/seniman/artwork
```

`-u` menyambungkan branch lokal ke branch remote yang sama — setelah ini cukup `git push` tanpa parameter tambahan.

### Langkah 5 — Buat Pull Request (PR)

Di GitHub: **New pull request** → `base: develop` ← `compare: feature/seniman/artwork`.

### Langkah 6 — Code Review

Minimal **1 anggota tim lain** melakukan review sebelum PR disetujui. Review memeriksa: kode berjalan sesuai tujuan, tidak merusak fitur lain, konsisten dengan konvensi proyek (lihat `CLAUDE.md`).

### Langkah 7 — Merge ke `develop`

Setelah disetujui (semua pemeriksaan/*checks* lolos), branch fitur di-merge ke `develop` lewat GitHub.

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

Branch yang sudah di-merge boleh dihapus — riwayat commit-nya tetap ada di `develop`, menghapus branch cuma merapikan daftar branch aktif.

---

## 6. Proses hingga ke `main`

```
Feature (oleh masing-masing anggota)
        │
        ▼
Pull Request ke develop (setelah review)
        │
        ▼
Testing & Integrasi
        │
        ▼
Merge ke main (Release / Stabil)
```

> **Penting:** merge dari `develop` ke `main` dilakukan **setelah seluruh fitur yang direncanakan selesai**, sudah melalui testing, dan dinyatakan stabil — bukan setiap kali 1 fitur selesai. `main` selalu mencerminkan versi yang siap dipakai/dipresentasikan.

---

## 7. Aturan Penting (Disepakati Bersama)

1. **Jangan coding langsung di `main`.**
2. **Jangan coding langsung di `develop`.**
3. **Satu pekerjaan/fitur = satu feature branch** — jangan mencampur beberapa fitur tidak berkaitan dalam 1 branch.
4. **Sebelum membuat branch baru, selalu `pull` `develop` terbaru.**
5. **Gunakan Pull Request ke `develop` dan lakukan code review** — jangan merge langsung tanpa direview siapa pun.
6. **`main` hanya untuk versi yang sudah stabil/final.**
7. **Setelah branch di-merge, branch fitur boleh dihapus** (lokal & remote).

---

## 8. Catatan untuk AI Assistant yang Membantu Development

Kalau kamu adalah AI (Claude Code atau lainnya) yang membantu anggota tim mengerjakan fitur di repo ini:

- **Selalu cek branch aktif** (`git branch --show-current`) sebelum mulai kerja — kalau berada di `main`/`develop`, **buat feature branch baru dulu** mengikuti konvensi di atas (§1), jangan commit langsung di situ.
- **Selalu `git pull origin develop` ke branch barumu** kalau membuat branch dari `develop` yang sudah lama tidak di-update.
- **Jangan buat Pull Request / merge ke `develop` atau `main` secara otomatis** tanpa diminta eksplisit oleh pengguna — PR & merge adalah keputusan yang perlu dikonfirmasi manusia (lihat aturan "actions yang butuh persetujuan" umum di praktik kerja proyek ini).
- Kalau pengguna minta "push", itu berarti **push ke feature branch miliknya sendiri** (`git push -u origin <nama-branch>`) — BUKAN push ke `develop`/`main` langsung, kecuali diminta eksplisit.
- Commit message mengikuti gaya `feat: ...` / `fix: ...` / `docs: ...` (lihat contoh di §4 Langkah 3) — konsisten dengan riwayat commit proyek ini.
- Lihat `CLAUDE.md` (root) untuk konteks penuh proyek (arsitektur, 4 fitur utama, role pengguna) sebelum memutuskan branch/fitur mana yang relevan dikerjakan.
