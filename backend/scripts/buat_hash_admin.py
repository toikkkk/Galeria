"""Buat nilai ADMIN_PASSWORD_HASH (bcrypt, cost 12) + ADMIN_JWT_SECRET acak untuk backend/.env.

    python scripts/buat_hash_admin.py
"""
import getpass
import secrets

import bcrypt

pw = getpass.getpass("Password admin (min. 10 karakter): ")
if len(pw) < 10 or pw != getpass.getpass("Ulangi password: "):
    raise SystemExit("Password terlalu pendek atau tidak sama.")
print("\nTempel ke backend/.env (hash mengandung '$' -- biarkan apa adanya, jangan diberi kutip ganda):\n")
print("ADMIN_EMAIL=admin@galeria.id")
print("ADMIN_PASSWORD_HASH=" + bcrypt.hashpw(pw.encode()[:72], bcrypt.gensalt(12)).decode())
print("ADMIN_JWT_SECRET=" + secrets.token_urlsafe(48))
