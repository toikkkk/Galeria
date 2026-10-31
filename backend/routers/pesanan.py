"""Endpoint pesanan (checkout) untuk kolektor dan seniman. Penjelasan siklus hidup: services/pesanan_service.py."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.transaksi import StatusTransaksi as S
from models.transaksi import Transaksi
from models.user import User
from schemas.pesanan import BayarReq, KirimReq, PesananBuat, PesananList, PesananOut
from services import pembayaran, pesanan_service as svc
from services.auth_deps import butuh_role, get_current_user

router = APIRouter(prefix="/api", tags=["pesanan"])


@router.post("/pesanan", response_model=PesananOut, status_code=201)
async def buat(
    body: PesananBuat,
    user: User = Depends(butuh_role("kolektor", "komunitas")),
    db: AsyncSession = Depends(get_db),
):
    """Kolektor memesan satu karya. Harga & komisi ditentukan SERVER dari harga karya, bukan dari klien."""
    t = await svc.buat_pesanan(db, user, body.karya_id, body.alamat_id)
    return await svc.muat_out(db, t, user.id)


@router.get("/pesanan", response_model=PesananList)
async def pesanan_saya(
    peran: str = Query("pembeli", pattern="^(pembeli|penjual)$"),
    status: str | None = Query(None, description="filter satu status"),
    page: int = Query(1, ge=1),
    page_size: int = Query(30, ge=1, le=100),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Pesananmu. ``peran=pembeli`` (default) untuk kolektor, ``peran=penjual`` untuk seniman."""
    if peran == "penjual" and user.role.value != "seniman":
        raise HTTPException(403, "Hanya seniman yang punya pesanan masuk.")
    await svc.kedaluwarsakan(db)
    kolom = Transaksi.penjual_id if peran == "penjual" else Transaksi.pembeli_id
    filt = kolom == user.id
    if status:
        try:
            filt = filt & (Transaksi.status == S(status))
        except ValueError:
            raise HTTPException(422, "status tidak dikenal")
    total = (await db.execute(select(func.count()).select_from(Transaksi).where(filt))).scalar_one()
    rows = (
        await db.execute(
            select(Transaksi).where(filt).order_by(Transaksi.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        )
    ).scalars().all()
    return PesananList(items=[await svc.muat_out(db, t, user.id) for t in rows], total=total)


@router.get("/pesanan/{pesanan_id}", response_model=PesananOut)
async def detail(pesanan_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    t = await svc.kunci(db, pesanan_id)
    if user.id not in (t.pembeli_id, t.penjual_id):
        raise HTTPException(404, "Pesanan tidak ditemukan")
    return await svc.muat_out(db, t, user.id)


@router.post("/pesanan/{pesanan_id}/bayar", response_model=PesananOut)
async def pilih_pembayaran(
    pesanan_id: str,
    body: BayarReq,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Pilih metode pembayaran dan dapatkan instruksinya (nomor VA / kode QRIS). Boleh diganti selama belum dibayar."""
    t = await svc.kunci(db, pesanan_id)
    svc.pastikan_pihak(t, user, sebagai="pembeli")
    svc.pastikan_status(t, S.MENUNGGU_PEMBAYARAN, pesan="Pesanan ini tidak lagi menunggu pembayaran.")
    try:
        await svc.pilih_metode(db, t, body.metode)
    except pembayaran.PembayaranTidakTersedia as exc:
        raise HTTPException(501, str(exc))
    return await svc.muat_out(db, t, user.id)


@router.post("/pesanan/{pesanan_id}/bayar/simulasi", response_model=PesananOut)
async def simulasi_bayar(pesanan_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """SANDBOX: anggap pembayaran sudah masuk (seperti simulator gateway). Dimatikan bila bukan mode sandbox."""
    if not pembayaran.simulasi_diizinkan():
        raise HTTPException(404, "Tidak tersedia.")
    t = await svc.kunci(db, pesanan_id)
    svc.pastikan_pihak(t, user, sebagai="pembeli")
    svc.pastikan_status(t, S.MENUNGGU_PEMBAYARAN, pesan="Pesanan ini tidak lagi menunggu pembayaran.")
    if not t.metode_pembayaran:
        raise HTTPException(409, "Pilih metode pembayaran dulu.")
    await svc.tandai_dibayar(db, t)
    return await svc.muat_out(db, t, user.id)


@router.post("/pesanan/{pesanan_id}/batal", response_model=PesananOut)
async def batal(pesanan_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    t = await svc.kunci(db, pesanan_id)
    svc.pastikan_pihak(t, user, sebagai="pembeli")
    svc.pastikan_status(t, S.MENUNGGU_PEMBAYARAN, pesan="Pesanan yang sudah dibayar tidak bisa dibatalkan sendiri.")
    await svc.batalkan(db, t)
    return await svc.muat_out(db, t, user.id)


@router.post("/pesanan/{pesanan_id}/konfirmasi", response_model=PesananOut)
async def konfirmasi(
    pesanan_id: str, user: User = Depends(butuh_role("seniman")), db: AsyncSession = Depends(get_db)
):
    t = await svc.kunci(db, pesanan_id)
    svc.pastikan_pihak(t, user, sebagai="penjual")
    svc.pastikan_status(t, S.DIBAYAR, pesan="Hanya pesanan yang sudah dibayar yang bisa dikonfirmasi.")
    await svc.konfirmasi(db, t)
    return await svc.muat_out(db, t, user.id)


@router.post("/pesanan/{pesanan_id}/kirim", response_model=PesananOut)
async def kirim(
    pesanan_id: str, body: KirimReq, user: User = Depends(butuh_role("seniman")), db: AsyncSession = Depends(get_db)
):
    t = await svc.kunci(db, pesanan_id)
    svc.pastikan_pihak(t, user, sebagai="penjual")
    svc.pastikan_status(t, S.DIKONFIRMASI, pesan="Konfirmasi pesanan dulu sebelum mengirim.")
    if t.dikirim_at is not None:
        raise HTTPException(409, "Pesanan ini sudah ditandai dikirim.")
    await svc.kirim(db, t, body.kurir, body.no_resi)
    return await svc.muat_out(db, t, user.id)


@router.post("/pesanan/{pesanan_id}/terima", response_model=PesananOut)
async def terima(pesanan_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Pembeli mengonfirmasi karya sudah diterima: pesanan selesai dan kepemilikan berpindah ke pembeli."""
    t = await svc.kunci(db, pesanan_id)
    svc.pastikan_pihak(t, user, sebagai="pembeli")
    svc.pastikan_status(t, S.DIKONFIRMASI, pesan="Pesanan ini belum bisa diselesaikan.")
    if t.dikirim_at is None:
        raise HTTPException(409, "Karya belum dikirim oleh seniman.")
    await svc.terima(db, t)
    return await svc.muat_out(db, t, user.id)
