/// Model komunitas (cermin `schemas/komunitas.py` di backend).
library;

DateTime _t(dynamic v) => DateTime.parse(v as String).toLocal();

class Komunitas {
  const Komunitas({
    required this.id,
    required this.nama,
    required this.aliran,
    required this.terbuka,
    required this.pemilikNama,
    required this.jumlahAnggota,
    required this.dibuat,
    this.deskripsi,
    this.aturan,
    this.saya,
    this.jumlahPermintaan,
  });

  final String id, nama, pemilikNama;
  final String? deskripsi, aturan;
  final List<String> aliran;
  final bool terbuka;
  final int jumlahAnggota;
  final DateTime dibuat;

  /// pemilik | anggota | menunggu | null (belum bergabung)
  final String? saya;
  final int? jumlahPermintaan;

  bool get pemilik => saya == 'pemilik';
  bool get anggotaAktif => saya == 'pemilik' || saya == 'anggota';
  bool get menunggu => saya == 'menunggu';

  /// Isi (postingan/anggota/karya) terbuka untuk pengguna ini?
  bool get bisaLihatIsi => terbuka || anggotaAktif;

  String get inisial {
    final k = nama.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (k.isEmpty) return '?';
    return (k.length == 1 ? k.first.substring(0, k.first.length < 2 ? 1 : 2) : k.first[0] + k.last[0]).toUpperCase();
  }

  factory Komunitas.fromJson(Map<String, dynamic> j) => Komunitas(
        id: j['id'] as String,
        nama: j['nama'] as String,
        deskripsi: j['deskripsi'] as String?,
        aliran: (j['aliran'] as List).cast<String>(),
        terbuka: j['terbuka'] as bool,
        aturan: j['aturan'] as String?,
        pemilikNama: j['pemilik_nama'] as String,
        jumlahAnggota: j['jumlah_anggota'] as int,
        dibuat: _t(j['dibuat_at']),
        saya: j['saya'] as String?,
        jumlahPermintaan: j['jumlah_permintaan'] as int?,
      );
}

class AnggotaKomunitas {
  const AnggotaKomunitas({required this.userId, required this.nama, required this.peran, required this.bergabung});

  final String userId, nama, peran;
  final DateTime bergabung;

  factory AnggotaKomunitas.fromJson(Map<String, dynamic> j) => AnggotaKomunitas(
        userId: j['user_id'] as String,
        nama: j['nama'] as String,
        peran: j['peran'] as String,
        bergabung: _t(j['bergabung_at']),
      );
}

class DaftarAnggota {
  const DaftarAnggota({required this.anggota, required this.permintaan});

  final List<AnggotaKomunitas> anggota, permintaan;

  factory DaftarAnggota.fromJson(Map<String, dynamic> j) => DaftarAnggota(
        anggota: (j['anggota'] as List).cast<Map<String, dynamic>>().map(AnggotaKomunitas.fromJson).toList(),
        permintaan: ((j['permintaan'] as List?) ?? const []).cast<Map<String, dynamic>>().map(AnggotaKomunitas.fromJson).toList(),
      );
}

class PostKomunitas {
  PostKomunitas({
    required this.id,
    required this.penulisId,
    required this.penulisNama,
    required this.penulisPemilik,
    required this.teks,
    required this.disematkan,
    required this.jumlahLike,
    required this.jumlahKomentar,
    required this.sayaLike,
    required this.waktu,
    required this.bisaHapus,
    required this.bisaSematkan,
    this.imageUrl,
  });

  final String id, penulisId, penulisNama, teks;
  final bool penulisPemilik, bisaHapus, bisaSematkan;
  final String? imageUrl;
  bool disematkan, sayaLike;
  int jumlahLike, jumlahKomentar;
  final DateTime waktu;

  factory PostKomunitas.fromJson(Map<String, dynamic> j) => PostKomunitas(
        id: j['id'] as String,
        penulisId: j['penulis_id'] as String,
        penulisNama: j['penulis_nama'] as String,
        penulisPemilik: j['penulis_pemilik'] as bool,
        teks: j['teks'] as String,
        imageUrl: j['image_url'] as String?,
        disematkan: j['disematkan'] as bool,
        jumlahLike: j['jumlah_like'] as int,
        jumlahKomentar: j['jumlah_komentar'] as int,
        sayaLike: j['saya_like'] as bool,
        waktu: _t(j['waktu']),
        bisaHapus: j['bisa_hapus'] as bool,
        bisaSematkan: j['bisa_sematkan'] as bool,
      );
}

class HalamanPost {
  const HalamanPost({required this.items, required this.adaLagi});

  final List<PostKomunitas> items;
  final bool adaLagi;
}

class KomentarKomunitas {
  const KomentarKomunitas({required this.id, required this.penulisNama, required this.teks, required this.waktu, required this.bisaHapus});

  final String id, penulisNama, teks;
  final DateTime waktu;
  final bool bisaHapus;

  factory KomentarKomunitas.fromJson(Map<String, dynamic> j) => KomentarKomunitas(
        id: j['id'] as String,
        penulisNama: j['penulis_nama'] as String,
        teks: j['teks'] as String,
        waktu: _t(j['waktu']),
        bisaHapus: j['bisa_hapus'] as bool,
      );
}

/// "3 mnt lalu", "2 jam lalu", "5 hari lalu", selain itu tanggal.
String waktuRelatif(DateTime t, [DateTime? sekarang]) {
  final d = (sekarang ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  if (d.inDays < 30) return '${d.inDays} hari lalu';
  return '${t.day}/${t.month}/${t.year}';
}
