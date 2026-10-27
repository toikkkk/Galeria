/// Model respons `GET /api/dashboard/seniman/{id}/sentimen` (lihat backend/schemas/sentimen.py).
/// Sentimen = keluaran model IndoBERT pada ulasan kolektor (data contoh, bukan ulasan pengguna sungguhan).
library;

int _i(dynamic v) => (v as num).toInt();
double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

class SentimenHitung {
  const SentimenHitung({required this.sentimen, required this.jumlah, required this.persen});

  final String sentimen; // positif | netral | negatif
  final int jumlah;
  final double persen;

  factory SentimenHitung.fromJson(Map<String, dynamic> j) =>
      SentimenHitung(sentimen: j['sentimen'] as String, jumlah: _i(j['jumlah']), persen: (j['persen'] as num).toDouble());
}

class SentimenBulan {
  const SentimenBulan({required this.bulan, required this.positif, required this.netral, required this.negatif});

  final String bulan; // YYYY-MM-01
  final int positif, netral, negatif;

  int get total => positif + netral + negatif;

  factory SentimenBulan.fromJson(Map<String, dynamic> j) => SentimenBulan(
        bulan: j['bulan'] as String,
        positif: _i(j['positif']),
        netral: _i(j['netral']),
        negatif: _i(j['negatif']),
      );
}

class UlasanContoh {
  const UlasanContoh({required this.teks, required this.sentimen, required this.rating, required this.tanggal, this.judulKarya});

  final String teks, sentimen, tanggal;
  final int rating;
  final String? judulKarya;

  factory UlasanContoh.fromJson(Map<String, dynamic> j) => UlasanContoh(
        teks: j['teks'] as String,
        sentimen: j['sentimen'] as String,
        rating: _i(j['rating']),
        tanggal: j['tanggal'] as String,
        judulKarya: j['judul_karya'] as String?,
      );
}

class SentimenSeniman {
  const SentimenSeniman({
    required this.senimanId,
    required this.nUlasan,
    required this.hitung,
    required this.trenBulanan,
    required this.ulasanTerbaru,
    this.modelVersion,
    this.indeksSentimen,
    this.ratingRata2,
  });

  final String senimanId;
  final int nUlasan;
  final String? modelVersion;
  final List<SentimenHitung> hitung;
  final double? indeksSentimen; // -100..100
  final double? ratingRata2;
  final List<SentimenBulan> trenBulanan;
  final List<UlasanContoh> ulasanTerbaru;

  factory SentimenSeniman.fromJson(Map<String, dynamic> j) => SentimenSeniman(
        senimanId: j['seniman_id'] as String,
        nUlasan: _i(j['n_ulasan']),
        modelVersion: j['model_version'] as String?,
        hitung: (j['hitung'] as List).map((e) => SentimenHitung.fromJson(e as Map<String, dynamic>)).toList(),
        indeksSentimen: _d(j['indeks_sentimen']),
        ratingRata2: _d(j['rating_rata2']),
        trenBulanan: (j['tren_bulanan'] as List).map((e) => SentimenBulan.fromJson(e as Map<String, dynamic>)).toList(),
        ulasanTerbaru: (j['ulasan_terbaru'] as List).map((e) => UlasanContoh.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
