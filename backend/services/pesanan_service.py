"""Logika pesanan (checkout) dari klik "beli" sampai karya diterima.

Siklus hidup (kolom ``transaksi.status`` + cap waktu):

    menunggu_pembayaran --bayar--> dibayar --seniman konfirmasi--> dikonfirmasi --seniman kirim (resi)-->
    (masih dikonfirmasi, dikirim_at terisi) --kolektor terima--> selesai (kepemilikan berpindah)

    menunggu_pembayaran --kolektor batal / lewat batas bayar--> dibatalkan

Tanda tangan digital dibuat sekali saat pesanan dibuat (``transaksi_service.buat_transaksi``) dan hanya
mengunci fakta yang tidak berubah (siapa, karya apa, harga); status & data pengiriman bebas berubah.
Transisi memakai ``SELECT ... FOR UPDATE`` supaya dua permintaan bersamaan tidak saling menimpa.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from models.karya import Karya, StatusVerifikasiKarya
from models.transaksi import StatusTransaksi as S
from models.transaksi import Transaksi
from models.user import AlamatPengiriman, User
from schemas.pesanan import InstruksiBayar, KaryaRingkas, PesananOut
from services import pembayaran, storage
from services.transaksi_service import buat_transaksi, catat_transfer_kepemilikan

BATAS_BAYAR_JAM = 24

LABEL = {
    S.MENUNGGU_PEMBAYARAN: "Menunggu pembayaran",
    S.DIBAYAR: "Dibayar, menunggu konfirmasi seniman",
    S.DIKONFIRMASI: "Dikonfirmasi seniman",
    S.SELESAI: "Selesai",
    S.DIBATALKAN: "Dibatalkan",
}


def komisi_persen() -> float:
    try:
        return float(os.environ.get("KOMISI_PERSEN", "10"))
    except ValueError:
        return 10.0


def hitung_komisi(harga_idr: int) -> int:
    return round(harga_idr * komisi_persen() / 100)


def _now() -> datetime:
    return datetime.now(timezone.utc)


async def kedaluwarsakan(db: AsyncSession) -> None:
    """Batalkan pesanan yang melewati batas bayar (dipanggil lazy tiap ada akses, tanpa job terjadwal)."""
    await db.execute(
        update(Transaksi)
        .where(Transaksi.status == S.MENUNGGU_PEMBAYARAN, Transaksi.batas_bayar_at < _now())
        .values(status=S.DIBATALKAN, dibatalkan_at=_now())
    )
    await db.commit()


def _aksi(t: Transaksi, user_id: uuid.UUID) -> list[str]:
    a: list[str] = []
    if user_id == t.pembeli_id:
        if t.status == S.MENUNGGU_PEMBAYARAN:
            a += ["bayar", "batal"]
        elif t.status == S.DIKONFIRMASI and t.dikirim_at is not None:
            a.append("terima")
    if user_id == t.penjual_id:
        if t.status == S.DIBAYAR:
            a.append("konfirmasi")
        elif t.status == S.DIKONFIRMASI and t.dikirim_at is None:
            a.append("kirim")
    return a


def ke_out(t: Transaksi, karya: Karya, pembeli: User, penjual: User, user_id: uuid.UUID) -> PesananOut:
    instruksi = None
    if t.status == S.MENUNGGU_PEMBAYARAN and t.metode_pembayaran and t.referensi_pembayaran:
        nama, _ = pembayaran.METODE[t.metode_pembayaran][0], None
        instruksi = InstruksiBayar(
            metode=t.metode_pembayaran,
            nama_metode=nama,
            nomor=t.referensi_pembayaran,
            jumlah_idr=t.harga_final_idr,
            batas_bayar_at=t.batas_bayar_at,
            mode=pembayaran.mode(),
        )
    return PesananOut(
        id=str(t.id),
        status=t.status.value,
        status_label=("Dalam pengiriman" if t.status == S.DIKONFIRMASI and t.dikirim_at else LABEL[t.status]),
        karya=KaryaRingkas(
            id=str(karya.id), title=karya.title, artist_name=karya.artist_name, style_name=karya.style_name,
            image_url=storage.url_gambar(karya.image_key), image_filename=karya.image_filename,
        ),
        pembeli_nama=pembeli.display_name,
        penjual_nama=penjual.display_name,
        harga_final_idr=t.harga_final_idr,
        komisi_platform_idr=t.komisi_platform_idr,
        pendapatan_seniman_idr=t.harga_final_idr - t.komisi_platform_idr,
        alamat=t.alamat_snapshot,
        instruksi_bayar=instruksi,
        metode_pembayaran=t.metode_pembayaran,
        kurir=t.kurir,
        no_resi=t.no_resi,
        sudah_dikirim=t.dikirim_at is not None,
        created_at=t.created_at,
        batas_bayar_at=t.batas_bayar_at,
        dibayar_at=t.dibayar_at,
        dikonfirmasi_at=t.dikonfirmasi_at,
        dikirim_at=t.dikirim_at,
        selesai_at=t.selesai_at,
        dibatalkan_at=t.dibatalkan_at,
        aksi=_aksi(t, user_id),
    )


async def muat_out(db: AsyncSession, t: Transaksi, user_id: uuid.UUID) -> PesananOut:
    karya = await db.get(Karya, t.karya_id)
    pembeli = await db.get(User, t.pembeli_id)
    penjual = await db.get(User, t.penjual_id)
    return ke_out(t, karya, pembeli, penjual, user_id)


def _parse_uuid(v: str, pesan: str) -> uuid.UUID:
    try:
        return uuid.UUID(v)
    except ValueError:
        raise HTTPException(404, pesan)


async def buat_pesanan(db: AsyncSession, pembeli: User, karya_id: str, alamat_id: str) -> Transaksi:
    kid = _parse_uuid(karya_id, "Karya tidak ditemukan")
    aid = _parse_uuid(alamat_id, "Alamat tidak ditemukan")
    await kedaluwarsakan(db)

    alamat = await db.get(AlamatPengiriman, aid)
    if alamat is None or alamat.user_id != pembeli.id:
        raise HTTPException(404, "Alamat tidak ditemukan")

    karya = (await db.execute(select(Karya).where(Karya.id == kid).with_for_update())).scalar_one_or_none()
    if (
        karya is None
        or karya.deleted_at is not None
        or karya.status_verifikasi != StatusVerifikasiKarya.TERVERIFIKASI
        or karya.seniman_id is None
    ):
        raise HTTPException(404, "Karya ini tidak tersedia untuk dibeli (karya contoh pada data demo tidak bisa dipesan).")
    if karya.seniman_id == pembeli.id:
        raise HTTPException(400, "Kamu tidak bisa membeli karyamu sendiri.")

    sudah = await db.scalar(select(Transaksi.id).where(Transaksi.karya_id == kid, Transaksi.status != S.DIBATALKAN))
    if sudah is not None:
        raise HTTPException(409, "Karya ini sudah terjual atau sedang dipesan orang lain.")

    try:
        t = await buat_transaksi(
            db, kid, pembeli.id, karya.seniman_id, karya.price_idr, hitung_komisi(karya.price_idr)
        )
    except RuntimeError as exc:  # belum ada signing key aktif / private key tak terbaca di server ini
        raise HTTPException(503, f"Penandatanganan transaksi belum siap di server: {exc}")
    t.alamat_snapshot = {
        "label": alamat.label,
        "nama_penerima": alamat.nama_penerima,
        "telepon": alamat.telepon,
        "alamat_lengkap": alamat.alamat_lengkap,
        "kota": alamat.kota,
        "kode_pos": alamat.kode_pos,
    }
    t.batas_bayar_at = _now() + timedelta(hours=BATAS_BAYAR_JAM)
    try:
        await db.commit()
    except IntegrityError:  # balapan dua pembeli: indeks unik parsial di DB menang
        await db.rollback()
        raise HTTPException(409, "Karya ini sudah terjual atau sedang dipesan orang lain.")
    return t


async def kunci(db: AsyncSession, pesanan_id: str) -> Transaksi:
    tid = _parse_uuid(pesanan_id, "Pesanan tidak ditemukan")
    await kedaluwarsakan(db)
    t = (await db.execute(select(Transaksi).where(Transaksi.id == tid).with_for_update())).scalar_one_or_none()
    if t is None:
        raise HTTPException(404, "Pesanan tidak ditemukan")
    return t


def pastikan_pihak(t: Transaksi, user: User, *, sebagai: str) -> None:
    ok = (sebagai == "pembeli" and t.pembeli_id == user.id) or (sebagai == "penjual" and t.penjual_id == user.id)
    if not ok:
        raise HTTPException(404, "Pesanan tidak ditemukan")  # bukan 403: jangan bocorkan pesanan orang lain


def pastikan_status(t: Transaksi, *boleh: S, pesan: str) -> None:
    if t.status not in boleh:
        raise HTTPException(409, pesan)


async def pilih_metode(db: AsyncSession, t: Transaksi, metode: str) -> None:
    nama, nomor = pembayaran.buat_instruksi(metode, t.id)
    t.metode_pembayaran = metode
    t.referensi_pembayaran = nomor
    await db.commit()


async def tandai_dibayar(db: AsyncSession, t: Transaksi) -> None:
    """Dipanggil simulator sandbox (dan kelak webhook gateway) saat uang diterima."""
    t.status = S.DIBAYAR
    t.dibayar_at = _now()
    await db.commit()


async def batalkan(db: AsyncSession, t: Transaksi) -> None:
    t.status = S.DIBATALKAN
    t.dibatalkan_at = _now()
    await db.commit()


async def konfirmasi(db: AsyncSession, t: Transaksi) -> None:
    t.status = S.DIKONFIRMASI
    t.dikonfirmasi_at = _now()
    await db.commit()


async def kirim(db: AsyncSession, t: Transaksi, kurir: str, no_resi: str) -> None:
    t.kurir = kurir
    t.no_resi = no_resi
    t.dikirim_at = _now()
    await db.commit()


async def terima(db: AsyncSession, t: Transaksi) -> None:
    """Pembeli menerima karya: pesanan selesai dan kepemilikan berpindah (satu transaksi DB)."""
    t.status = S.SELESAI
    t.selesai_at = _now()
    await catat_transfer_kepemilikan(db, t)
    await db.commit()
