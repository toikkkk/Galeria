"""Logika event & tiket: membuat event, memesan/membayar tiket, e-tiket, dan check-in penyelenggara.

Aturan penting:
- Penyelenggara = seniman atau akun komunitas. Event langsung terbit; waktu harus di masa depan.
- Kuota dijaga di level server: pembelian mengunci baris jenis tiket (``FOR UPDATE``) lalu menghitung tiket yang
  sudah dibayar + yang sedang menunggu pembayaran (menahan kuota 30 menit). Maksimal 5 tiket per akun per event.
- Tiket gratis langsung terbit. Tiket berbayar terbit saat pembayaran diterima (sandbox: tombol simulasi).
- E-tiket punya kode acak unik; check-in hanya oleh penyelenggara event itu, sekali pakai, mulai 2 jam sebelum event
  sampai event berakhir.
- Tautan event online hanya diberikan ke penyelenggara dan pemegang tiket.
- Pesanan tiket yang tidak dibayar lewat batas waktu dibatalkan secara lazy (saat ada akses).
"""

from __future__ import annotations

import secrets
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models.event import Event, EventKarya, EventPesanan, EventTiket, EventTiketPembelian, StatusEvent as SE
from models.karya import Karya, StatusVerifikasiKarya
from models.komunitas import Komunitas
from models.user import User
from schemas.event import (
    CheckinOut, ETiket, EventBuat, EventOut, EventRingkas, KaryaEvent, PesananTiketOut, PesertaItem, TiketOut,
)
from schemas.pesanan import InstruksiBayar
from services import pembayaran, storage
from services import notifikasi_service as notif
from models.engagement import TipeNotifikasi

BATAS_BAYAR_MENIT = 30
MAKS_TIKET_PER_AKUN = 5
CHECKIN_SEBELUM = timedelta(hours=2)
_ALFABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # tanpa 0/O/1/I agar mudah dibaca & diketik

LABEL_PESANAN = {"menunggu_pembayaran": "Menunggu pembayaran", "dibayar": "Tiket terbit", "dibatalkan": "Dibatalkan"}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _parse(v: str, pesan: str) -> uuid.UUID:
    try:
        return uuid.UUID(v)
    except ValueError:
        raise HTTPException(404, pesan)


def status_event(e: Event, now: datetime | None = None) -> str:
    now = now or _now()
    if e.status in (SE.DIBATALKAN, SE.DRAFT):
        return e.status.value
    if now >= e.selesai_at:
        return "selesai"
    return "berlangsung" if now >= e.mulai_at else "akan_datang"


def _kode() -> str:
    return "GAL-" + "".join(secrets.choice(_ALFABET) for _ in range(10))


async def kedaluwarsakan(db: AsyncSession) -> None:
    await db.execute(
        update(EventPesanan).where(EventPesanan.status == "menunggu_pembayaran", EventPesanan.batas_bayar_at < _now())
        .values(status="dibatalkan")
    )
    await db.commit()


async def _terpakai(db: AsyncSession, tiket_ids: list[uuid.UUID]) -> dict[uuid.UUID, int]:
    if not tiket_ids:
        return {}
    rows = await db.execute(
        select(EventPesanan.event_tiket_id, func.coalesce(func.sum(EventPesanan.jumlah), 0))
        .where(EventPesanan.event_tiket_id.in_(tiket_ids), EventPesanan.status.in_(["menunggu_pembayaran", "dibayar"]))
        .group_by(EventPesanan.event_tiket_id)
    )
    return {r[0]: int(r[1]) for r in rows}


async def ke_out_banyak(db: AsyncSession, daftar: list[Event], user: User | None) -> list[EventOut]:
    if not daftar:
        return []
    now = _now()
    eids = [e.id for e in daftar]
    tiket = (await db.execute(select(EventTiket).where(EventTiket.event_id.in_(eids)).order_by(EventTiket.harga_idr, EventTiket.nama_tiket))).scalars().all()
    terpakai = await _terpakai(db, [t.id for t in tiket])
    per_event: dict[uuid.UUID, list[EventTiket]] = {}
    for t in tiket:
        per_event.setdefault(t.event_id, []).append(t)
    karya_rows = (
        await db.execute(select(EventKarya.event_id, Karya).join(Karya, Karya.id == EventKarya.karya_id).where(EventKarya.event_id.in_(eids)))
    ).all()
    karya_per: dict[uuid.UUID, list[Karya]] = {}
    for eid, k in karya_rows:
        if k.deleted_at is None:
            karya_per.setdefault(eid, []).append(k)
    nama = {u.id: u.display_name for u in (await db.execute(select(User).where(User.id.in_({e.komunitas_id for e in daftar})))).scalars()}
    refs = {e.komunitas_ref_id for e in daftar if e.komunitas_ref_id}
    nama_kom = {k.id: k.nama for k in (await db.execute(select(Komunitas).where(Komunitas.id.in_(refs)))).scalars()} if refs else {}
    punya: set[uuid.UUID] = set()
    if user is not None:
        punya = set((await db.execute(
            select(EventTiket.event_id).join(EventTiketPembelian, EventTiketPembelian.event_tiket_id == EventTiket.id)
            .where(EventTiketPembelian.pembeli_id == user.id, EventTiketPembelian.status != "dibatalkan", EventTiket.event_id.in_(eids))
        )).scalars())
    stat: dict[uuid.UUID, tuple[int, int, int]] = {}
    milik = [e.id for e in daftar if user is not None and e.komunitas_id == user.id]
    if milik:
        for r in await db.execute(
            select(EventPesanan.event_id, func.coalesce(func.sum(EventPesanan.jumlah), 0), func.coalesce(func.sum(EventPesanan.total_idr), 0))
            .where(EventPesanan.event_id.in_(milik), EventPesanan.status == "dibayar").group_by(EventPesanan.event_id)
        ):
            stat[r[0]] = (int(r[1]), int(r[2]), 0)
        for r in await db.execute(
            select(EventTiket.event_id, func.count()).join(EventTiketPembelian, EventTiketPembelian.event_tiket_id == EventTiket.id)
            .where(EventTiket.event_id.in_(milik), EventTiketPembelian.checkin_at.is_not(None)).group_by(EventTiket.event_id)
        ):
            terj, pend, _ = stat.get(r[0], (0, 0, 0))
            stat[r[0]] = (terj, pend, int(r[1]))
    out = []
    for e in daftar:
        ts = per_event.get(e.id, [])
        tout = [TiketOut(id=str(t.id), nama=t.nama_tiket, harga_idr=t.harga_idr, kuota=t.kuota, sisa=max(0, t.kuota - terpakai.get(t.id, 0)), keterangan=t.keterangan) for t in ts]
        penyelenggara = user is not None and e.komunitas_id == user.id
        st = status_event(e, now)
        terj, pend, cek = stat.get(e.id, (0, 0, 0)) if penyelenggara else (0, 0, 0)
        out.append(EventOut(
            id=str(e.id), judul=e.judul, deskripsi=e.deskripsi, tema=e.tema, format=e.format, nama_lokasi=e.nama_lokasi,
            alamat=e.alamat, kota=e.kota,
            link_online=e.link_online if (penyelenggara or e.id in punya) else None,
            mulai_at=e.mulai_at, selesai_at=e.selesai_at, status=st, penyelenggara_nama=nama.get(e.komunitas_id, "-"),
            gratis=all(t.harga_idr == 0 for t in ts), harga_mulai_idr=min((t.harga_idr for t in ts), default=0),
            total_kuota=sum(t.kuota for t in ts), total_sisa=sum(t.sisa for t in tout), tiket=tout,
            karya=[KaryaEvent(id=str(k.id), title=k.title, artist_name=k.artist_name, style_name=k.style_name, price_idr=k.price_idr,
                              image_url=storage.url_gambar(k.image_key), image_filename=k.image_filename) for k in karya_per.get(e.id, [])],
            server_now=now, saya_punya_tiket=e.id in punya, saya_penyelenggara=penyelenggara,
            komunitas_id=str(e.komunitas_ref_id) if e.komunitas_ref_id else None, komunitas_nama=nama_kom.get(e.komunitas_ref_id),
            tiket_terjual=terj if penyelenggara else None, pendapatan_idr=pend if penyelenggara else None,
            sudah_checkin=cek if penyelenggara else None,
            bisa_dibatalkan=penyelenggara and st in ("akan_datang", "berlangsung") and terj == 0,
        ))
    return out


async def muat(db: AsyncSession, event_id: str) -> Event:
    e = await db.get(Event, _parse(event_id, "Event tidak ditemukan"))
    if e is None or e.status == SE.DRAFT:
        raise HTTPException(404, "Event tidak ditemukan")
    return e


async def buat(db: AsyncSession, user: User, b: EventBuat) -> Event:
    now = _now()
    if b.mulai_at.tzinfo is None or b.selesai_at.tzinfo is None:
        raise HTTPException(422, "Waktu harus menyertakan zona waktu.")
    if b.mulai_at <= now:
        raise HTTPException(422, "Waktu mulai harus di masa depan.")
    if b.selesai_at <= b.mulai_at:
        raise HTTPException(422, "Waktu selesai harus setelah waktu mulai.")
    if b.selesai_at - b.mulai_at > timedelta(days=30):
        raise HTTPException(422, "Durasi event maksimal 30 hari.")
    if b.mulai_at - now > timedelta(days=365):
        raise HTTPException(422, "Event maksimal dijadwalkan 1 tahun ke depan.")
    if len({t.nama.lower() for t in b.tiket}) != len(b.tiket):
        raise HTTPException(422, "Nama jenis tiket tidak boleh kembar.")
    kids = [_parse(k, "Karya tidak ditemukan") for k in dict.fromkeys(b.karya_ids)]
    if kids:
        ok = (await db.execute(select(func.count()).select_from(Karya).where(
            Karya.id.in_(kids), Karya.seniman_id == user.id, Karya.deleted_at.is_(None),
            Karya.status_verifikasi == StatusVerifikasiKarya.TERVERIFIKASI,
        ))).scalar_one()
        if ok != len(kids):
            raise HTTPException(422, "Karya yang dipamerkan harus karya terverifikasi milikmu sendiri.")
    kom_id = None
    if b.komunitas_id:
        kom = await db.get(Komunitas, _parse(b.komunitas_id, "Komunitas tidak ditemukan"))
        if kom is None or kom.pemilik_id != user.id:
            raise HTTPException(422, "Event atas nama komunitas hanya bisa dibuat oleh pemilik komunitas itu.")
        kom_id = kom.id
    e = Event(
        id=uuid.uuid4(), komunitas_ref_id=kom_id, komunitas_id=user.id, judul=b.judul, deskripsi=b.deskripsi, tema=b.tema, format=b.format,
        nama_lokasi=b.nama_lokasi, alamat=b.alamat, kota=b.kota, link_online=b.link_online,
        lokasi=b.nama_lokasi if b.format == "offline" else "Online", mulai_at=b.mulai_at, selesai_at=b.selesai_at,
        status=SE.DIPUBLIKASIKAN,
    )
    db.add(e)
    await db.flush()
    for t in b.tiket:
        db.add(EventTiket(id=uuid.uuid4(), event_id=e.id, nama_tiket=t.nama, harga_idr=t.harga_idr, kuota=t.kuota, keterangan=t.keterangan))
    for k in kids:
        db.add(EventKarya(event_id=e.id, karya_id=k))
    await db.commit()
    return e


async def batalkan_event(db: AsyncSession, user: User, event_id: str) -> Event:
    await kedaluwarsakan(db)
    e = (await db.execute(select(Event).where(Event.id == _parse(event_id, "Event tidak ditemukan")).with_for_update())).scalar_one_or_none()
    if e is None or e.komunitas_id != user.id:
        raise HTTPException(404, "Event tidak ditemukan")
    if status_event(e) not in ("akan_datang", "berlangsung"):
        raise HTTPException(409, "Event ini sudah berakhir atau dibatalkan.")
    terjual = (await db.execute(select(func.count()).select_from(EventPesanan).where(EventPesanan.event_id == e.id, EventPesanan.status == "dibayar"))).scalar_one()
    if terjual:
        raise HTTPException(409, "Event ini sudah punya pembeli tiket. Pembatalan dengan pengembalian dana belum tersedia.")
    e.status = SE.DIBATALKAN
    await db.execute(update(EventPesanan).where(EventPesanan.event_id == e.id, EventPesanan.status == "menunggu_pembayaran").values(status="dibatalkan"))
    await db.commit()
    return e


async def _terbitkan_etiket(db: AsyncSession, p: EventPesanan) -> None:
    for _ in range(p.jumlah):
        db.add(EventTiketPembelian(
            id=uuid.uuid4(), event_tiket_id=p.event_tiket_id, pembeli_id=p.pembeli_id, kode_tiket=_kode(),
            pesanan_id=p.id, nama_pemegang=p.nama_pemegang,
        ))
    await db.flush()


async def pesan(db: AsyncSession, user: User, event_id: str, tiket_id: str, jumlah: int, nama: str) -> EventPesanan:
    await kedaluwarsakan(db)
    e = await muat(db, event_id)
    if e.status != SE.DIPUBLIKASIKAN or status_event(e) not in ("akan_datang", "berlangsung"):
        raise HTTPException(409, "Penjualan tiket untuk event ini sudah ditutup.")
    if e.komunitas_id == user.id:
        raise HTTPException(409, "Kamu penyelenggara event ini; tidak perlu membeli tiket.")
    tid = _parse(tiket_id, "Jenis tiket tidak ditemukan")
    t = (await db.execute(select(EventTiket).where(EventTiket.id == tid, EventTiket.event_id == e.id).with_for_update())).scalar_one_or_none()
    if t is None:
        raise HTTPException(404, "Jenis tiket tidak ditemukan")
    sisa = t.kuota - (await _terpakai(db, [t.id])).get(t.id, 0)
    if sisa <= 0:
        raise HTTPException(409, "Tiket jenis ini sudah habis.")
    if jumlah > sisa:
        raise HTTPException(409, f"Sisa tiket hanya {sisa}.")
    sudah = (await db.execute(
        select(func.coalesce(func.sum(EventPesanan.jumlah), 0)).where(
            EventPesanan.event_id == e.id, EventPesanan.pembeli_id == user.id, EventPesanan.status.in_(["menunggu_pembayaran", "dibayar"]))
    )).scalar_one()
    if int(sudah) + jumlah > MAKS_TIKET_PER_AKUN:
        raise HTTPException(409, f"Satu akun maksimal {MAKS_TIKET_PER_AKUN} tiket per event.")
    total = t.harga_idr * jumlah
    p = EventPesanan(
        id=uuid.uuid4(), event_id=e.id, event_tiket_id=t.id, pembeli_id=user.id, jumlah=jumlah,
        harga_satuan_idr=t.harga_idr, total_idr=total, nama_pemegang=nama,
        status="dibayar" if total == 0 else "menunggu_pembayaran",
        batas_bayar_at=None if total == 0 else _now() + timedelta(minutes=BATAS_BAYAR_MENIT),
        dibayar_at=_now() if total == 0 else None,
    )
    db.add(p)
    await db.flush()
    if total == 0:
        await _terbitkan_etiket(db, p)
        notif.kirim(db, user.id, TipeNotifikasi.EVENT, "Tiket terbit", f'{p.jumlah} tiket untuk "{e.judul}" sudah ada di Tiket Saya.', f"tiket:{p.id}")
    await db.commit()
    return p


async def kunci_pesanan(db: AsyncSession, pesanan_id: str, user: User) -> EventPesanan:
    await kedaluwarsakan(db)
    p = (await db.execute(select(EventPesanan).where(EventPesanan.id == _parse(pesanan_id, "Pesanan tiket tidak ditemukan")).with_for_update())).scalar_one_or_none()
    if p is None or p.pembeli_id != user.id:
        raise HTTPException(404, "Pesanan tiket tidak ditemukan")
    return p


def _pastikan_menunggu(p: EventPesanan) -> None:
    if p.status != "menunggu_pembayaran":
        raise HTTPException(409, "Pesanan tiket ini tidak lagi menunggu pembayaran.")


async def pilih_metode(db: AsyncSession, p: EventPesanan, metode: str) -> None:
    _pastikan_menunggu(p)
    try:
        _, nomor = pembayaran.buat_instruksi(metode, p.id)
    except pembayaran.PembayaranTidakTersedia as exc:
        raise HTTPException(501, str(exc))
    p.metode_pembayaran = metode
    p.referensi_pembayaran = nomor
    await db.commit()


async def tandai_dibayar(db: AsyncSession, p: EventPesanan) -> None:
    _pastikan_menunggu(p)
    if not p.metode_pembayaran:
        raise HTTPException(409, "Pilih metode pembayaran dulu.")
    p.status = "dibayar"
    p.dibayar_at = _now()
    await _terbitkan_etiket(db, p)
    ev = await db.get(Event, p.event_id)
    notif.kirim(db, p.pembeli_id, TipeNotifikasi.EVENT, "Pembayaran tiket diterima", f'{p.jumlah} e-tiket untuk "{ev.judul}" sudah terbit.', f"tiket:{p.id}")
    notif.kirim(db, ev.komunitas_id, TipeNotifikasi.EVENT, "Tiket event terjual", f'{p.jumlah} tiket "{ev.judul}" terjual.', f"event:{ev.id}")
    await db.commit()


async def batalkan_pesanan(db: AsyncSession, p: EventPesanan) -> None:
    _pastikan_menunggu(p)
    p.status = "dibatalkan"
    await db.commit()


def _ringkas(e: Event, now: datetime) -> EventRingkas:
    return EventRingkas(id=str(e.id), judul=e.judul, format=e.format, kota=e.kota, nama_lokasi=e.nama_lokasi,
                        mulai_at=e.mulai_at, selesai_at=e.selesai_at, status=status_event(e, now))


async def pesanan_out(db: AsyncSession, p: EventPesanan) -> PesananTiketOut:
    now = _now()
    e = await db.get(Event, p.event_id)
    t = await db.get(EventTiket, p.event_tiket_id)
    tk = (await db.execute(select(EventTiketPembelian).where(EventTiketPembelian.pesanan_id == p.id).order_by(EventTiketPembelian.created_at))).scalars().all()
    ins = None
    if p.status == "menunggu_pembayaran" and p.metode_pembayaran and p.referensi_pembayaran:
        ins = InstruksiBayar(metode=p.metode_pembayaran, nama_metode=pembayaran.METODE[p.metode_pembayaran][0], nomor=p.referensi_pembayaran,
                             jumlah_idr=p.total_idr, batas_bayar_at=p.batas_bayar_at, mode=pembayaran.mode())
    return PesananTiketOut(
        id=str(p.id), event=_ringkas(e, now), tiket_nama=t.nama_tiket, jumlah=p.jumlah, harga_satuan_idr=p.harga_satuan_idr,
        total_idr=p.total_idr, status=p.status, status_label=LABEL_PESANAN[p.status], nama_pemegang=p.nama_pemegang,
        instruksi_bayar=ins, batas_bayar_at=p.batas_bayar_at, dibayar_at=p.dibayar_at, created_at=p.created_at,
        etiket=[ETiket(id=str(x.id), kode=x.kode_tiket, nama_pemegang=x.nama_pemegang, status=x.status.value, checkin_at=x.checkin_at) for x in tk],
        aksi=["bayar", "batal"] if p.status == "menunggu_pembayaran" else [],
    )


async def checkin(db: AsyncSession, user: User, kode: str) -> CheckinOut:
    row = (await db.execute(
        select(EventTiketPembelian, EventTiket, Event).join(EventTiket, EventTiket.id == EventTiketPembelian.event_tiket_id)
        .join(Event, Event.id == EventTiket.event_id).where(EventTiketPembelian.kode_tiket == kode)
        .with_for_update(of=EventTiketPembelian)
    )).first()
    if row is None or row[2].komunitas_id != user.id:
        # kode milik event lain dan kode yang tak ada diperlakukan sama: penyelenggara tak bisa menebak tiket event orang
        return CheckinOut(berhasil=False, pesan="Kode tiket tidak dikenali untuk event-mu.")
    tp, tk, ev = row
    info = dict(nama_pemegang=tp.nama_pemegang, tiket_nama=tk.nama_tiket, event_judul=ev.judul)
    now = _now()
    if ev.status == SE.DIBATALKAN or tp.status.value == "dibatalkan":
        return CheckinOut(berhasil=False, pesan="Tiket ini dibatalkan.", **info)
    if tp.status.value == "terpakai":
        jam = tp.checkin_at.astimezone().strftime("%H:%M") if tp.checkin_at else "-"
        return CheckinOut(berhasil=False, pesan=f"Tiket sudah digunakan (check-in pukul {jam}).", **info)
    if now < ev.mulai_at - CHECKIN_SEBELUM:
        return CheckinOut(berhasil=False, pesan="Check-in belum dibuka (mulai 2 jam sebelum event).", **info)
    if now > ev.selesai_at:
        return CheckinOut(berhasil=False, pesan="Event sudah berakhir.", **info)
    from models.event import StatusTiketPembelian

    tp.status = StatusTiketPembelian.TERPAKAI
    tp.checkin_at = now
    await db.commit()
    return CheckinOut(berhasil=True, pesan="Check-in berhasil. Silakan masuk.", **info)


async def peserta(db: AsyncSession, user: User, event_id: str) -> list[PesertaItem]:
    e = await muat(db, event_id)
    if e.komunitas_id != user.id:
        raise HTTPException(404, "Event tidak ditemukan")
    rows = (await db.execute(
        select(EventTiketPembelian, EventTiket.nama_tiket, User.display_name)
        .join(EventTiket, EventTiket.id == EventTiketPembelian.event_tiket_id).join(User, User.id == EventTiketPembelian.pembeli_id)
        .where(EventTiket.event_id == e.id).order_by(EventTiketPembelian.created_at)
    )).all()
    return [PesertaItem(kode=tp.kode_tiket, nama_pemegang=tp.nama_pemegang, tiket_nama=n, status=tp.status.value, checkin_at=tp.checkin_at, akun_pembeli=akun) for tp, n, akun in rows]
