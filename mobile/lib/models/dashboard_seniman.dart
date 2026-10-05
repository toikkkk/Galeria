/// Model respons `GET /api/dashboard/...` (lihat backend/schemas/dashboard.py).
/// Uang = integer Rupiah; persen = angka biasa (12.5 = 12,5%), null bila tak ada pembanding.
library;

int _i(dynamic v) => (v as num).toInt();
double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

class SenimanDemo {
  const SenimanDemo({required this.id, required this.displayName, required this.levelReputasi, required this.nTerjual});

  final String id, displayName, levelReputasi;
  final int nTerjual;

  factory SenimanDemo.fromJson(Map<String, dynamic> j) => SenimanDemo(
        id: j['id'] as String,
        displayName: j['display_name'] as String,
        levelReputasi: j['level_reputasi'] as String,
        nTerjual: _i(j['n_terjual']),
      );
}

class RingkasanSeniman {
  const RingkasanSeniman({
    required this.id,
    required this.displayName,
    required this.levelReputasi,
    required this.periodeHari,
    required this.nTerjual,
    required this.omzetIdr,
    required this.komisiPlatformIdr,
    required this.pendapatanBersihIdr,
    required this.hargaRata2Idr,
    required this.nPembeliUnik,
    required this.karyaTersedia,
    required this.karyaTerjualTotal,
    required this.perubahanNTerjualPct,
    required this.perubahanOmzetPct,
  });

  final String id, displayName, levelReputasi;
  final int periodeHari, nTerjual, omzetIdr, komisiPlatformIdr, pendapatanBersihIdr;
  final int hargaRata2Idr, nPembeliUnik, karyaTersedia, karyaTerjualTotal;
  final double? perubahanNTerjualPct, perubahanOmzetPct;

  /// "mapan" -> "Seniman Mapan".
  String get labelLevel => switch (levelReputasi) {
        'pemula' => 'Seniman Pemula',
        'menengah' => 'Seniman Menengah',
        'mapan' => 'Seniman Mapan',
        _ => 'Seniman',
      };

  factory RingkasanSeniman.fromJson(Map<String, dynamic> j) {
    final s = j['seniman'] as Map<String, dynamic>;
    final p = j['perubahan_pct'] as Map<String, dynamic>;
    return RingkasanSeniman(
      id: s['id'] as String,
      displayName: s['display_name'] as String,
      levelReputasi: s['level_reputasi'] as String,
      periodeHari: _i(j['periode_hari']),
      nTerjual: _i(j['n_terjual']),
      omzetIdr: _i(j['omzet_idr']),
      komisiPlatformIdr: _i(j['komisi_platform_idr']),
      pendapatanBersihIdr: _i(j['pendapatan_bersih_idr']),
      hargaRata2Idr: _i(j['harga_rata2_idr']),
      nPembeliUnik: _i(j['n_pembeli_unik']),
      karyaTersedia: _i(j['karya_tersedia']),
      karyaTerjualTotal: _i(j['karya_terjual_total']),
      perubahanNTerjualPct: _d(p['n_terjual']),
      perubahanOmzetPct: _d(p['omzet_idr']),
    );
  }
}

class PenjualanBulan {
  const PenjualanBulan({required this.bulan, required this.nTerjual, required this.omzetIdr, this.gayaTerlaris});

  final String bulan; // "YYYY-MM-01"
  final int nTerjual, omzetIdr;
  final String? gayaTerlaris;

  factory PenjualanBulan.fromJson(Map<String, dynamic> j) => PenjualanBulan(
        bulan: j['bulan'] as String,
        nTerjual: _i(j['n_terjual']),
        omzetIdr: _i(j['omzet_idr']),
        gayaTerlaris: j['gaya_terlaris'] as String?,
      );
}

class AliranSeniman {
  const AliranSeniman({
    required this.styleName,
    required this.nTerjual,
    required this.omzetIdr,
    required this.hargaRata2Idr,
    required this.hargaPasarRata2Idr,
    this.selisihPct,
  });

  final String styleName;
  final int nTerjual, omzetIdr, hargaRata2Idr, hargaPasarRata2Idr;
  final double? selisihPct;

  factory AliranSeniman.fromJson(Map<String, dynamic> j) => AliranSeniman(
        styleName: j['style_name'] as String,
        nTerjual: _i(j['n_terjual']),
        omzetIdr: _i(j['omzet_idr']),
        hargaRata2Idr: _i(j['harga_rata2_idr']),
        hargaPasarRata2Idr: _i(j['harga_pasar_rata2_idr']),
        selisihPct: _d(j['selisih_pct']),
      );
}

class SegmenPembeli {
  const SegmenPembeli({required this.segmenId, required this.segmenNama, required this.nPembeli, this.porsiPct, this.deskripsi});

  final int segmenId, nPembeli;
  final String segmenNama;
  final double? porsiPct;
  final String? deskripsi;

  factory SegmenPembeli.fromJson(Map<String, dynamic> j) => SegmenPembeli(
        segmenId: _i(j['segmen_id']),
        segmenNama: j['segmen_nama'] as String,
        nPembeli: _i(j['n_pembeli']),
        porsiPct: _d(j['porsi_pct']),
        deskripsi: j['deskripsi'] as String?,
      );
}

class SegmenPembeliHasil {
  const SegmenPembeliHasil({required this.tersedia, required this.items});

  final bool tersedia;
  final List<SegmenPembeli> items;

  factory SegmenPembeliHasil.fromJson(Map<String, dynamic> j) => SegmenPembeliHasil(
        tersedia: j['tersedia'] as bool,
        items: (j['items'] as List).cast<Map<String, dynamic>>().map(SegmenPembeli.fromJson).toList(),
      );
}

class SenimanRamai {
  const SenimanRamai({
    required this.senimanId,
    required this.displayName,
    required this.nTerjual30Hari,
    required this.lonjakan,
    required this.hargaRata2Idr,
  });

  final String senimanId, displayName;
  final int nTerjual30Hari, hargaRata2Idr;
  final double lonjakan;

  factory SenimanRamai.fromJson(Map<String, dynamic> j) => SenimanRamai(
        senimanId: j['seniman_id'] as String,
        displayName: j['display_name'] as String,
        nTerjual30Hari: _i(j['n_terjual_30hari']),
        lonjakan: (j['lonjakan'] as num).toDouble(),
        hargaRata2Idr: _i(j['harga_rata2_30hari_idr']),
      );
}

class AliranRamai {
  const AliranRamai({required this.styleName, required this.nTerjual30Hari, this.porsiPct, required this.hargaRata2Idr});

  final String styleName;
  final int nTerjual30Hari, hargaRata2Idr;
  final double? porsiPct;

  factory AliranRamai.fromJson(Map<String, dynamic> j) => AliranRamai(
        styleName: j['style_name'] as String,
        nTerjual30Hari: _i(j['n_terjual_30hari']),
        porsiPct: _d(j['porsi_penjualan_pct']),
        hargaRata2Idr: _i(j['harga_rata2_30hari_idr']),
      );
}

class TrenPasar {
  const TrenPasar({required this.senimanRamai, required this.aliranRamai});

  final List<SenimanRamai> senimanRamai;
  final List<AliranRamai> aliranRamai;

  factory TrenPasar.fromJson(Map<String, dynamic> j) => TrenPasar(
        senimanRamai:
            (j['seniman_ramai'] as List).cast<Map<String, dynamic>>().map(SenimanRamai.fromJson).toList(),
        aliranRamai: (j['aliran_ramai'] as List).cast<Map<String, dynamic>>().map(AliranRamai.fromJson).toList(),
      );
}
