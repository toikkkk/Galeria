"""Dependency FastAPI untuk melindungi endpoint dengan login pengguna.

    @router.get("/saya")
    async def saya(user: User = Depends(get_current_user)): ...

    @router.post("/karya", dependencies=[Depends(butuh_role("seniman"))])
"""

from __future__ import annotations

import uuid

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.user import User
from services import auth_service

_bearer = HTTPBearer(auto_error=False)


def _tolak(pesan: str = "Belum masuk atau sesi berakhir.") -> HTTPException:
    return HTTPException(401, pesan, headers={"WWW-Authenticate": "Bearer"})


async def get_current_user(
    cred: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    if cred is None:
        raise _tolak()
    if not auth_service.terkonfigurasi():
        raise HTTPException(503, "Auth belum dikonfigurasi di server (JWT_SECRET).")
    payload = auth_service.baca_access_token(cred.credentials)
    if payload is None:
        raise _tolak()
    try:
        uid = uuid.UUID(payload["sub"])
    except (ValueError, KeyError):
        raise _tolak()
    user = await db.get(User, uid)
    if user is None or not user.is_active:  # akun dinonaktifkan/di-ban langsung berlaku, tak menunggu token habis
        raise _tolak()
    return user


def butuh_role(*role: str):
    """Dependency pembatas peran: ``Depends(butuh_role("seniman", "komunitas"))``."""

    async def _cek(user: User = Depends(get_current_user)) -> User:
        if user.role.value not in role:
            raise HTTPException(403, "Peran akunmu tidak boleh mengakses ini.")
        return user

    return _cek
