"""Logika komunitas seniman.

Aturan akses:
- Komunitas TERBUKA: siapa pun yang login boleh melihat isi (postingan, anggota, karya) dan bergabung langsung.
- Komunitas TERTUTUP: isi hanya untuk anggota aktif; bergabung = mengajukan permintaan yang disetujui pemilik.
- Menulis postingan/komentar dan menyukai: anggota aktif. Pemilik juga boleh menghapus postingan/komentar siapa
  pun, menyematkan satu postingan, menyetujui/menolak permintaan, dan mengeluarkan anggota.
- Satu akun memiliki maksimal 3 komunitas. Nama komunitas unik (tanpa membedakan huruf besar/kecil).
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy import delete, func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from models.karya import Karya, StatusVerifikasiKarya
from models.komunitas import Komunitas, KomunitasAnggota, KomunitasKomentar, KomunitasLike, KomunitasPost
from models.user import User
from schemas.komunitas import (
    AnggotaList, AnggotaOut, KomentarOut, KomunitasBuat, KomunitasOut, PostOut,
)
from services import storage
from services import notifikasi_service as notif
from models.engagement import TipeNotifikasi

MAKS_KOMUNITAS_MILIK = 3


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _parse(v: str, pesan: str) -> uuid.UUID:
    try:
        return uuid.UUID(v)
    except ValueError:
        raise HTTPException(404, pesan)


async def muat(db: AsyncSession, komunitas_id: str, *, kunci: bool = False) -> Komunitas:
    q = select(Komunitas).where(Komunitas.id == _parse(komunitas_id, "Komunitas tidak ditemukan"))
    if kunci:
        q = q.with_for_update()
    k = (await db.execute(q)).scalar_one_or_none()
    if k is None:
        raise HTTPException(404, "Komunitas tidak ditemukan")
    return k


async def hubungan(db: AsyncSession, kid: uuid.UUID, user: User | None) -> KomunitasAnggota | None:
    if user is None:
        return None
    return await db.get(KomunitasAnggota, (kid, user.id))


def _label_saya(a: KomunitasAnggota | None) -> str | None:
    if a is None:
        return None
    return "menunggu" if a.status == "menunggu" else a.peran


async def pastikan_boleh_lihat(db: AsyncSession, k: Komunitas, user: User | None) -> KomunitasAnggota | None:
    a = await hubungan(db, k.id, user)
    if not k.terbuka and not (a is not None and a.status == "aktif"):
        raise HTTPException(403, "Komunitas ini tertutup. Bergabunglah untuk melihat isinya.")
    return a


async def pastikan_anggota(db: AsyncSession, k: Komunitas, user: User) -> KomunitasAnggota:
    a = await hubungan(db, k.id, user)
    if a is None or a.status != "aktif":
        raise HTTPException(403, "Hanya anggota komunitas yang bisa melakukan ini.")
    return a


def pastikan_pemilik(k: Komunitas, user: User) -> None:
    if k.pemilik_id != user.id:
        raise HTTPException(403, "Hanya pemilik komunitas yang bisa melakukan ini.")


async def ke_out_banyak(db: AsyncSession, daftar: list[Komunitas], user: User | None) -> list[KomunitasOut]:
    if not daftar:
        return []
    ids = [k.id for k in daftar]
    jumlah = {r[0]: int(r[1]) for r in await db.execute(
        select(KomunitasAnggota.komunitas_id, func.count()).where(KomunitasAnggota.komunitas_id.in_(ids), KomunitasAnggota.status == "aktif").group_by(KomunitasAnggota.komunitas_id)
    )}
    nama = {u.id: u.display_name for u in (await db.execute(select(User).where(User.id.in_({k.pemilik_id for k in daftar})))).scalars()}
    saya: dict[uuid.UUID, KomunitasAnggota] = {}
    if user is not None:
        for a in (await db.execute(select(KomunitasAnggota).where(KomunitasAnggota.komunitas_id.in_(ids), KomunitasAnggota.user_id == user.id))).scalars():
            saya[a.komunitas_id] = a
    permintaan: dict[uuid.UUID, int] = {}
    milik = [k.id for k in daftar if user is not None and k.pemilik_id == user.id]
    if milik:
        permintaan = {r[0]: int(r[1]) for r in await db.execute(
            select(KomunitasAnggota.komunitas_id, func.count()).where(KomunitasAnggota.komunitas_id.in_(milik), KomunitasAnggota.status == "menunggu").group_by(KomunitasAnggota.komunitas_id)
        )}
    return [
        KomunitasOut(
            id=str(k.id), nama=k.nama, deskripsi=k.deskripsi, aliran=list(k.aliran or []), terbuka=k.terbuka, aturan=k.aturan,
            pemilik_nama=nama.get(k.pemilik_id, "-"), jumlah_anggota=jumlah.get(k.id, 0), dibuat_at=k.created_at,
            saya=_label_saya(saya.get(k.id)), jumlah_permintaan=permintaan.get(k.id, 0) if k.id in milik else None,
        )
        for k in daftar
    ]


async def buat(db: AsyncSession, user: User, b: KomunitasBuat) -> Komunitas:
    punya = (await db.execute(select(func.count()).select_from(Komunitas).where(Komunitas.pemilik_id == user.id))).scalar_one()
    if punya >= MAKS_KOMUNITAS_MILIK:
        raise HTTPException(409, f"Satu akun maksimal memiliki {MAKS_KOMUNITAS_MILIK} komunitas.")
    k = Komunitas(id=uuid.uuid4(), pemilik_id=user.id, nama=b.nama, deskripsi=b.deskripsi, aliran=b.aliran, terbuka=b.terbuka, aturan=b.aturan)
    db.add(k)
    try:
        await db.flush()
        db.add(KomunitasAnggota(komunitas_id=k.id, user_id=user.id, peran="pemilik", status="aktif"))
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(409, "Nama komunitas sudah dipakai. Pilih nama lain.")
    return k


async def gabung(db: AsyncSession, user: User, komunitas_id: str) -> KomunitasAnggota:
    k = await muat(db, komunitas_id)
    a = await hubungan(db, k.id, user)
    if a is not None:
        raise HTTPException(409, "Kamu sudah menjadi anggota." if a.status == "aktif" else "Permintaan bergabungmu sedang menunggu persetujuan.")
    a = KomunitasAnggota(komunitas_id=k.id, user_id=user.id, peran="anggota", status="aktif" if k.terbuka else "menunggu")
    db.add(a)
    notif.kirim(db, k.pemilik_id, TipeNotifikasi.KOMUNITAS, "Anggota baru bergabung" if k.terbuka else "Permintaan bergabung baru",
                f"{user.display_name} {'bergabung di' if k.terbuka else 'meminta bergabung ke'} {k.nama}.", f"komunitas:{k.id}")
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(409, "Kamu sudah terdaftar di komunitas ini.")
    return a


async def keluar(db: AsyncSession, user: User, komunitas_id: str) -> None:
    k = await muat(db, komunitas_id)
    a = await hubungan(db, k.id, user)
    if a is None:
        raise HTTPException(409, "Kamu bukan anggota komunitas ini.")
    if k.pemilik_id == user.id:
        raise HTTPException(409, "Pemilik tidak bisa keluar dari komunitasnya sendiri.")
    await db.delete(a)
    await db.commit()


async def daftar_anggota(db: AsyncSession, k: Komunitas, user: User | None) -> AnggotaList:
    await pastikan_boleh_lihat(db, k, user)
    rows = (await db.execute(
        select(KomunitasAnggota, User.display_name).join(User, User.id == KomunitasAnggota.user_id)
        .where(KomunitasAnggota.komunitas_id == k.id).order_by(KomunitasAnggota.peran.desc(), KomunitasAnggota.bergabung_at)
    )).all()
    def o(a, n): return AnggotaOut(user_id=str(a.user_id), nama=n, peran=a.peran, bergabung_at=a.bergabung_at)
    aktif = [o(a, n) for a, n in rows if a.status == "aktif"]
    minta = [o(a, n) for a, n in rows if a.status == "menunggu"] if (user is not None and k.pemilik_id == user.id) else []
    return AnggotaList(anggota=aktif, permintaan=minta)


async def putuskan_permintaan(db: AsyncSession, user: User, komunitas_id: str, target_id: str, setuju: bool) -> None:
    k = await muat(db, komunitas_id)
    pastikan_pemilik(k, user)
    a = await db.get(KomunitasAnggota, (k.id, _parse(target_id, "Anggota tidak ditemukan")))
    if a is None or a.status != "menunggu":
        raise HTTPException(404, "Permintaan bergabung tidak ditemukan.")
    notif.kirim(db, a.user_id, TipeNotifikasi.KOMUNITAS, "Permintaan disetujui" if setuju else "Permintaan ditolak",
                f"Permintaanmu bergabung ke {k.nama} {'disetujui' if setuju else 'ditolak'}.", f"komunitas:{k.id}")
    if setuju:
        a.status = "aktif"
    else:
        await db.delete(a)
    await db.commit()


async def keluarkan(db: AsyncSession, user: User, komunitas_id: str, target_id: str) -> None:
    k = await muat(db, komunitas_id)
    pastikan_pemilik(k, user)
    tid = _parse(target_id, "Anggota tidak ditemukan")
    if tid == user.id:
        raise HTTPException(409, "Pemilik tidak bisa mengeluarkan dirinya sendiri.")
    a = await db.get(KomunitasAnggota, (k.id, tid))
    if a is None:
        raise HTTPException(404, "Anggota tidak ditemukan.")
    await db.delete(a)
    await db.commit()


# ------------------------------------------------------------------ postingan
async def post_out_banyak(db: AsyncSession, posts: list[KomunitasPost], k: Komunitas, user: User | None) -> list[PostOut]:
    if not posts:
        return []
    ids = [p.id for p in posts]
    nama = {u.id: u.display_name for u in (await db.execute(select(User).where(User.id.in_({p.penulis_id for p in posts})))).scalars()}
    likes = {r[0]: int(r[1]) for r in await db.execute(select(KomunitasLike.post_id, func.count()).where(KomunitasLike.post_id.in_(ids)).group_by(KomunitasLike.post_id))}
    komen = {r[0]: int(r[1]) for r in await db.execute(
        select(KomunitasKomentar.post_id, func.count()).where(KomunitasKomentar.post_id.in_(ids), KomunitasKomentar.deleted_at.is_(None)).group_by(KomunitasKomentar.post_id))}
    saya = set()
    if user is not None:
        saya = set((await db.execute(select(KomunitasLike.post_id).where(KomunitasLike.post_id.in_(ids), KomunitasLike.user_id == user.id))).scalars())
    pemilik = user is not None and k.pemilik_id == user.id
    return [
        PostOut(
            id=str(p.id), komunitas_id=str(p.komunitas_id), penulis_id=str(p.penulis_id), penulis_nama=nama.get(p.penulis_id, "-"),
            penulis_pemilik=p.penulis_id == k.pemilik_id, teks=p.teks, image_url=storage.url_gambar(p.image_key), disematkan=p.disematkan,
            jumlah_like=likes.get(p.id, 0), jumlah_komentar=komen.get(p.id, 0), saya_like=p.id in saya, waktu=p.created_at,
            bisa_hapus=bool(user is not None and (p.penulis_id == user.id or pemilik)), bisa_sematkan=pemilik,
        )
        for p in posts
    ]


async def buat_post(db: AsyncSession, user: User, komunitas_id: str, teks: str, image_key: str | None = None) -> tuple[KomunitasPost, Komunitas]:
    k = await muat(db, komunitas_id)
    await pastikan_anggota(db, k, user)
    p = KomunitasPost(id=uuid.uuid4(), komunitas_id=k.id, penulis_id=user.id, teks=teks, image_key=image_key)
    db.add(p)
    await db.commit()
    return p, k


async def muat_post(db: AsyncSession, post_id: str, *, kunci: bool = False) -> tuple[KomunitasPost, Komunitas]:
    q = select(KomunitasPost).where(KomunitasPost.id == _parse(post_id, "Postingan tidak ditemukan"), KomunitasPost.deleted_at.is_(None))
    if kunci:
        q = q.with_for_update()
    p = (await db.execute(q)).scalar_one_or_none()
    if p is None:
        raise HTTPException(404, "Postingan tidak ditemukan")
    return p, await muat(db, str(p.komunitas_id))


async def hapus_post(db: AsyncSession, user: User, post_id: str) -> str | None:
    p, k = await muat_post(db, post_id)
    if p.penulis_id != user.id and k.pemilik_id != user.id:
        raise HTTPException(403, "Kamu hanya bisa menghapus postinganmu sendiri.")
    p.deleted_at = _now()
    p.disematkan = False
    await db.commit()
    return p.image_key


async def sematkan(db: AsyncSession, user: User, post_id: str) -> KomunitasPost:
    p, k = await muat_post(db, post_id, kunci=True)
    pastikan_pemilik(k, user)
    if p.disematkan:
        p.disematkan = False
    else:
        await db.execute(update(KomunitasPost).where(KomunitasPost.komunitas_id == k.id, KomunitasPost.disematkan.is_(True)).values(disematkan=False))
        p.disematkan = True
    await db.commit()
    return p


async def toggle_like(db: AsyncSession, user: User, post_id: str) -> tuple[bool, int]:
    p, k = await muat_post(db, post_id)
    await pastikan_anggota(db, k, user)
    ada = await db.get(KomunitasLike, (p.id, user.id))
    if ada is None:
        db.add(KomunitasLike(post_id=p.id, user_id=user.id))
        saya = True
    else:
        await db.delete(ada)
        saya = False
    try:
        await db.commit()
    except IntegrityError:  # dua ketukan bersamaan: anggap sudah tersuka
        await db.rollback()
        saya = True
    n = (await db.execute(select(func.count()).select_from(KomunitasLike).where(KomunitasLike.post_id == p.id))).scalar_one()
    return saya, int(n)


async def buat_komentar(db: AsyncSession, user: User, post_id: str, teks: str) -> KomentarOut:
    p, k = await muat_post(db, post_id)
    await pastikan_anggota(db, k, user)
    c = KomunitasKomentar(id=uuid.uuid4(), post_id=p.id, penulis_id=user.id, teks=teks)
    db.add(c)
    if p.penulis_id != user.id:
        notif.kirim(db, p.penulis_id, TipeNotifikasi.KOMUNITAS, f"{user.display_name} mengomentari postinganmu", teks[:100], f"komunitas:{k.id}")
    await db.commit()
    return KomentarOut(id=str(c.id), penulis_id=str(user.id), penulis_nama=user.display_name, teks=c.teks, waktu=c.created_at or _now(), bisa_hapus=True)


async def daftar_komentar(db: AsyncSession, user: User | None, post_id: str) -> list[KomentarOut]:
    p, k = await muat_post(db, post_id)
    await pastikan_boleh_lihat(db, k, user)
    rows = (await db.execute(
        select(KomunitasKomentar, User.display_name).join(User, User.id == KomunitasKomentar.penulis_id)
        .where(KomunitasKomentar.post_id == p.id, KomunitasKomentar.deleted_at.is_(None)).order_by(KomunitasKomentar.created_at).limit(200)
    )).all()
    return [KomentarOut(id=str(c.id), penulis_id=str(c.penulis_id), penulis_nama=n, teks=c.teks, waktu=c.created_at,
                        bisa_hapus=bool(user is not None and (c.penulis_id == user.id or k.pemilik_id == user.id))) for c, n in rows]


async def hapus_komentar(db: AsyncSession, user: User, komentar_id: str) -> None:
    c = await db.get(KomunitasKomentar, _parse(komentar_id, "Komentar tidak ditemukan"))
    if c is None or c.deleted_at is not None:
        raise HTTPException(404, "Komentar tidak ditemukan")
    p = await db.get(KomunitasPost, c.post_id)
    k = await muat(db, str(p.komunitas_id))
    if c.penulis_id != user.id and k.pemilik_id != user.id:
        raise HTTPException(403, "Kamu hanya bisa menghapus komentarmu sendiri.")
    c.deleted_at = _now()
    await db.commit()


async def karya_anggota(db: AsyncSession, k: Komunitas, limit: int = 40) -> list[Karya]:
    return list((await db.execute(
        select(Karya).join(KomunitasAnggota, KomunitasAnggota.user_id == Karya.seniman_id)
        .where(KomunitasAnggota.komunitas_id == k.id, KomunitasAnggota.status == "aktif", Karya.deleted_at.is_(None),
               Karya.status_verifikasi == StatusVerifikasiKarya.TERVERIFIKASI)
        .order_by(Karya.created_at.desc()).limit(limit)
    )).scalars())
