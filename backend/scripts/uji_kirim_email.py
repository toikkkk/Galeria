"""Uji pengiriman email (SMTP) dari laptop, tanpa lewat aplikasi.

    cd backend
    .\\.venv\\Scripts\\python.exe -m scripts.uji_kirim_email alamat@email.kamu

Membaca SMTP_* dari ``backend/.env`` lalu mengirim satu email contoh berisi kode 123456 (bukan kode sungguhan).
Menampilkan penyebab bila gagal (password salah, verifikasi 2 langkah belum aktif, jaringan memblokir port 587, dll.).
"""

from __future__ import annotations

import asyncio
import sys

from dotenv import load_dotenv

load_dotenv()

from services import email_service  # noqa: E402  (setelah load_dotenv agar SMTP_* terbaca)


def _saran(pesan: str) -> str:
    p = pesan.lower()
    if "535" in p or "authentication" in p or "username and password" in p:
        return ("Login SMTP ditolak. Pastikan: (1) SMTP_PASSWORD berisi APP PASSWORD 16 karakter, bukan password Gmail biasa; "
                "(2) Verifikasi 2 Langkah di akun Google sudah aktif; (3) SMTP_USER = alamat Gmail yang membuat App Password itu.")
    if "timed out" in p or "timeout" in p or "unreachable" in p or "getaddrinfo" in p or "refused" in p:
        return ("Tidak bisa menjangkau smtp.gmail.com:587. Cek koneksi internet; sebagian WiFi kampus/kantor memblokir port 587 "
                "-- coba data seluler, atau isi SMTP_PORT=465.")
    return "Periksa kembali isi SMTP_* di backend/.env."


async def main() -> int:
    if len(sys.argv) != 2 or "@" not in sys.argv[1]:
        print("Pemakaian: python -m scripts.uji_kirim_email alamat@email.kamu")
        return 2
    tujuan = sys.argv[1].strip()
    if not email_service.terkonfigurasi():
        print("SMTP_USER / SMTP_PASSWORD di backend/.env masih kosong -> MODE UJI (email tidak akan terkirim).")
        print("Isi keduanya dulu (lihat backend/.env.example), lalu jalankan lagi.")
        return 1
    print(f"Mengirim email uji ke {tujuan} lewat {email_service._env('SMTP_HOST', 'smtp.gmail.com')}:{email_service._env('SMTP_PORT', '587')} ...")
    try:
        await email_service.kirim(
            tujuan, "Uji email GALERIA",
            "Ini email uji dari backend GALERIA.\n\nKode: 123456\n\nJika email ini sampai, pengiriman SMTP sudah berfungsi.\n",
            email_service._html("Penguji", "123456", "Ini email uji. Pengiriman SMTP GALERIA berfungsi."),
        )
    except email_service.EmailGagal as exc:
        print(f"\nGAGAL: {exc}\n-> {_saran(str(exc))}")
        return 1
    print("\nBERHASIL. Cek kotak masuk (dan folder spam) di", tujuan)
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
