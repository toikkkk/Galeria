"""Bantu membedakan 'tabel/schema belum ada' dari error SQL lain, supaya router tidak menyamarkan bug nyata."""

from __future__ import annotations

from sqlalchemy.exc import DBAPIError

# 42P01 = undefined_table, 3F000 = invalid_schema_name
_KODE_TABEL_HILANG = {"42P01", "3F000"}


def tabel_belum_ada(exc: DBAPIError) -> bool:
    """True bila error karena tabel/schema belum ada (migrasi/muat data belum dijalankan)."""
    for e in (getattr(exc, "orig", None), getattr(getattr(exc, "orig", None), "__cause__", None)):
        kode = getattr(e, "sqlstate", None) or getattr(e, "pgcode", None)
        if kode in _KODE_TABEL_HILANG:
            return True
    return False
