"""Penandatanganan transaksi & pencatatan transfer kepemilikan (TODO_KRIPTOGRAFI.md Tahap 4.2).

Dua fungsi dengan tanggung jawab SENGAJA terpisah (lihat SPEC_PAYLOAD.md 1.2.b):

- ``buat_transaksi()`` -- tanda tangan dilakukan SEKALI, saat baris ``transaksi`` pertama
  kali di-INSERT (``payload_hash``/``digital_signature`` NOT NULL sejak awal di skema).
  Payload HANYA mengunci fakta order yang TIDAK BERUBAH (siapa, karya apa, harga berapa) --
  ``status`` SENGAJA TIDAK ikut ditandatangani karena kolom itu mutable sepanjang lifecycle
  order (menunggu_pembayaran -> dibayar -> ... -> selesai).
- ``catat_transfer_kepemilikan()`` -- dipanggil TERPISAH, hanya saat status transaksi
  mencapai "selesai" (kepemilikan baru BENAR-BENAR berpindah di titik itu, bukan saat order
  dibuat). Murni pencatatan (``kepemilikan_karya`` tidak punya kolom signature sendiri --
  bukti kriptografisnya berasal dari ``transaksi.digital_signature`` yang terhubung lewat FK).

CATATAN SCOPE (jujur, bukan disembunyikan): belum ada endpoint checkout/pembayaran di
backend ini (lihat CLAUDE.md root "Belum dikerjakan"). Modul ini menyediakan PRIMITIF yang
nanti dipanggil endpoint checkout tsb -- bukan alur pembayaran lengkap (itu di luar scope
fitur kriptografi).
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.sertifikat import SigningKey
from models.transaksi import KepemilikanKarya, StatusTransaksi, SumberKepemilikan, Transaksi
from services.kripto import format_waktu_kanonik, hitung_payload_hash, muat_private_key, tanda_tangani


async def buat_transaksi(
    db: AsyncSession,
    karya_id: uuid.UUID,
    pembeli_id: uuid.UUID,
    penjual_id: uuid.UUID,
    harga_final_idr: int,
    komisi_platform_idr: int,
) -> Transaksi:
    """Bangun payload ``transaksi.v1`` kanonik -> hash -> tanda tangani -> INSERT baris
    ``transaksi`` (status awal MENUNGGU_PEMBAYARAN). TIDAK melakukan ``db.commit()`` --
    caller yang menentukan kapan transaksi DB ditutup.
    """
    signing_key = await db.scalar(select(SigningKey).where(SigningKey.is_active.is_(True)))
    if signing_key is None:
        raise RuntimeError("Tidak ada signing key aktif -- jalankan `python -m scripts.buat_signing_key` dulu.")

    transaksi_id = uuid.uuid4()
    dibuat_pada = datetime.now(timezone.utc)

    # Field di sini HARUS sama persis dgn SPEC_PAYLOAD.md 1.2.b -- `status` SENGAJA tidak ada.
    payload = {
        "schema": "transaksi.v1",
        "transaksi_id": str(transaksi_id),
        "karya_id": str(karya_id),
        "pembeli_id": str(pembeli_id),
        "penjual_id": str(penjual_id),
        "harga_final_idr": harga_final_idr,
        "komisi_platform_idr": komisi_platform_idr,
        "dibuat_pada": format_waktu_kanonik(dibuat_pada),
    }
    payload_hash = hitung_payload_hash(payload)
    private_key = muat_private_key(signing_key.kms_key_ref)
    digital_signature = tanda_tangani(payload_hash, private_key)

    transaksi = Transaksi(
        id=transaksi_id,
        karya_id=karya_id,
        pembeli_id=pembeli_id,
        penjual_id=penjual_id,
        harga_final_idr=harga_final_idr,
        komisi_platform_idr=komisi_platform_idr,
        status=StatusTransaksi.MENUNGGU_PEMBAYARAN,
        payload_hash=payload_hash,
        digital_signature=digital_signature,
        signing_key_id=signing_key.id,
        created_at=dibuat_pada,
    )
    db.add(transaksi)
    await db.flush()
    return transaksi


async def catat_transfer_kepemilikan(db: AsyncSession, transaksi: Transaksi) -> KepemilikanKarya:
    """Tutup kepemilikan AKTIF sebelumnya (kalau ada, ``dilepas_at`` diisi) + buka baris
    kepemilikan baru utk ``transaksi.pembeli_id``. WAJIB dipanggil HANYA saat
    ``transaksi.status == SELESAI`` (caller bertanggung jawab memastikan ini -- fungsi ini
    sendiri tidak mengecek status, supaya tetap murni/mudah diuji).

    Partial unique index di DB (``kepemilikan_karya``, ``WHERE dilepas_at IS NULL``) menjamin
    di level database tidak mungkin ada 2 "pemilik aktif" bersamaan utk 1 karya -- kalau fungsi
    ini dipanggil dgn urutan salah (mis. lupa menutup kepemilikan lama), INSERT akan gagal
    oleh constraint itu, bukan diam-diam membuat data tidak konsisten.
    """
    aktif = await db.scalar(
        select(KepemilikanKarya).where(
            KepemilikanKarya.karya_id == transaksi.karya_id,
            KepemilikanKarya.dilepas_at.is_(None),
        )
    )
    sekarang = datetime.now(timezone.utc)
    if aktif is not None:
        aktif.dilepas_at = sekarang

    baru = KepemilikanKarya(
        karya_id=transaksi.karya_id,
        pemilik_id=transaksi.pembeli_id,
        sumber=SumberKepemilikan.PEMBELIAN,
        transaksi_id=transaksi.id,
        diperoleh_at=sekarang,
    )
    db.add(baru)
    await db.flush()
    return baru
