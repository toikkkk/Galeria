"""Menghidupkan SEMUA fitur untuk dua akun demo utama (Aria Wijaya = seniman, Budi Santoso = kolektor01).

Butuh ``siapkan_akun_demo`` + ``tambah_aktivitas_demo`` + ``tambah_koleksi_demo`` sudah dijalankan.

Yang ditambahkan (semuanya data CONTOH di database yang sama dengan data asli; pembayaran = riwayat simulasi):
  Aria  : Seniman PRO aktif 1 tahun (buat event, promosi karya), 2 karya dipromosikan (tampil di depan beranda & lelang),
          2 pesanan masuk baru dari Budi (satu menunggu bayar, satu sedang dikirim), 7 notifikasi.
  Budi  : Akses AR aktif 1 tahun (fitur AR terbuka), 3 karya di keranjang, pesanan menunggu bayar + pesanan dikirim,
          6 notifikasi.

    python -m scripts.aktifkan_fitur_demo
Hapus: ``python -m scripts.siapkan_akun_demo --hapus`` (ikut membersihkan semuanya).
"""

from __future__ import annotations

import asyncio
import hashlib
import random
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, text

from database import _session_factory, engine
from models.engagement import (
    KeranjangItem, Notifikasi, PlanSubscription, StatusSubscription, Subscription, TipeNotifikasi,
)
from models.event import Event
from models.karya import Karya, StatusVerifikasiKarya
from models.komunitas import Komunitas
from models.langganan import KaryaPromosi, Tagihan
from models.lelang import Lelang, StatusLelang
from models.sertifikat import SigningKey
from models.user import AlamatPengiriman, User
from scripts.siapkan_akun_demo import DASAR, DOMAIN, _isi_siklus, _tanda_tangan_transaksi, _varian
from services import storage
from services.kripto import muat_private_key
from services.langganan_service import HARGA_PROMOSI, daftar_paket
from services.sertifikat_service import terbitkan_sertifikat

NOW = datetime.now(timezone.utc)
ARIA = f"aria.wijaya{DOMAIN}"
BUDI = f"kolektor01{DOMAIN}"
PENANDA = "Kapal di Dermaga Senja"   # karya baru; keberadaannya = skrip ini sudah pernah jalan


def _tagihan_lunas(user: User, jenis: str, judul: str, jumlah: int, payload: dict, dibayar: datetime) -> Tagihan:
    return Tagihan(id=uuid.uuid4(), user_id=user.id, jenis=jenis, judul=judul, jumlah_idr=jumlah, payload=payload,
                   status="dibayar", metode_pembayaran="qris", referensi_pembayaran=f"DEMO{uuid.uuid4().int % 10**10:010d}",
                   batas_bayar_at=dibayar + timedelta(minutes=30), dibayar_at=dibayar, created_at=dibayar - timedelta(minutes=5))


def _notif(user: User, tipe: TipeNotifikasi, judul: str, isi: str, tautan: str | None, jam_lalu: float, baca: bool) -> Notifikasi:
    return Notifikasi(id=uuid.uuid4(), user_id=user.id, tipe=tipe, judul=judul, isi=isi, tautan=tautan,
                      is_read=baca, created_at=NOW - timedelta(hours=jam_lalu))


async def aktifkan() -> None:
    rnd = random.Random(808)
    async with _session_factory() as db:
        aria = (await db.execute(select(User).where(User.email == ARIA))).scalar_one_or_none()
        budi = (await db.execute(select(User).where(User.email == BUDI))).scalar_one_or_none()
        if aria is None or budi is None:
            raise SystemExit("Akun demo belum ada. Jalankan siapkan_akun_demo, tambah_aktivitas_demo, tambah_koleksi_demo dulu.")
        if (await db.execute(select(Karya.id).where(Karya.seniman_id == aria.id, Karya.title == PENANDA))).first():
            raise SystemExit("Fitur demo sudah diaktifkan. Jalankan `python -m scripts.siapkan_akun_demo --hapus` dulu bila ingin membuat ulang semuanya.")
        key = await db.scalar(select(SigningKey).where(SigningKey.is_active.is_(True)))
        if key is None:
            raise SystemExit("Tidak ada signing key aktif.")
        muat_private_key(key.kms_key_ref)
        alamat = (await db.execute(select(AlamatPengiriman).where(AlamatPengiriman.user_id == budi.id))).scalars().first()
        if alamat is None:
            raise SystemExit("Budi belum punya alamat.")
        paket = {p.plan: p for p in daftar_paket()}

        # ---------------------------------------------------------------- langganan
        pro = await db.scalar(select(Subscription).where(
            Subscription.user_id == aria.id, Subscription.plan_type == PlanSubscription.KOMUNITAS_PRO,
            Subscription.status == StatusSubscription.AKTIF).order_by(Subscription.berakhir_at.desc()).limit(1))
        if pro is not None:
            pro.berakhir_at = NOW + timedelta(days=365)
        else:
            db.add(Subscription(id=uuid.uuid4(), user_id=aria.id, plan_type=PlanSubscription.KOMUNITAS_PRO,
                                status=StatusSubscription.AKTIF, mulai_at=NOW, berakhir_at=NOW + timedelta(days=365)))
        p = paket.get("komunitas_pro")
        db.add(_tagihan_lunas(aria, "langganan", p.nama if p else "Seniman PRO", p.harga_idr if p else 149_000,
                              {"plan": "komunitas_pro"}, NOW - timedelta(days=2)))
        db.add(Subscription(id=uuid.uuid4(), user_id=budi.id, plan_type=PlanSubscription.AR_AKSES,
                            status=StatusSubscription.AKTIF, mulai_at=NOW, berakhir_at=NOW + timedelta(days=365)))
        p = paket.get("ar_akses")
        db.add(_tagihan_lunas(budi, "langganan", p.nama if p else "Akses AR", p.harga_idr if p else 49_000,
                              {"plan": "ar_akses"}, NOW - timedelta(days=2)))

        # ---------------------------------------------------------------- 2 karya baru Aria -> pesanan Budi
        baru: list[tuple[Karya, str, int]] = []
        for judul, idx_dasar, harga, tahap in ((PENANDA, 0, 4_300_000, "menunggu"), ("Musim Semi di Lembah", 4, 3_600_000, "dikirim")):
            berkas, gaya = DASAR[idx_dasar]
            isi = _varian(berkas, idx_dasar, rnd)
            kid = uuid.uuid4()
            k_key = f"karya/{kid}.jpg"
            await storage.unggah(k_key, isi, "image/jpeg")
            k = Karya(id=kid, seniman_id=aria.id, title=judul, artist_name=aria.display_name, gallery_name="Sanggar Aria", style_name=gaya,
                      price_idr=harga, image_filename=f"{kid}.jpg", image_key=k_key, lebar_cm=rnd.choice([50, 60, 70]),
                      tinggi_cm=rnd.choice([60, 70, 80]), file_hash=hashlib.sha256(isi).hexdigest(),
                      status_verifikasi=StatusVerifikasiKarya.TERVERIFIKASI,
                      created_at=(NOW - timedelta(days=rnd.randint(10, 25))).replace(tzinfo=None),
                      deskripsi=f"{judul}: karya bergaya {gaya}, cat minyak di atas kanvas. Dikerjakan langsung oleh seniman.")
            db.add(k)
            baru.append((k, tahap, harga))
        await db.flush()
        transaksi = {}
        for k, tahap, harga in baru:
            await terbitkan_sertifikat(db, k, "lolos", "lolos")
            dibuat = NOW - timedelta(hours=3) if tahap == "menunggu" else NOW - timedelta(days=4)
            t = await _tanda_tangan_transaksi(db, key, k, budi, harga, dibuat)
            _isi_siklus(t, alamat, tahap, dibuat, rnd, "")
            t.created_at = dibuat
            transaksi[tahap] = (t, k)

        # ---------------------------------------------------------------- promosi + keranjang (karya Aria yang masih bebas)
        bebas = [r[0] for r in (await db.execute(text("""
            SELECT k.id FROM karya k
            WHERE k.seniman_id = :a AND k.deleted_at IS NULL AND k.status_verifikasi = 'terverifikasi'
              AND NOT EXISTS (SELECT 1 FROM transaksi t WHERE t.karya_id = k.id)
              AND NOT EXISTS (SELECT 1 FROM lelang l WHERE l.karya_id = k.id AND l.status IN ('akan_datang','berlangsung'))
            ORDER BY k.created_at"""), {"a": aria.id})).all()]
        n_promosi = 0
        for kid, durasi in zip(bebas[:2], (14, 30)):
            harga = HARGA_PROMOSI[durasi]
            tg = _tagihan_lunas(aria, "promosi", f"Promosi karya · {durasi} hari", harga,
                                {"karya_id": str(kid), "durasi_hari": durasi, "di_beranda": True, "di_lelang": True}, NOW - timedelta(days=1))
            db.add(tg)
            await db.flush()
            db.add(KaryaPromosi(id=uuid.uuid4(), karya_id=kid, seniman_id=aria.id, tagihan_id=tg.id, durasi_hari=durasi,
                                harga_idr=harga, di_beranda=True, di_lelang=True, mulai_at=NOW - timedelta(days=1),
                                berakhir_at=NOW - timedelta(days=1) + timedelta(days=durasi)))
            n_promosi += 1
        for kid in bebas[:3]:
            db.add(KeranjangItem(user_id=budi.id, karya_id=kid))

        # ---------------------------------------------------------------- notifikasi
        lelang = (await db.execute(select(Lelang).join(Karya, Karya.id == Lelang.karya_id)
                                   .where(Karya.seniman_id == aria.id, Lelang.status == StatusLelang.BERLANGSUNG)
                                   .order_by(Lelang.mulai_at))).scalars().first()
        ev = (await db.execute(select(Event).where(Event.komunitas_id == aria.id).order_by(Event.mulai_at))).scalars().first()
        kom = (await db.execute(select(Komunitas).where(Komunitas.pemilik_id == aria.id).order_by(Komunitas.created_at))).scalars().all()
        tm, km = transaksi["menunggu"]
        td, kd = transaksi["dikirim"]
        L = f"lelang:{lelang.id}" if lelang else None
        E = f"event:{ev.id}" if ev else None
        K1 = f"komunitas:{kom[0].id}" if kom else None
        K2 = f"komunitas:{kom[-1].id}" if kom else None
        for n in (
            _notif(aria, TipeNotifikasi.TRANSAKSI, "Pesanan baru dari Budi Santoso", f'"{km.title}" menunggu pembayaran pembeli.', f"pesanan:{tm.id}", 3, False),
            _notif(aria, TipeNotifikasi.LELANG, "Tawaran baru untuk lelangmu", "Ada tawaran lebih tinggi pada lelang yang sedang berlangsung.", L, 5, False),
            _notif(aria, TipeNotifikasi.EVENT, "Tiket event terjual", "Tiket Pameran Senja di Teluk terus terjual. Cek daftar peserta.", E, 9, False),
            _notif(aria, TipeNotifikasi.KOMUNITAS, "Permintaan bergabung baru", "Satu orang meminta bergabung ke komunitas tertutupmu.", K2, 20, False),
            _notif(aria, TipeNotifikasi.TRANSAKSI, "Pesanan sedang dikirim", f'"{kd.title}" sudah kamu kirim. Menunggu konfirmasi pembeli.', f"pesanan:{td.id}", 70, True),
            _notif(aria, TipeNotifikasi.VERIFIKASI_KARYA, "Karya terverifikasi", f'"{kd.title}" lolos verifikasi dan sertifikat digitalnya terbit.', f"karya:{kd.id}", 120, True),
            _notif(aria, TipeNotifikasi.SISTEM, "Seniman PRO aktif", "Langgananmu aktif. Buat event dan promosikan karya tanpa batas fitur.", None, 48, True),
            _notif(budi, TipeNotifikasi.TRANSAKSI, "Menunggu pembayaran", f'Selesaikan pembayaran "{km.title}" agar pesanan diproses.', f"pesanan:{tm.id}", 3, False),
            _notif(budi, TipeNotifikasi.TRANSAKSI, "Pesananmu dikirim", f'"{kd.title}" sedang dalam perjalanan. Konfirmasi setelah diterima.', f"pesanan:{td.id}", 30, False),
            _notif(budi, TipeNotifikasi.LELANG, "Tawaranmu terlampaui", "Ada tawaran lebih tinggi. Tawar lagi sebelum lelang berakhir.", L, 6, False),
            _notif(budi, TipeNotifikasi.EVENT, "Pengingat event", "Pameran Senja di Teluk segera dimulai. Siapkan e-tiketmu.", E, 12, True),
            _notif(budi, TipeNotifikasi.KOMUNITAS, "Postingan baru di komunitas", "Aria Wijaya membagikan tips cat minyak di Sanggar Aria Surabaya.", K1, 40, True),
            _notif(budi, TipeNotifikasi.SISTEM, "Akses AR aktif", "Coba lukisan di ruanganmu dengan AR tanpa batas.", None, 48, True),
        ):
            db.add(n)
        await db.commit()

    await engine.dispose()
    print("Aria  : Seniman PRO aktif 1 tahun | %d karya dipromosikan | +2 pesanan masuk dari Budi | 7 notifikasi" % n_promosi)
    print("Budi  : Akses AR aktif 1 tahun | %d karya di keranjang | pesanan menunggu bayar + dikirim | 6 notifikasi" % len(bebas[:3]))


if __name__ == "__main__":
    asyncio.run(aktifkan())
