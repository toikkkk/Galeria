/// Ulasan publik sebuah karya (`GET /api/karya/{id}/ulasan`).
class UlasanKaryaItem {
  const UlasanKaryaItem({required this.nama, required this.rating, required this.teks, required this.tanggal, this.sentimen});

  final String nama, teks;
  final int rating;
  final DateTime tanggal;
  final String? sentimen;

  factory UlasanKaryaItem.fromJson(Map<String, dynamic> j) => UlasanKaryaItem(
        nama: j['nama'] as String,
        rating: j['rating'] as int,
        teks: j['teks'] as String,
        tanggal: DateTime.parse(j['tanggal'] as String).toLocal(),
        sentimen: j['sentimen'] as String?,
      );
}

class UlasanKarya {
  const UlasanKarya({required this.jumlah, required this.rata2, required this.sebaran, required this.items});

  final int jumlah;
  final double? rata2;
  final Map<String, int> sebaran;
  final List<UlasanKaryaItem> items;

  factory UlasanKarya.fromJson(Map<String, dynamic> j) => UlasanKarya(
        jumlah: j['jumlah'] as int,
        rata2: (j['rata2'] as num?)?.toDouble(),
        sebaran: (j['sebaran'] as Map).map((k, v) => MapEntry(k as String, v as int)),
        items: (j['items'] as List).cast<Map<String, dynamic>>().map(UlasanKaryaItem.fromJson).toList(),
      );
}
