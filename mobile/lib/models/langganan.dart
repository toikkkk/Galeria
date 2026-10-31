/// Model langganan, promosi, dan tagihan (cermin `schemas/langganan.py` di backend).
library;

import 'pesanan.dart';

DateTime _t(dynamic v) => DateTime.parse(v as String).toLocal();

class Paket {
  const Paket({required this.plan, required this.nama, required this.hargaIdr, required this.durasiHari, required this.untuk, required this.manfaat});

  final String plan, nama;
  final int hargaIdr, durasiHari;
  final List<String> untuk, manfaat;

  factory Paket.fromJson(Map<String, dynamic> j) => Paket(
        plan: j['plan'] as String,
        nama: j['nama'] as String,
        hargaIdr: j['harga_idr'] as int,
        durasiHari: j['durasi_hari'] as int,
        untuk: (j['untuk'] as List).cast<String>(),
        manfaat: (j['manfaat'] as List).cast<String>(),
      );
}

class HargaPromosi {
  const HargaPromosi({required this.durasiHari, required this.hargaIdr});

  final int durasiHari, hargaIdr;

  factory HargaPromosi.fromJson(Map<String, dynamic> j) => HargaPromosi(durasiHari: j['durasi_hari'] as int, hargaIdr: j['harga_idr'] as int);
}

class KatalogPaket {
  const KatalogPaket({required this.paket, required this.promosi});

  final List<Paket> paket;
  final List<HargaPromosi> promosi;

  Paket? cari(String plan) => paket.where((p) => p.plan == plan).firstOrNull;

  factory KatalogPaket.fromJson(Map<String, dynamic> j) => KatalogPaket(
        paket: (j['paket'] as List).cast<Map<String, dynamic>>().map(Paket.fromJson).toList(),
        promosi: (j['promosi'] as List).cast<Map<String, dynamic>>().map(HargaPromosi.fromJson).toList(),
      );
}

class LanggananAktif {
  const LanggananAktif({required this.plan, required this.nama, required this.berakhir, required this.sisaHari});

  final String plan, nama;
  final DateTime berakhir;
  final int sisaHari;

  factory LanggananAktif.fromJson(Map<String, dynamic> j) => LanggananAktif(
        plan: j['plan'] as String,
        nama: j['nama'] as String,
        berakhir: _t(j['berakhir_at']),
        sisaHari: j['sisa_hari'] as int,
      );
}

class LanggananSaya {
  const LanggananSaya({required this.aktif, required this.pro, required this.ar});

  static const kosong = LanggananSaya(aktif: [], pro: false, ar: false);

  final List<LanggananAktif> aktif;
  final bool pro, ar;

  factory LanggananSaya.fromJson(Map<String, dynamic> j) => LanggananSaya(
        aktif: (j['aktif'] as List).cast<Map<String, dynamic>>().map(LanggananAktif.fromJson).toList(),
        pro: j['pro'] as bool,
        ar: j['ar'] as bool,
      );
}

class Tagihan {
  const Tagihan({
    required this.id,
    required this.jenis,
    required this.judul,
    required this.jumlahIdr,
    required this.status,
    required this.statusLabel,
    required this.aksi,
    this.instruksi,
    this.batasBayarAt,
  });

  final String id, jenis, judul, status, statusLabel;
  final int jumlahIdr;
  final List<String> aksi;
  final InstruksiBayar? instruksi;
  final DateTime? batasBayarAt;

  bool get lunas => status == 'dibayar';

  factory Tagihan.fromJson(Map<String, dynamic> j) {
    final ins = j['instruksi_bayar'] as Map<String, dynamic>?;
    return Tagihan(
      id: j['id'] as String,
      jenis: j['jenis'] as String,
      judul: j['judul'] as String,
      jumlahIdr: j['jumlah_idr'] as int,
      status: j['status'] as String,
      statusLabel: j['status_label'] as String,
      aksi: (j['aksi'] as List? ?? const []).cast<String>(),
      instruksi: ins == null ? null : InstruksiBayar.fromJson(ins),
      batasBayarAt: j['batas_bayar_at'] == null ? null : _t(j['batas_bayar_at']),
    );
  }
}

class PromosiKarya {
  const PromosiKarya({required this.id, required this.karyaId, required this.judulKarya, required this.durasiHari, required this.hargaIdr, required this.diBeranda, required this.diLelang, required this.berakhir, required this.aktif});

  final String id, karyaId, judulKarya;
  final int durasiHari, hargaIdr;
  final bool diBeranda, diLelang, aktif;
  final DateTime berakhir;

  factory PromosiKarya.fromJson(Map<String, dynamic> j) => PromosiKarya(
        id: j['id'] as String,
        karyaId: j['karya_id'] as String,
        judulKarya: j['judul_karya'] as String,
        durasiHari: j['durasi_hari'] as int,
        hargaIdr: j['harga_idr'] as int,
        diBeranda: j['di_beranda'] as bool,
        diLelang: j['di_lelang'] as bool,
        berakhir: _t(j['berakhir_at']),
        aktif: j['aktif'] as bool,
      );
}
