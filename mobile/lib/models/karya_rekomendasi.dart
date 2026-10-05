import 'karya.dart';

/// Satu alasan rekomendasi: [kode] tetap (kontrak backend), [teks] siap tampil.
class AlasanRekomendasi {
  const AlasanRekomendasi({required this.kode, required this.teks});

  final String kode;
  final String teks;

  factory AlasanRekomendasi.fromJson(Map<String, dynamic> json) =>
      AlasanRekomendasi(kode: json['kode'] as String, teks: json['teks'] as String);
}

/// Karya hasil rekomendasi. [skor] hanya untuk urutan -- JANGAN ditampilkan
/// sebagai "peluang beli".
class KaryaRekomendasi {
  const KaryaRekomendasi({
    required this.karya,
    required this.peringkat,
    required this.skor,
    required this.alasan,
  });

  final Karya karya;
  final int peringkat;
  final double skor;
  final List<AlasanRekomendasi> alasan;

  factory KaryaRekomendasi.fromJson(Map<String, dynamic> json) => KaryaRekomendasi(
        karya: Karya.fromJson(json['karya'] as Map<String, dynamic>),
        peringkat: json['peringkat'] as int,
        skor: (json['skor'] as num).toDouble(),
        alasan: (json['alasan'] as List)
            .cast<Map<String, dynamic>>()
            .map(AlasanRekomendasi.fromJson)
            .toList(),
      );
}

/// Respons `GET /api/rekomendasi/{kolektor_id}`.
class RekomendasiResult {
  const RekomendasiResult({
    required this.strategi,
    required this.segmenNama,
    required this.items,
  });

  /// `model` (punya riwayat beli) atau `cold_start`.
  final String strategi;
  final String? segmenNama;
  final List<KaryaRekomendasi> items;

  factory RekomendasiResult.fromJson(Map<String, dynamic> json) => RekomendasiResult(
        strategi: json['strategi'] as String,
        segmenNama: (json['segmen'] as Map<String, dynamic>?)?['nama'] as String?,
        items: (json['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(KaryaRekomendasi.fromJson)
            .toList(),
      );
}

/// Satu baris `GET /api/rekomendasi/demo-kolektor`.
class KolektorDemo {
  const KolektorDemo({
    required this.id,
    required this.displayName,
    required this.segmen,
    required this.nPembelian,
  });

  final String id;
  final String displayName;
  final String? segmen;
  final int nPembelian;

  factory KolektorDemo.fromJson(Map<String, dynamic> json) => KolektorDemo(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        segmen: json['segmen'] as String?,
        nPembelian: json['n_pembelian'] as int,
      );
}
