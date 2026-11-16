"""Pengiriman email lewat SMTP (mis. Gmail + App Password). Murni library standar, tanpa dependensi baru.

Konfigurasi (``backend/.env``):
    SMTP_USER        alamat pengirim, mis. galeria.app@gmail.com
    SMTP_PASSWORD    untuk Gmail: App Password 16 karakter (BUKAN password akun). Spasi diabaikan.
    SMTP_HOST        default smtp.gmail.com
    SMTP_PORT        default 587 (STARTTLS); 465 = SSL langsung
    SMTP_FROM        default = SMTP_USER
    SMTP_FROM_NAME   default GALERIA

Pola sama dengan ``database.py`` / ``storage.py``: bila ``SMTP_USER``/``SMTP_PASSWORD`` kosong, aplikasi tetap bisa jalan.
Email TIDAK dikirim (MODE UJI): isinya -- termasuk kode -- dicetak di terminal backend, supaya alur bisa dicoba di laptop
tanpa akun email. Jangan dibiarkan begitu di server sungguhan: pengguna lain tidak akan menerima apa pun.
"""

from __future__ import annotations

import asyncio
import logging
import os
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr
from html import escape

log = logging.getLogger("galeria.email")

TTL_MENIT = 15


class EmailGagal(Exception):
    """Email tidak terkirim (kredensial salah, SMTP tidak terjangkau, dll.). Pesan aman untuk log, bukan untuk pengguna."""


def _env(k: str, default: str = "") -> str:
    return os.environ.get(k, default).strip()


def terkonfigurasi() -> bool:
    return bool(_env("SMTP_USER") and _env("SMTP_PASSWORD"))


def _kirim_sinkron(ke: str, subjek: str, teks: str, html: str) -> None:
    host, port = _env("SMTP_HOST", "smtp.gmail.com"), int(_env("SMTP_PORT", "587") or "587")
    user, sandi = _env("SMTP_USER"), _env("SMTP_PASSWORD").replace(" ", "")
    pengirim = _env("SMTP_FROM") or user
    pesan = EmailMessage()
    pesan["Subject"] = subjek
    pesan["From"] = formataddr((_env("SMTP_FROM_NAME", "GALERIA"), pengirim))
    pesan["To"] = ke
    pesan.set_content(teks)
    pesan.add_alternative(html, subtype="html")
    konteks = ssl.create_default_context()
    try:
        if port == 465:
            with smtplib.SMTP_SSL(host, port, timeout=20, context=konteks) as s:
                s.login(user, sandi)
                s.send_message(pesan)
        else:
            with smtplib.SMTP(host, port, timeout=20) as s:
                s.starttls(context=konteks)
                s.login(user, sandi)
                s.send_message(pesan)
    except (smtplib.SMTPException, OSError) as exc:
        raise EmailGagal(f"{type(exc).__name__}: {exc}") from exc


async def kirim(ke: str, subjek: str, teks: str, html: str) -> bool:
    """True = terkirim sungguhan; False = mode uji (dicetak di terminal). Melempar ``EmailGagal`` bila SMTP gagal."""
    if not terkonfigurasi():
        print(f"\n[EMAIL MODE UJI -- tidak dikirim] ke={ke}\n  subjek: {subjek}\n  {teks}\n", flush=True)
        return False
    await asyncio.to_thread(_kirim_sinkron, ke, subjek, teks, html)
    return True


_JUDUL = {
    "reset_password": ("Kode reset password GALERIA", "Gunakan kode ini untuk membuat password baru."),
    "verifikasi_email": ("Kode verifikasi email GALERIA", "Gunakan kode ini untuk memverifikasi email akunmu."),
}


def _html(nama: str, kode: str, kalimat: str) -> str:
    n = escape(nama)
    return f"""<!doctype html><html><body style="margin:0;background:#f3efe9;font-family:Segoe UI,Arial,sans-serif;color:#3e251e">
<div style="max-width:440px;margin:0 auto;padding:28px 18px">
  <div style="text-align:center;letter-spacing:.35em;font:700 22px Georgia,serif;margin-bottom:18px">GALERIA</div>
  <div style="background:#fff;border-radius:16px;padding:26px 22px;border-top:4px solid #dba12c">
    <p style="margin:0 0 6px;font-size:15px">Halo {n},</p>
    <p style="margin:0 0 18px;font-size:14px;color:#5f4b44">{escape(kalimat)}</p>
    <div style="text-align:center;font:800 34px/1 Consolas,monospace;letter-spacing:.3em;background:#f7e7c1;color:#3e251e;border-radius:12px;padding:16px 0">{kode}</div>
    <p style="margin:18px 0 0;font-size:12.5px;color:#7a6a63">Kode berlaku {TTL_MENIT} menit dan hanya bisa dipakai sekali.
    Jangan bagikan kode ini ke siapa pun, termasuk yang mengaku dari GALERIA. Bila bukan kamu yang meminta, abaikan email ini.</p>
  </div>
</div></body></html>"""


async def kirim_kode(ke: str, nama: str, kode: str, tujuan: str) -> None:
    """Kirim kode ``tujuan`` ke ``ke``. Kegagalan hanya dicatat di log (dipanggil dari background task)."""
    subjek, kalimat = _JUDUL[tujuan]
    teks = f"Halo {nama},\n\n{kalimat}\n\nKode: {kode}\n\nBerlaku {TTL_MENIT} menit, sekali pakai. Jangan bagikan ke siapa pun.\n"
    try:
        await kirim(ke, subjek, teks, _html(nama, kode, kalimat))
    except EmailGagal as exc:
        log.error("Gagal mengirim email %s ke %s: %s", tujuan, ke, exc)
