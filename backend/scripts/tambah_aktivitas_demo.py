"""Tambahan akun DEMO Aria Wijaya: event, komunitas, dan lelang (untuk screenshot mockup/poster).

Butuh akun dari ``scripts.siapkan_akun_demo`` (seniman + 12 kolektor ``@demo.galeria.test``) sudah ada.
Ini DATA CONTOH di database yang sama dengan data asli: jangan dipakai untuk klaim performa.

    python -m scripts.tambah_aktivitas_demo           # tambah
    python -m scripts.tambah_aktivitas_demo --hapus   # hapus hanya aktivitas ini (akun & karya tetap)

Dibuat: 2 komunitas (1 terbuka ramai, 1 tertutup dgn 1 permintaan gabung) + postingan/suka/komentar,
4 event (1 sudah selesai, 1 online gratis, 2 offline berbayar) + tiket terjual & check-in,
3 lelang (2 berlangsung dgn riwayat bid, 1 akan datang) memakai karya yang masih tersedia.
``siapkan_akun_demo --hapus`` juga memanggil pembersihan ini otomatis.
"""

from __future__ import annotations

import asyncio
import random
import string
import sys
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, text

from database import _session_factory, engine
from models.event import Event, EventKarya, EventPesanan, EventTiket, EventTiketPembelian, StatusEvent, StatusTiketPembelian
from models.karya import Karya
from models.komunitas import Komunitas, KomunitasAnggota, KomunitasKomentar, KomunitasLike, KomunitasPost
from models.lelang import Lelang, LelangBid, StatusLelang
from models.user import User
from scripts.siapkan_akun_demo import DOMAIN, SENIMAN_EMAIL

NOW = datetime.now(timezone.utc)
KOMUNITAS_NAMA = ("Sanggar Aria Surabaya", "Pelukis Muda Jatim")


def _kode(rnd: random.Random) -> str:
    return "GAL-" + "".join(rnd.choices(string.ascii_uppercase + string.digits, k=10))


async def hapus_aktivitas(db, ids: list[uuid.UUID], termasuk_transaksi: bool = False) -> None:
    """Hapus event/komunitas/lelang milik atau melibatkan akun demo ``ids`` (urutan menghormati FK RESTRICT).

    Lelang yang sudah punya pesanan (``transaksi.lelang_id``) hanya ikut terhapus bila ``termasuk_transaksi``
    (dipakai ``siapkan_akun_demo --hapus``, yang memang menghapus transaksi demo)."""
    p = {"ids": ids}
    pra: tuple[str, ...] = ()
    if termasuk_transaksi:  # transaksi menunjuk lelang (RESTRICT) -> hapus dulu beserta turunannya
        pra = (
            "DELETE FROM ulasan WHERE seniman_id = ANY(:ids) OR pembeli_id = ANY(:ids)",
            "DELETE FROM kepemilikan_karya WHERE pemilik_id = ANY(:ids) OR karya_id IN (SELECT id FROM karya WHERE seniman_id = ANY(:ids))",
            "DELETE FROM notifikasi WHERE user_id = ANY(:ids)",
            "DELETE FROM karya_promosi WHERE seniman_id = ANY(:ids)",   # promosi menunjuk tagihan (RESTRICT)
            "DELETE FROM tagihan WHERE user_id = ANY(:ids)",
            "DELETE FROM transaksi WHERE penjual_id = ANY(:ids) OR pembeli_id = ANY(:ids)",
        )
    sisa_lelang = "" if termasuk_transaksi else " AND id NOT IN (SELECT lelang_id FROM transaksi WHERE lelang_id IS NOT NULL)"
    for sql in pra + (
        "DELETE FROM lelang_bids WHERE lelang_id IN (SELECT id FROM lelang WHERE karya_id IN (SELECT id FROM karya WHERE seniman_id = ANY(:ids))" + sisa_lelang + ")"
        " OR (bidder_id = ANY(:ids) AND lelang_id NOT IN (SELECT lelang_id FROM transaksi WHERE lelang_id IS NOT NULL))",
        "DELETE FROM lelang WHERE karya_id IN (SELECT id FROM karya WHERE seniman_id = ANY(:ids))" + sisa_lelang,
        "DELETE FROM event_tiket_pembelian WHERE pembeli_id = ANY(:ids)",
        "DELETE FROM event_pesanan WHERE pembeli_id = ANY(:ids) OR event_id IN (SELECT id FROM events WHERE komunitas_id = ANY(:ids))",
        "DELETE FROM event_karya WHERE event_id IN (SELECT id FROM events WHERE komunitas_id = ANY(:ids))",
        "DELETE FROM events WHERE komunitas_id = ANY(:ids)",
        "DELETE FROM komunitas_komentar WHERE penulis_id = ANY(:ids)",
        "DELETE FROM komunitas_post WHERE penulis_id = ANY(:ids) OR komunitas_id IN (SELECT id FROM komunitas WHERE pemilik_id = ANY(:ids))",
        "DELETE FROM komunitas WHERE pemilik_id = ANY(:ids)",
    ):
        await db.execute(text(sql), p)


async def tambah() -> None:
    rnd = random.Random(77)
    async with _session_factory() as db:
        sen = (await db.execute(select(User).where(User.email == SENIMAN_EMAIL))).scalar_one_or_none()
        if sen is None:
            raise SystemExit("Akun demo belum ada. Jalankan `python -m scripts.siapkan_akun_demo` dulu.")
        if (await db.execute(select(Komunitas.id).where(Komunitas.pemilik_id == sen.id))).first():
            raise SystemExit("Aktivitas demo sudah ada. Jalankan dengan --hapus dulu bila ingin membuat ulang.")
        pembeli = list((await db.execute(select(User).where(User.email.like(f"kolektor%{DOMAIN}")).order_by(User.email))).scalars())
        if len(pembeli) < 8:
            raise SystemExit("Pembeli demo kurang dari 8; jalankan siapkan_akun_demo.")

        # karya yang masih tersedia (belum ada transaksi)
        tersedia = list((await db.execute(
            select(Karya).where(Karya.seniman_id == sen.id, Karya.deleted_at.is_(None),
                                ~Karya.id.in_(text("SELECT karya_id FROM transaksi"))).order_by(Karya.created_at)
        )).scalars())
        if len(tersedia) < 4:
            raise SystemExit("Karya tersedia kurang dari 4.")

        # ------------------------------------------------------------------ komunitas
        k1 = Komunitas(id=uuid.uuid4(), pemilik_id=sen.id, nama=KOMUNITAS_NAMA[0], terbuka=True,
                       aliran=["Impressionism", "Post Impressionism", "Romanticism"],
                       deskripsi="Wadah pelukis dan pecinta seni rupa di Surabaya untuk berbagi proses, kritik, dan kabar pameran.",
                       aturan="Saling menghargai karya. Tidak boleh mengunggah karya orang lain tanpa izin. Promosi hanya di kolom pengumuman.",
                       created_at=NOW - timedelta(days=75))
        k2 = Komunitas(id=uuid.uuid4(), pemilik_id=sen.id, nama=KOMUNITAS_NAMA[1], terbuka=False,
                       aliran=["Expressionism", "Cubism"],
                       deskripsi="Kelompok kurasi tertutup untuk seniman muda Jawa Timur. Anggota baru diseleksi pemilik.",
                       aturan="Anggota wajib mengunggah minimal satu karya terverifikasi di GALERIA.",
                       created_at=NOW - timedelta(days=30))
        db.add_all([k1, k2])
        await db.flush()
        db.add(KomunitasAnggota(komunitas_id=k1.id, user_id=sen.id, peran="pemilik", status="aktif", bergabung_at=k1.created_at))
        db.add(KomunitasAnggota(komunitas_id=k2.id, user_id=sen.id, peran="pemilik", status="aktif", bergabung_at=k2.created_at))
        for i, u in enumerate(pembeli[:9]):
            db.add(KomunitasAnggota(komunitas_id=k1.id, user_id=u.id, peran="anggota", status="aktif",
                                    bergabung_at=NOW - timedelta(days=70 - i * 6)))
        for u in pembeli[9:11]:
            db.add(KomunitasAnggota(komunitas_id=k2.id, user_id=u.id, peran="anggota", status="aktif", bergabung_at=NOW - timedelta(days=20)))
        db.add(KomunitasAnggota(komunitas_id=k2.id, user_id=pembeli[11].id, peran="anggota", status="menunggu", bergabung_at=NOW - timedelta(days=1)))

        posts_teks = [
            (sen, True, 14, "Selamat datang di Sanggar Aria Surabaya! Pekan depan kita adakan pameran kecil. Detail tiket ada di menu Event, ya."),
            (pembeli[0], False, 11, "Baru selesai satu kanvas lanskap pagi hari. Masih mencari komposisi cahaya yang pas, ada saran untuk warna langitnya?"),
            (sen, False, 8, "Tips: lapisi cat minyak tipis-tipis dulu (fat over lean) supaya tidak mudah retak saat mengering."),
            (pembeli[3], False, 5, "Terima kasih Kak Aria untuk sesi live painting kemarin, banyak ilmu baru soal teknik glazing."),
            (pembeli[5], False, 2, "Ada yang tahu toko kanvas bagus di Malang? Butuh ukuran 80x100 untuk karya berikutnya."),
        ]
        posts: list[KomunitasPost] = []
        for pen, sem, hari, teks in posts_teks:
            po = KomunitasPost(id=uuid.uuid4(), komunitas_id=k1.id, penulis_id=pen.id, teks=teks, disematkan=sem, created_at=NOW - timedelta(days=hari))
            db.add(po)
            posts.append(po)
        await db.flush()
        for pi, po in enumerate(posts):
            for u in rnd.sample(pembeli[:9], rnd.randint(2, 6)):
                db.add(KomunitasLike(post_id=po.id, user_id=u.id, created_at=po.created_at + timedelta(hours=rnd.randint(1, 30))))
        komentar = [
            (1, pembeli[2], "Coba tambah sedikit kuning pucat di dekat horizon, biasanya langit jadi lebih hangat."),
            (1, sen, "Setuju dengan Dimas. Kamu juga bisa mencampur sedikit oker supaya tidak terlalu cerah."),
            (2, pembeli[1], "Terima kasih tipsnya, Kak! Langsung dicoba di kanvas berikutnya."),
            (3, sen, "Sama-sama, senang kalian antusias! Sesi berikutnya kita bahas pewarnaan bayangan."),
            (4, pembeli[4], "Coba cek toko seni di sekitar Pasar Besar, harganya cukup bersahabat."),
        ]
        for idx, pen, teks in komentar:
            db.add(KomunitasKomentar(id=uuid.uuid4(), post_id=posts[idx].id, penulis_id=pen.id, teks=teks,
                                     created_at=posts[idx].created_at + timedelta(hours=rnd.randint(2, 20))))

        # ------------------------------------------------------------------ event
        def event(judul, tema, fmt, kota, nama_lokasi, alamat, mulai_hari, durasi_jam, deskripsi, status=StatusEvent.DIPUBLIKASIKAN, link=None):
            mulai = NOW + timedelta(days=mulai_hari)
            return Event(id=uuid.uuid4(), komunitas_id=sen.id, komunitas_ref_id=k1.id, judul=judul, tema=tema, format=fmt,
                         lokasi=nama_lokasi if fmt == "offline" else "Online", nama_lokasi=nama_lokasi, alamat=alamat, kota=kota,
                         link_online=link, mulai_at=mulai, selesai_at=mulai + timedelta(hours=durasi_jam), status=status,
                         deskripsi=deskripsi, created_at=mulai - timedelta(days=rnd.randint(14, 30)))

        e_pameran = event("Pameran Senja di Teluk", "Pameran Lukisan", "offline", "Surabaya", "Galeri Seni Kota Lama",
                          "Jl. Veteran No. 12, Surabaya", 10, 6,
                          "Pameran 20 lukisan bergaya impresionis karya Aria Wijaya dan seniman undangan, lengkap dengan sertifikat keaslian digital untuk setiap karya.")
        e_workshop = event("Workshop Cat Minyak untuk Pemula", "Workshop", "offline", "Surabaya", "Sanggar Aria",
                           "Jl. Darmo Permai III No. 7, Surabaya", 21, 4,
                           "Belajar dasar mencampur warna, sapuan kuas, dan komposisi. Semua peralatan disediakan, peserta dibatasi agar tiap orang terbimbing.")
        e_live = event("Live Painting & Diskusi Seniman", "Live Painting", "online", None, "Online", None, 5, 2,
                       "Saksikan proses melukis langsung dan tanya jawab seputar karier seniman di era digital.", link="https://meet.example.com/galeria-live-aria")
        e_lalu = event("Pameran Tahunan Sanggar Aria", "Pameran Lukisan", "offline", "Surabaya", "Balai Pemuda",
                       "Jl. Gubernur Suryo No. 15, Surabaya", -30, 8,
                       "Pameran tahunan perdana Sanggar Aria: 35 karya dari 12 seniman anggota.", status=StatusEvent.SELESAI)
        semua_event = [e_pameran, e_workshop, e_live, e_lalu]
        db.add_all(semua_event)
        await db.flush()

        def tiket(e, nama, harga, kuota, ket):
            t = EventTiket(id=uuid.uuid4(), event_id=e.id, nama_tiket=nama, harga_idr=harga, kuota=kuota, keterangan=ket)
            db.add(t)
            return t

        t_reg = tiket(e_pameran, "Reguler", 50_000, 100, "Akses pameran sepanjang hari")
        t_vip = tiket(e_pameran, "VIP", 150_000, 30, "Akses pameran + sesi temu seniman + katalog cetak")
        t_ws = tiket(e_workshop, "Peserta", 175_000, 25, "Termasuk peralatan melukis & kanvas 30x40")
        t_live = tiket(e_live, "Gratis", 0, 200, "Tautan dikirim setelah mendaftar")
        t_lalu = tiket(e_lalu, "Reguler", 40_000, 150, "Tiket masuk pameran")
        await db.flush()
        for e, ks in ((e_pameran, tersedia[:4]), (e_lalu, tersedia[:3]), (e_workshop, tersedia[:1])):
            for k in ks:
                db.add(EventKarya(event_id=e.id, karya_id=k.id))

        def beli(e, t, u, jumlah, hari_lalu, checkin=False):
            total = t.harga_idr * jumlah
            dibayar = NOW - timedelta(days=hari_lalu)
            pes = EventPesanan(id=uuid.uuid4(), event_id=e.id, event_tiket_id=t.id, pembeli_id=u.id, jumlah=jumlah, harga_satuan_idr=t.harga_idr,
                               total_idr=total, nama_pemegang=u.display_name, status="dibayar",
                               metode_pembayaran=rnd.choice(["va_bca", "qris", "va_mandiri"]) if total else None,
                               referensi_pembayaran=f"DEMO{rnd.randint(10**9, 10**10 - 1)}" if total else None,
                               batas_bayar_at=dibayar + timedelta(minutes=30), dibayar_at=dibayar, created_at=dibayar - timedelta(minutes=10))
            db.add(pes)
            return pes, [EventTiketPembelian(id=uuid.uuid4(), event_tiket_id=t.id, pembeli_id=u.id, kode_tiket=_kode(rnd), pesanan_id=pes.id,
                                             nama_pemegang=u.display_name, created_at=dibayar,
                                             status=StatusTiketPembelian.TERPAKAI if checkin else StatusTiketPembelian.AKTIF,
                                             checkin_at=(e.mulai_at + timedelta(minutes=rnd.randint(5, 90))) if checkin else None)
                         for _ in range(jumlah)]

        jual = []
        for i, u in enumerate(pembeli[:8]):
            jual.append(beli(e_pameran, t_vip if i < 2 else t_reg, u, rnd.randint(1, 3), rnd.randint(1, 8)))
        for u in pembeli[:5]:
            jual.append(beli(e_workshop, t_ws, u, 1, rnd.randint(1, 6)))
        for u in pembeli:
            jual.append(beli(e_live, t_live, u, 1, rnd.randint(0, 3)))
        for i, u in enumerate(pembeli[:10]):
            jual.append(beli(e_lalu, t_lalu, u, rnd.randint(1, 2), 30 + rnd.randint(0, 4), checkin=(i != 9)))
        await db.flush()
        for _, tikets in jual:
            db.add_all(tikets)

        # ------------------------------------------------------------------ lelang
        def lelang(k, awal, kelipatan, mulai_hari, selesai_hari, status):
            return Lelang(id=uuid.uuid4(), karya_id=k.id, harga_awal_idr=awal, kelipatan_bid_idr=kelipatan,
                          mulai_at=NOW + timedelta(days=mulai_hari), selesai_at=NOW + timedelta(days=selesai_hari), status=status)

        l1 = lelang(tersedia[0], 3_000_000, 100_000, -2, 2, StatusLelang.BERLANGSUNG)
        l2 = lelang(tersedia[1], 5_000_000, 250_000, -1, 5, StatusLelang.BERLANGSUNG)
        l3 = lelang(tersedia[2], 4_000_000, 200_000, 3, 7, StatusLelang.AKAN_DATANG)
        db.add_all([l1, l2, l3])
        await db.flush()
        bids = [
            (l1, [(0, 3_000_000), (1, 3_100_000), (0, 3_300_000), (2, 3_500_000), (1, 3_800_000), (3, 4_000_000)]),
            (l2, [(4, 5_000_000), (5, 5_250_000), (4, 5_750_000)]),
        ]
        for l, daftar in bids:
            span = (NOW - l.mulai_at) - timedelta(hours=1)
            for n, (pi, jumlah) in enumerate(daftar):
                db.add(LelangBid(id=uuid.uuid4(), lelang_id=l.id, bidder_id=pembeli[pi].id, jumlah_idr=jumlah,
                                 created_at=l.mulai_at + span * (n + 1) / (len(daftar) + 1)))
        await db.commit()

    await engine.dispose()
    print("Ditambahkan ke akun Aria Wijaya:")
    print(f"  komunitas : {len(KOMUNITAS_NAMA)} ({len(posts)} postingan, 9+2 anggota, 1 permintaan gabung)")
    print(f"  event     : {len(semua_event)} (1 selesai, 1 online gratis, 2 offline berbayar), {sum(len(t) for _, t in jual)} tiket")
    print("  lelang    : 3 (2 berlangsung dengan bid, 1 akan datang)")


async def hapus() -> None:
    async with _session_factory() as db:
        sen_id = (await db.execute(select(User.id).where(User.email == SENIMAN_EMAIL))).scalar_one_or_none()
        if sen_id is None:
            print("Tidak ada akun demo.")
            return
        ids = [r[0] for r in (await db.execute(text("SELECT id FROM users WHERE email LIKE :p"), {"p": f"%{DOMAIN}"})).all()]
        await hapus_aktivitas(db, ids)
        await db.commit()
    await engine.dispose()
    print("Event, komunitas, dan lelang demo dihapus (akun & karya tetap).")


if __name__ == "__main__":
    asyncio.run(hapus() if "--hapus" in sys.argv else tambah())
