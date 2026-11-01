"""Ulasan pembeli yang nyata: ditulis SETELAH pesanan selesai (karya sudah diterima), sekali per pesanan.

Berbeda dari ``routers/ulasan.py`` (data contoh tanpa login). Sentimen langsung dihitung di request ini oleh model
ringan TF-IDF+LogReg (``services/sentimen_ringan.py``). Bila bobotnya tidak ada, ``sentimen_prediksi`` tetap NULL
(= menunggu) dan bisa diisi batch oleh ``ml-sentiment/scripts/analisis_ulasan_baru.py`` (IndoBERT) atau
``backend/scripts/analisis_ulasan_tertunda.py``.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.karya import Karya, StatusVerifikasiKarya
from models.transaksi import StatusTransaksi as S
from models.transaksi import Transaksi
from models.ulasan import Ulasan
from models.user import User
from schemas.ulasan_nyata import UlasanKaryaItem, UlasanKaryaOut, UlasanOut, UlasanPesananIn
from services.auth_deps import get_current_user
from services import notifikasi_service as notif
from services import sentimen_ringan
from models.engagement import TipeNotifikasi

router = APIRouter(prefix="/api", tags=["ulasan"])


def _nama_singkat(nama: str) -> str:
    """"Budi Santoso" -> "Budi S." (nama lengkap pembeli tidak ditampilkan ke publik)."""
    kata = nama.split()
    if len(kata) <= 1:
        return nama
    return f"{kata[0]} {kata[-1][0].upper()}."


@router.post("/pesanan/{pesanan_id}/ulasan", response_model=UlasanOut, status_code=201)
async def tulis_ulasan(
    pesanan_id: str,
    body: UlasanPesananIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Pembeli menilai karya yang SUDAH diterimanya. Satu ulasan per pesanan."""
    try:
        tid = uuid.UUID(pesanan_id)
    except ValueError:
        raise HTTPException(404, "Pesanan tidak ditemukan")
    t = await db.get(Transaksi, tid)
    if t is None or t.pembeli_id != user.id:
        raise HTTPException(404, "Pesanan tidak ditemukan")
    if t.status != S.SELESAI:
        raise HTTPException(409, "Kamu bisa menulis ulasan setelah karya diterima dan pesanan selesai.")
    u = Ulasan(
        id=uuid.uuid4(), transaksi_id=t.id, karya_id=t.karya_id, pembeli_id=user.id, seniman_id=t.penjual_id,
        rating=body.rating, teks=body.teks,
    )
    hasil = sentimen_ringan.prediksi(body.teks)  # None bila bobot model tidak ada -> tetap 'menunggu analisis'
    if hasil is not None:
        u.sentimen_prediksi, u.model_version, u.dihitung_pada = hasil["label"], hasil["model_version"], datetime.now(timezone.utc)
        u.prob_negatif, u.prob_netral, u.prob_positif = (hasil["prob"][k] for k in ("negatif", "netral", "positif"))
    db.add(u)
    notif.kirim(db, t.penjual_id, TipeNotifikasi.TRANSAKSI, f"Ulasan baru ({body.rating}/5)", body.teks[:120], f"karya:{t.karya_id}")
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(409, "Kamu sudah mengulas pesanan ini.")
    return UlasanOut(id=str(u.id), karya_id=str(u.karya_id), rating=u.rating,
                     status="menunggu_analisis" if u.sentimen_prediksi is None else "dianalisis")


@router.get("/karya/{karya_id}/ulasan", response_model=UlasanKaryaOut)
async def ulasan_karya(
    karya_id: str,
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """Ulasan publik sebuah karya terverifikasi: rata-rata, sebaran bintang, dan daftar ulasan terbaru."""
    try:
        kid = uuid.UUID(karya_id)
    except ValueError:
        raise HTTPException(404, "Karya tidak ditemukan")
    karya = await db.get(Karya, kid)
    if karya is None or karya.deleted_at is not None or karya.status_verifikasi != StatusVerifikasiKarya.TERVERIFIKASI:
        raise HTTPException(404, "Karya tidak ditemukan")

    agregat = (
        await db.execute(select(Ulasan.rating, func.count()).where(Ulasan.karya_id == kid).group_by(Ulasan.rating))
    ).all()
    sebaran = {str(i): 0 for i in range(1, 6)}
    for rating, n in agregat:
        sebaran[str(rating)] = int(n)
    jumlah = sum(sebaran.values())
    rata2 = round(sum(int(r) * n for r, n in sebaran.items()) / jumlah, 2) if jumlah else None

    rows = (
        await db.execute(
            select(Ulasan, User.display_name)
            .join(User, User.id == Ulasan.pembeli_id)
            .where(Ulasan.karya_id == kid)
            .order_by(Ulasan.created_at.desc())
            .limit(limit)
        )
    ).all()
    return UlasanKaryaOut(
        jumlah=jumlah,
        rata2=rata2,
        sebaran=sebaran,
        items=[
            UlasanKaryaItem(
                nama=_nama_singkat(nama), rating=u.rating, teks=u.teks,
                tanggal=u.created_at.isoformat(), sentimen=u.sentimen_prediksi,
            )
            for u, nama in rows
        ],
    )
