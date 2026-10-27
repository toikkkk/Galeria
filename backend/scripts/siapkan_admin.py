"""Isi ADMIN_EMAIL / ADMIN_PASSWORD_HASH / ADMIN_JWT_SECRET di backend/.env BILA belum terisi.

Idempotent: kalau sudah terisi, tidak diubah. Dipanggil oleh dashboard-admin/mulai.ps1.

    python scripts/siapkan_admin.py [--env PATH] [--password PW]
"""
import argparse
import re
import secrets
from pathlib import Path

import bcrypt

ap = argparse.ArgumentParser()
ap.add_argument("--env", default=str(Path(__file__).resolve().parents[1] / ".env"))
ap.add_argument("--password", default="")
a = ap.parse_args()

path = Path(a.env)
teks = path.read_text(encoding="utf-8") if path.exists() else ""


def terisi(kunci: str) -> bool:
    return re.search(rf"(?m)^{kunci}=\S+", teks) is not None


def set_kunci(kunci: str, nilai: str) -> None:
    global teks
    if re.search(rf"(?m)^{kunci}=.*$", teks):
        teks = re.sub(rf"(?m)^{kunci}=.*$", lambda _: f"{kunci}={nilai}", teks)
    else:
        teks = teks.rstrip("\n") + f"\n{kunci}={nilai}\n"


if not terisi("ADMIN_EMAIL"):
    set_kunci("ADMIN_EMAIL", "admin@galeria.id")
if not terisi("ADMIN_JWT_SECRET"):
    set_kunci("ADMIN_JWT_SECRET", secrets.token_urlsafe(48))
if terisi("ADMIN_PASSWORD_HASH"):
    print("Akun admin sudah ada di .env (tidak diubah).")
else:
    pw = a.password or secrets.token_urlsafe(9)
    set_kunci("ADMIN_PASSWORD_HASH", bcrypt.hashpw(pw.encode()[:72], bcrypt.gensalt(12)).decode())
    print(f"AKUN ADMIN DIBUAT -> email: admin@galeria.id | password: {pw}")
path.write_text(teks, encoding="utf-8")
