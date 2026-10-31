"""Penyedia pembayaran.

Saat ini hanya mode ``sandbox``: instruksi pembayaran (nomor virtual account / kode QRIS) dibuat
sendiri dan pembayaran DISIMULASIKAN lewat ``POST /api/pesanan/{id}/bayar/simulasi`` -- tidak ada uang
sungguhan dan tidak ada gateway di belakangnya. Alurnya sengaja sama dengan gateway sungguhan (pilih
metode -> dapat instruksi -> status berubah saat pembayaran diterima), jadi menyambungkan Midtrans nanti
cukup mengganti dua hal di sini: ``buat_instruksi`` (minta transaksi ke gateway) dan penerima webhook
yang memanggil ``pesanan_service.tandai_dibayar``.

``PAYMENT_MODE`` (env): ``sandbox`` (default). Nilai lain belum diimplementasi dan ditolak dengan jelas.
"""

from __future__ import annotations

import hashlib
import os
import uuid

METODE = {
    "va_bca": ("Virtual Account BCA", "70012"),
    "va_mandiri": ("Virtual Account Mandiri", "88908"),
    "va_bni": ("Virtual Account BNI", "8277"),
    "qris": ("QRIS", ""),
}


class PembayaranTidakTersedia(RuntimeError):
    pass


def mode() -> str:
    return (os.environ.get("PAYMENT_MODE") or "sandbox").strip().lower()


def pastikan_didukung() -> None:
    if mode() != "sandbox":
        raise PembayaranTidakTersedia(f"PAYMENT_MODE={mode()} belum didukung (baru 'sandbox').")


def simulasi_diizinkan() -> bool:
    return mode() == "sandbox"


def buat_instruksi(metode: str, transaksi_id: uuid.UUID) -> tuple[str, str]:
    """(nama_metode, nomor) -- nomor stabil untuk transaksi yang sama (diturunkan dari id)."""
    pastikan_didukung()
    nama, prefix = METODE[metode]
    angka = str(int(hashlib.sha256(transaksi_id.bytes).hexdigest()[:15], 16))[:11].rjust(11, "0")
    if metode == "qris":
        return nama, f"GALERIA.QRIS.{angka}"
    return nama, f"{prefix}{angka}"
