"""Registrasi SEMUA model SQLAlchemy ke ``Base.metadata`` (lihat
``database.py``), supaya resolusi foreign key lintas-tabel (mis.
``karya.sertifikat_aktif_id -> sertifikat_keaslian.id``) selalu berhasil
tidak peduli router mana yang sedang aktif/di-import duluan.

Tanpa file ini: SQLAlchemy hanya tahu suatu tabel ADA kalau modul yang
mendefinisikannya pernah di-import di suatu tempat sebelum query/insert
pertama dijalankan -- gagal dengan ``NoReferencedTableError`` yang
membingungkan kalau lupa (pernah terjadi nyata: endpoint
``POST /api/karya`` gagal karena ``models/sertifikat.py`` tidak pernah
ter-import, walau tabelnya sendiri sudah ada di Neon).

``main.py`` cukup ``import models`` SEKALI saat startup -- tidak perlu tahu
daftar modul di bawah ini satu-satu.
"""

from __future__ import annotations

from . import engagement, event, karya, lelang, sertifikat, transaksi, user, verification

__all__ = [
    "engagement",
    "event",
    "karya",
    "lelang",
    "sertifikat",
    "transaksi",
    "user",
    "verification",
]
