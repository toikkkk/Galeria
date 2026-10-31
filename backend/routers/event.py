"""Endpoint event & tiket. Penjelasan aturan: services/event_service.py."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.event import Event, EventPesanan, EventTiket, EventTiketPembelian, StatusEvent as SE
from models.user import User
from schemas.event import (
    BayarTiketIn, CheckinIn, CheckinOut, ETiket, EventBuat, EventList, EventOut, PesanTiketIn, PesananTiketOut,
    PesertaList, TiketSayaItem, TiketSayaList,
)
from services import event_service as svc
from services import langganan_service
from services import pembayaran
from services.auth_deps import butuh_role, get_current_user, get_user_opsional
from fastapi import HTTPException

router = APIRouter(prefix="/api", tags=["event"])

_penyelenggara = butuh_role("seniman", "komunitas")


@router.post("/event", response_model=EventOut, status_code=201)
async def buat_event(body: EventBuat, user: User = Depends(_penyelenggara), db: AsyncSession = Depends(get_db)):
    await langganan_service.pastikan_pro(db, user)  # penegakan di server, bukan hanya di aplikasi
    e = await svc.buat(db, user, body)
    return (await svc.ke_out_banyak(db, [e], user))[0]


@router.get("/event", response_model=EventList)
async def daftar_event(
    waktu: str = Query("mendatang", pattern="^(mendatang|selesai|semua)$"),
    q: str | None = Query(None, max_length=80),
    komunitas_id: str | None = Query(None, description="hanya event atas nama komunitas ini"),
    page: int = Query(1, ge=1),
    page_size: int = Query(30, ge=1, le=100),
    user: User | None = Depends(get_user_opsional),
    db: AsyncSession = Depends(get_db),
):
    """Event yang dipublikasikan. ``waktu=mendatang`` (default) = belum berakhir, yang paling dekat dulu."""
    filt = Event.status == SE.DIPUBLIKASIKAN
    if waktu == "mendatang":
        filt = filt & (Event.selesai_at > func.now())
    elif waktu == "selesai":
        filt = filt & (Event.selesai_at <= func.now())
    if q and q.strip():
        like = f"%{q.strip()}%"
        filt = filt & (Event.judul.ilike(like) | Event.kota.ilike(like) | Event.tema.ilike(like))
    if komunitas_id:
        try:
            filt = filt & (Event.komunitas_ref_id == uuid.UUID(komunitas_id))
        except ValueError:
            raise HTTPException(404, "Komunitas tidak ditemukan")
    total = (await db.execute(select(func.count()).select_from(Event).where(filt))).scalar_one()
    urut = Event.mulai_at.desc() if waktu == "selesai" else Event.mulai_at.asc()
    rows = (await db.execute(select(Event).where(filt).order_by(urut).offset((page - 1) * page_size).limit(page_size))).scalars().all()
    await svc.kedaluwarsakan(db)
    return EventList(items=await svc.ke_out_banyak(db, list(rows), user), total=total)


@router.get("/event/saya", response_model=EventList)
async def event_saya(user: User = Depends(_penyelenggara), db: AsyncSession = Depends(get_db)):
    """Semua event yang kamu selenggarakan (termasuk yang dibatalkan), dengan statistik penjualan."""
    await svc.kedaluwarsakan(db)
    rows = (await db.execute(select(Event).where(Event.komunitas_id == user.id, Event.status != SE.DRAFT).order_by(Event.mulai_at.desc()).limit(100))).scalars().all()
    return EventList(items=await svc.ke_out_banyak(db, list(rows), user), total=len(rows))


@router.post("/event/checkin", response_model=CheckinOut)
async def checkin(body: CheckinIn, user: User = Depends(_penyelenggara), db: AsyncSession = Depends(get_db)):
    """Penyelenggara memeriksa e-tiket peserta. Hasil 200 dengan ``berhasil=false`` + alasan bila tiket tak bisa dipakai."""
    return await svc.checkin(db, user, body.kode)


@router.get("/event/{event_id}", response_model=EventOut)
async def detail_event(event_id: str, user: User | None = Depends(get_user_opsional), db: AsyncSession = Depends(get_db)):
    await svc.kedaluwarsakan(db)
    e = await svc.muat(db, event_id)
    return (await svc.ke_out_banyak(db, [e], user))[0]


@router.post("/event/{event_id}/batal", response_model=EventOut)
async def batal_event(event_id: str, user: User = Depends(_penyelenggara), db: AsyncSession = Depends(get_db)):
    e = await svc.batalkan_event(db, user, event_id)
    return (await svc.ke_out_banyak(db, [e], user))[0]


@router.get("/event/{event_id}/peserta", response_model=PesertaList)
async def peserta(event_id: str, user: User = Depends(_penyelenggara), db: AsyncSession = Depends(get_db)):
    items = await svc.peserta(db, user, event_id)
    return PesertaList(items=items, total=len(items))


@router.post("/event/{event_id}/pesan", response_model=PesananTiketOut, status_code=201)
async def pesan_tiket(event_id: str, body: PesanTiketIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Pesan tiket. Tiket gratis langsung terbit; tiket berbayar menunggu pembayaran (30 menit)."""
    p = await svc.pesan(db, user, event_id, body.tiket_id, body.jumlah, body.nama_pemegang)
    return await svc.pesanan_out(db, p)


@router.get("/event-pesanan/{pesanan_id}", response_model=PesananTiketOut)
async def detail_pesanan(pesanan_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = await svc.kunci_pesanan(db, pesanan_id, user)
    return await svc.pesanan_out(db, p)


@router.post("/event-pesanan/{pesanan_id}/bayar", response_model=PesananTiketOut)
async def bayar(pesanan_id: str, body: BayarTiketIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = await svc.kunci_pesanan(db, pesanan_id, user)
    await svc.pilih_metode(db, p, body.metode)
    return await svc.pesanan_out(db, p)


@router.post("/event-pesanan/{pesanan_id}/bayar/simulasi", response_model=PesananTiketOut)
async def simulasi(pesanan_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """SANDBOX: anggap pembayaran masuk, lalu e-tiket diterbitkan."""
    if not pembayaran.simulasi_diizinkan():
        raise HTTPException(404, "Tidak tersedia.")
    p = await svc.kunci_pesanan(db, pesanan_id, user)
    await svc.tandai_dibayar(db, p)
    return await svc.pesanan_out(db, p)


@router.post("/event-pesanan/{pesanan_id}/batal", response_model=PesananTiketOut)
async def batal_pesanan(pesanan_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = await svc.kunci_pesanan(db, pesanan_id, user)
    await svc.batalkan_pesanan(db, p)
    return await svc.pesanan_out(db, p)


@router.get("/tiket-saya", response_model=TiketSayaList)
async def tiket_saya(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Semua e-tiketmu (aktif dan terpakai), event terdekat dulu."""
    await svc.kedaluwarsakan(db)
    rows = (await db.execute(
        select(EventTiketPembelian, EventTiket, Event)
        .join(EventTiket, EventTiket.id == EventTiketPembelian.event_tiket_id).join(Event, Event.id == EventTiket.event_id)
        .where(EventTiketPembelian.pembeli_id == user.id, EventTiketPembelian.status != "dibatalkan")
        .order_by(Event.mulai_at.desc(), EventTiketPembelian.created_at)
    )).all()
    now = svc._now()
    return TiketSayaList(items=[
        TiketSayaItem(
            etiket=ETiket(id=str(tp.id), kode=tp.kode_tiket, nama_pemegang=tp.nama_pemegang, status=tp.status.value, checkin_at=tp.checkin_at),
            tiket_nama=tk.nama_tiket, event=svc._ringkas(ev, now), link_online=ev.link_online,
        ) for tp, tk, ev in rows
    ])
