"""Endpoint komunitas seniman. Penjelasan aturan akses: services/komunitas_service.py."""

from __future__ import annotations

import io
import logging
import uuid
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from PIL import Image as PILImage, ImageOps
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.komunitas import Komunitas, KomunitasAnggota, KomunitasPost
from models.user import User
from routers.katalog import tandai_terjual, to_list_item
from schemas.katalog import KaryaListItem
from schemas.komunitas import (
    AnggotaList, KomentarBuat, KomentarList, KomentarOut, KomunitasBuat, KomunitasList, KomunitasOut, KomunitasUbah,
    LikeOut, PostBuat, PostList, PostOut,
)
from services import komunitas_service as svc
from services import storage
from services.auth_deps import butuh_role, get_current_user, get_user_opsional

logger = logging.getLogger("galeria.komunitas")
router = APIRouter(prefix="/api/komunitas", tags=["komunitas"])

_UPLOADS = Path(__file__).resolve().parent.parent / "uploads" / "komunitas"
_MAKS_BYTE = 10 * 1024 * 1024
_HALAMAN = 20


@router.post("", response_model=KomunitasOut, status_code=201)
async def buat(body: KomunitasBuat, user: User = Depends(butuh_role("seniman", "komunitas")), db: AsyncSession = Depends(get_db)):
    k = await svc.buat(db, user, body)
    return (await svc.ke_out_banyak(db, [k], user))[0]


@router.get("", response_model=KomunitasList)
async def daftar(
    saya: bool = Query(False, description="hanya komunitas yang kamu ikuti/miliki (butuh login)"),
    q: str | None = Query(None, max_length=60),
    page: int = Query(1, ge=1),
    page_size: int = Query(30, ge=1, le=100),
    user: User | None = Depends(get_user_opsional),
    db: AsyncSession = Depends(get_db),
):
    """Jelajahi komunitas. Komunitas tertutup tetap tampil di daftar (nama & deskripsi), isinya terkunci."""
    filt = Komunitas.id.is_not(None)
    if saya:
        if user is None:
            raise HTTPException(401, "Masuk dulu untuk melihat komunitasmu.")
        filt = filt & Komunitas.id.in_(select(KomunitasAnggota.komunitas_id).where(KomunitasAnggota.user_id == user.id))
    if q and q.strip():
        like = f"%{q.strip()}%"
        filt = filt & or_(Komunitas.nama.ilike(like), Komunitas.deskripsi.ilike(like))
    total = (await db.execute(select(func.count()).select_from(Komunitas).where(filt))).scalar_one()
    rows = (await db.execute(select(Komunitas).where(filt).order_by(Komunitas.created_at.desc()).offset((page - 1) * page_size).limit(page_size))).scalars().all()
    return KomunitasList(items=await svc.ke_out_banyak(db, list(rows), user), total=total)


@router.get("/{komunitas_id}", response_model=KomunitasOut)
async def detail(komunitas_id: str, user: User | None = Depends(get_user_opsional), db: AsyncSession = Depends(get_db)):
    k = await svc.muat(db, komunitas_id)
    return (await svc.ke_out_banyak(db, [k], user))[0]


@router.patch("/{komunitas_id}", response_model=KomunitasOut)
async def ubah(komunitas_id: str, body: KomunitasUbah, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    k = await svc.muat(db, komunitas_id, kunci=True)
    svc.pastikan_pemilik(k, user)
    if body.deskripsi is not None:
        k.deskripsi = body.deskripsi
    if body.aturan is not None:
        k.aturan = body.aturan
    if body.terbuka is not None:
        k.terbuka = body.terbuka
    await db.commit()
    return (await svc.ke_out_banyak(db, [k], user))[0]


@router.post("/{komunitas_id}/gabung", response_model=KomunitasOut)
async def gabung(komunitas_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Komunitas terbuka: langsung jadi anggota. Tertutup: menunggu persetujuan pemilik."""
    await svc.gabung(db, user, komunitas_id)
    return (await svc.ke_out_banyak(db, [await svc.muat(db, komunitas_id)], user))[0]


@router.post("/{komunitas_id}/keluar", response_model=KomunitasOut)
async def keluar(komunitas_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await svc.keluar(db, user, komunitas_id)
    return (await svc.ke_out_banyak(db, [await svc.muat(db, komunitas_id)], user))[0]


@router.get("/{komunitas_id}/anggota", response_model=AnggotaList)
async def anggota(komunitas_id: str, user: User | None = Depends(get_user_opsional), db: AsyncSession = Depends(get_db)):
    return await svc.daftar_anggota(db, await svc.muat(db, komunitas_id), user)


@router.post("/{komunitas_id}/anggota/{target_id}/setuju", status_code=204)
async def setujui(komunitas_id: str, target_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await svc.putuskan_permintaan(db, user, komunitas_id, target_id, True)


@router.post("/{komunitas_id}/anggota/{target_id}/tolak", status_code=204)
async def tolak(komunitas_id: str, target_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await svc.putuskan_permintaan(db, user, komunitas_id, target_id, False)


@router.delete("/{komunitas_id}/anggota/{target_id}", status_code=204)
async def keluarkan(komunitas_id: str, target_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await svc.keluarkan(db, user, komunitas_id, target_id)


@router.get("/{komunitas_id}/karya", response_model=list[KaryaListItem])
async def karya(komunitas_id: str, user: User | None = Depends(get_user_opsional), db: AsyncSession = Depends(get_db)):
    """Karya terverifikasi milik anggota komunitas."""
    k = await svc.muat(db, komunitas_id)
    await svc.pastikan_boleh_lihat(db, k, user)
    items = [to_list_item(x) for x in await svc.karya_anggota(db, k)]
    await tandai_terjual(db, items)
    return items


# ------------------------------------------------------------------ postingan
@router.get("/{komunitas_id}/post", response_model=PostList)
async def daftar_post(
    komunitas_id: str,
    sebelum: datetime | None = Query(None, description="ambil yang lebih lama dari waktu ini (halaman berikutnya)"),
    user: User | None = Depends(get_user_opsional),
    db: AsyncSession = Depends(get_db),
):
    k = await svc.muat(db, komunitas_id)
    await svc.pastikan_boleh_lihat(db, k, user)
    dasar = (KomunitasPost.komunitas_id == k.id) & KomunitasPost.deleted_at.is_(None)
    posts: list[KomunitasPost] = []
    if sebelum is None:
        posts += list((await db.execute(select(KomunitasPost).where(dasar, KomunitasPost.disematkan.is_(True)))).scalars())
    q = select(KomunitasPost).where(dasar, KomunitasPost.disematkan.is_(False))
    if sebelum is not None:
        q = q.where(KomunitasPost.created_at < sebelum)
    biasa = list((await db.execute(q.order_by(KomunitasPost.created_at.desc()).limit(_HALAMAN + 1))).scalars())
    ada_lagi = len(biasa) > _HALAMAN
    return PostList(items=await svc.post_out_banyak(db, posts + biasa[:_HALAMAN], k, user), ada_lagi=ada_lagi)


@router.post("/{komunitas_id}/post", response_model=PostOut, status_code=201)
async def tulis_post(komunitas_id: str, body: PostBuat, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p, k = await svc.buat_post(db, user, komunitas_id, body.teks)
    return (await svc.post_out_banyak(db, [p], k, user))[0]


@router.post("/{komunitas_id}/post-foto", response_model=PostOut, status_code=201)
async def tulis_post_foto(
    komunitas_id: str,
    teks: str = Query(..., min_length=1, max_length=1000),
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Postingan dengan satu foto (JPEG diproses ulang, sisi terpanjang maksimal 1600 px)."""
    teks = PostBuat(teks=teks).teks
    k = await svc.muat(db, komunitas_id)
    await svc.pastikan_anggota(db, k, user)
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(400, "File harus berupa gambar")
    raw = await file.read()
    if not raw:
        raise HTTPException(400, "File gambar kosong")
    if len(raw) > _MAKS_BYTE:
        raise HTTPException(413, "Gambar terlalu besar (maksimal 10 MB)")
    try:
        img = ImageOps.exif_transpose(PILImage.open(io.BytesIO(raw))).convert("RGB")
        img.thumbnail((1600, 1600))
    except Exception:
        raise HTTPException(400, "Gagal membaca gambar (file korup/format tidak didukung)")
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=88)
    nama = f"{uuid.uuid4()}.jpg"
    if storage.terkonfigurasi():
        key = f"komunitas/{nama}"
        try:
            await storage.unggah(key, buf.getvalue(), "image/jpeg")
        except Exception:
            logger.exception("Unggah foto postingan ke R2 gagal")
            raise HTTPException(502, "Gagal menyimpan gambar. Coba lagi sebentar.")
    else:
        _UPLOADS.mkdir(parents=True, exist_ok=True)
        (_UPLOADS / nama).write_bytes(buf.getvalue())
        key = f"uploads/komunitas/{nama}"
    try:
        p, k = await svc.buat_post(db, user, komunitas_id, teks, image_key=key)
    except Exception:
        if key.startswith("komunitas/"):
            try:
                await storage.hapus(key)
            except Exception:
                logger.warning("Gagal membersihkan objek %s", key)
        raise
    return (await svc.post_out_banyak(db, [p], k, user))[0]


@router.delete("/post/{post_id}", status_code=204)
async def hapus_post(post_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    key = await svc.hapus_post(db, user, post_id)
    if key and key.startswith("komunitas/"):
        try:
            await storage.hapus(key)
        except Exception:
            logger.warning("Gagal menghapus objek %s", key)


@router.post("/post/{post_id}/sematkan", response_model=PostOut)
async def sematkan(post_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = await svc.sematkan(db, user, post_id)
    k = await svc.muat(db, str(p.komunitas_id))
    return (await svc.post_out_banyak(db, [p], k, user))[0]


@router.post("/post/{post_id}/like", response_model=LikeOut)
async def like(post_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    saya, n = await svc.toggle_like(db, user, post_id)
    return LikeOut(saya_like=saya, jumlah_like=n)


@router.get("/post/{post_id}/komentar", response_model=KomentarList)
async def daftar_komentar(post_id: str, user: User | None = Depends(get_user_opsional), db: AsyncSession = Depends(get_db)):
    return KomentarList(items=await svc.daftar_komentar(db, user, post_id))


@router.post("/post/{post_id}/komentar", response_model=KomentarOut, status_code=201)
async def tulis_komentar(post_id: str, body: KomentarBuat, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await svc.buat_komentar(db, user, post_id, body.teks)


@router.delete("/komentar/{komentar_id}", status_code=204)
async def hapus_komentar(komentar_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await svc.hapus_komentar(db, user, komentar_id)
