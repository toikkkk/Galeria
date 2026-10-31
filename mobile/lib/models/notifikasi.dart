/// Notifikasi in-app (cermin `routers/notifikasi.py` di backend).
library;

class Notifikasi {
  Notifikasi({required this.id, required this.tipe, required this.judul, required this.waktu, required this.dibaca, this.isi, this.tautan});

  final String id, tipe, judul;
  final String? isi, tautan;
  final DateTime waktu;
  bool dibaca;

  factory Notifikasi.fromJson(Map<String, dynamic> j) => Notifikasi(
        id: j['id'] as String,
        tipe: j['tipe'] as String,
        judul: j['judul'] as String,
        isi: j['isi'] as String?,
        tautan: j['tautan'] as String?,
        dibaca: j['dibaca'] as bool,
        waktu: DateTime.parse(j['waktu'] as String).toLocal(),
      );

  /// Bagian sebelum titik dua pada tautan, mis. "pesanan" dari tautan pesanan dengan id.
  String? get jenisTautan => tautan?.split(':').first;

  /// Bagian sesudah titik dua (id), atau null.
  String? get idTautan {
    final t = tautan;
    if (t == null || !t.contains(':')) return null;
    return t.substring(t.indexOf(':') + 1);
  }
}

class HalamanNotifikasi {
  const HalamanNotifikasi({required this.items, required this.belumDibaca, required this.adaLagi});

  final List<Notifikasi> items;
  final int belumDibaca;
  final bool adaLagi;
}
