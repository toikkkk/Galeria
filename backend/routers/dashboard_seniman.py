"""Endpoint dashboard seniman (statistik deskriptif data dummy rekomendasi).

Hanya membaca; bukan prediksi/saran harga (fitur Estimasi Harga di-drop).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from schemas.dashboard import (
    AliranSeniman,
    NotifikasiSeniman,
    PenjualanBulan,
    RiwayatPenarikan,
    RingkasanSeniman,
    SegmenPembeliResponse,
    SenimanDemoItem,
    TrenPasar,
)
from models.user import User
from schemas.sentimen import SentimenSeniman
from services import dashboard_nyata as nyata
from services import dashboard_repo as repo
from services.auth_deps import butuh_role

router = APIRouter(prefix="/api/dashboard", tags=["dashboard-seniman"])


async def _seniman_atau_404(db: AsyncSession, seniman_id: str):
    sid = repo.parse_uuid(seniman_id)
    seniman = await repo.get_seniman(db, sid) if sid else None
    if seniman is None:
        raise HTTPException(404, "Seniman tidak ditemukan")
    return sid, seniman


@router.get("/demo-seniman", response_model=list[SenimanDemoItem])
async def demo_seniman(db: AsyncSession = Depends(get_db)):
    """Seniman contoh (pengganti login sampai Auth selesai), terbanyak terjual dulu."""
    return await repo.daftar_seniman_demo(db)


@router.get("/seniman/{seniman_id}/ringkasan", response_model=RingkasanSeniman)
async def ringkasan(
    seniman_id: str,
    periode: int = Query(30, description="30, 90, atau 365 hari"),
    db: AsyncSession = Depends(get_db),
):
    if periode not in (30, 90, 365):
        raise HTTPException(422, "periode harus 30, 90, atau 365")
    sid, seniman = await _seniman_atau_404(db, seniman_id)
    return await repo.ringkasan(db, seniman, sid, periode)


@router.get("/seniman/{seniman_id}/penjualan-bulanan", response_model=list[PenjualanBulan])
async def penjualan_bulanan(
    seniman_id: str,
    bulan: int = Query(12, ge=1, le=36),
    db: AsyncSession = Depends(get_db),
):
    sid, _ = await _seniman_atau_404(db, seniman_id)
    return await repo.penjualan_bulanan(db, sid, bulan)


@router.get("/seniman/{seniman_id}/aliran", response_model=list[AliranSeniman])
async def aliran(seniman_id: str, db: AsyncSession = Depends(get_db)):
    sid, _ = await _seniman_atau_404(db, seniman_id)
    return await repo.aliran(db, sid)


@router.get("/seniman/{seniman_id}/segmen-pembeli", response_model=SegmenPembeliResponse)
async def segmen_pembeli(seniman_id: str, db: AsyncSession = Depends(get_db)):
    sid, _ = await _seniman_atau_404(db, seniman_id)
    return await repo.segmen_pembeli(db, sid)


@router.get("/pasar/tren", response_model=TrenPasar)
async def tren_pasar(db: AsyncSession = Depends(get_db)):
    return await repo.tren_pasar(db)


@router.get("/seniman/{seniman_id}/penarikan", response_model=RiwayatPenarikan)
async def penarikan(seniman_id: str, db: AsyncSession = Depends(get_db)):
    """Riwayat tarik dana (turunan dari pendapatan bersih bulanan, data contoh)."""
    sid, _ = await _seniman_atau_404(db, seniman_id)
    return await repo.riwayat_penarikan(db, sid)


@router.get("/seniman/{seniman_id}/notifikasi", response_model=list[NotifikasiSeniman])
async def notifikasi(seniman_id: str, db: AsyncSession = Depends(get_db)):
    """Notifikasi: pembelian kolektor, hasil lelang, tindakan (data contoh)."""
    sid, _ = await _seniman_atau_404(db, seniman_id)
    return await repo.notifikasi_seniman(db, sid)


# ---------------------------------------------------------------------------
# Dashboard seniman yang login: data NYATA dari transaksi/karya/ulasan (bukan data contoh).
# `/saya/...` selalu merujuk ke akun pemanggil, jadi tidak ada id yang bisa diutak-atik.
# ---------------------------------------------------------------------------
_seniman = butuh_role("seniman")


@router.get("/saya/ringkasan", response_model=RingkasanSeniman)
async def saya_ringkasan(
    periode: int = Query(30, description="30, 90, atau 365 hari"),
    user: User = Depends(_seniman),
    db: AsyncSession = Depends(get_db),
):
    if periode not in (30, 90, 365):
        raise HTTPException(422, "periode harus 30, 90, atau 365")
    return await nyata.ringkasan(db, user, periode)


@router.get("/saya/penjualan-bulanan", response_model=list[PenjualanBulan])
async def saya_penjualan_bulanan(
    bulan: int = Query(12, ge=1, le=36), user: User = Depends(_seniman), db: AsyncSession = Depends(get_db)
):
    return await nyata.penjualan_bulanan(db, user, bulan)


@router.get("/saya/aliran", response_model=list[AliranSeniman])
async def saya_aliran(user: User = Depends(_seniman), db: AsyncSession = Depends(get_db)):
    return await nyata.aliran(db, user)


@router.get("/saya/segmen-pembeli", response_model=SegmenPembeliResponse)
async def saya_segmen_pembeli(user: User = Depends(_seniman)):
    """Segmentasi pembeli butuh riwayat pembelian banyak kolektor; belum tersedia untuk data nyata."""
    return SegmenPembeliResponse(tersedia=False, items=[])


@router.get("/saya/penarikan", response_model=RiwayatPenarikan)
async def saya_penarikan(user: User = Depends(_seniman)):
    """Fitur tarik dana belum ada, jadi riwayatnya kosong (bukan angka karangan)."""
    return RiwayatPenarikan(total_ditarik_idr=0, items=[])


@router.get("/saya/notifikasi", response_model=list[NotifikasiSeniman])
async def saya_notifikasi(user: User = Depends(_seniman), db: AsyncSession = Depends(get_db)):
    return await nyata.notifikasi(db, user)


@router.get("/saya/sentimen", response_model=SentimenSeniman)
async def saya_sentimen(user: User = Depends(_seniman), db: AsyncSession = Depends(get_db)):
    return await nyata.sentimen(db, user)
