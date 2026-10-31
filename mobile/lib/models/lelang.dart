/// Model lelang (cermin `schemas/lelang.py` di backend). Semua waktu dihitung dari JAM SERVER:
/// [serverNow] dibandingkan dengan jam HP saat data diterima, lalu selisihnya dipakai untuk hitung mundur,
/// jadi jam HP yang salah tidak membuat hitung mundur meleset.
library;

class BidLelang {
  const BidLelang({required this.nama, required this.jumlahIdr, required this.waktu, required this.saya});

  final String nama;
  final int jumlahIdr;
  final DateTime waktu;
  final bool saya;

  factory BidLelang.fromJson(Map<String, dynamic> j) => BidLelang(
        nama: j['nama'] as String,
        jumlahIdr: j['jumlah_idr'] as int,
        waktu: DateTime.parse(j['waktu'] as String).toLocal(),
        saya: j['saya'] as bool? ?? false,
      );
}

class Lelang {
  Lelang({
    required this.id,
    required this.status,
    required this.karyaId,
    required this.judul,
    required this.artistName,
    required this.styleName,
    required this.senimanNama,
    required this.hargaAwalIdr,
    required this.kelipatanIdr,
    required this.hargaSaatIniIdr,
    required this.jumlahBid,
    required this.bidMinimumIdr,
    required this.mulai,
    required this.selesai,
    required this.selisihJam,
    required this.sayaTertinggi,
    required this.sayaPemenang,
    required this.bisaDibatalkan,
    this.imageUrl,
    this.imageFilename,
    this.lebarCm,
    this.tinggiCm,
    this.pemenangNama,
    this.pesananId,
    this.bids = const [],
  });

  final String id, status, karyaId, judul, artistName, styleName, senimanNama;
  final int hargaAwalIdr, kelipatanIdr, hargaSaatIniIdr, jumlahBid, bidMinimumIdr;
  final DateTime mulai, selesai;

  /// jam server dikurangi jam HP saat data diterima.
  final Duration selisihJam;
  final bool sayaTertinggi, sayaPemenang, bisaDibatalkan;
  final String? imageUrl, imageFilename, pemenangNama, pesananId;
  final double? lebarCm, tinggiCm;
  final List<BidLelang> bids;

  DateTime get sekarangServer => DateTime.now().add(selisihJam);

  /// Status menurut jam server SAAT INI (menyusul bila waktu berjalan sejak data diterima).
  String get statusSekarang {
    if (status == 'dibatalkan' || status == 'selesai') return status;
    final n = sekarangServer;
    if (n.isBefore(mulai)) return 'akan_datang';
    return n.isBefore(selesai) ? 'berlangsung' : 'selesai';
  }

  bool get berlangsung => statusSekarang == 'berlangsung';

  /// Sisa waktu menuju target: sampai mulai (akan datang) atau sampai selesai (berlangsung).
  Duration get sisa {
    final target = statusSekarang == 'akan_datang' ? mulai : selesai;
    final d = target.difference(sekarangServer);
    return d.isNegative ? Duration.zero : d;
  }

  factory Lelang.fromJson(Map<String, dynamic> j) {
    final k = j['karya'] as Map<String, dynamic>;
    final serverNow = DateTime.parse(j['server_now'] as String).toLocal();
    return Lelang(
      id: j['id'] as String,
      status: j['status'] as String,
      karyaId: k['id'] as String,
      judul: k['title'] as String,
      artistName: k['artist_name'] as String,
      styleName: k['style_name'] as String,
      imageUrl: k['image_url'] as String?,
      imageFilename: k['image_filename'] as String?,
      lebarCm: (k['lebar_cm'] as num?)?.toDouble(),
      tinggiCm: (k['tinggi_cm'] as num?)?.toDouble(),
      senimanNama: j['seniman_nama'] as String,
      hargaAwalIdr: j['harga_awal_idr'] as int,
      kelipatanIdr: j['kelipatan_bid_idr'] as int,
      hargaSaatIniIdr: j['harga_saat_ini_idr'] as int,
      jumlahBid: j['jumlah_bid'] as int,
      bidMinimumIdr: j['bid_minimum_berikutnya_idr'] as int,
      mulai: DateTime.parse(j['mulai_at'] as String).toLocal(),
      selesai: DateTime.parse(j['selesai_at'] as String).toLocal(),
      selisihJam: serverNow.difference(DateTime.now()),
      sayaTertinggi: j['saya_tertinggi'] as bool? ?? false,
      sayaPemenang: j['saya_pemenang'] as bool? ?? false,
      pemenangNama: j['pemenang_nama'] as String?,
      pesananId: j['pesanan_id'] as String?,
      bisaDibatalkan: j['bisa_dibatalkan'] as bool? ?? false,
      bids: ((j['bids'] as List?) ?? const []).cast<Map<String, dynamic>>().map(BidLelang.fromJson).toList(),
    );
  }
}

/// 3725 detik -> "01:02:05"; lebih dari sehari -> "2h 03:10:00".
String formatSisa(Duration d) {
  final hari = d.inDays;
  final jam = d.inHours % 24;
  final mnt = d.inMinutes % 60;
  final dtk = d.inSeconds % 60;
  final hms = '${jam.toString().padLeft(2, '0')}:${mnt.toString().padLeft(2, '0')}:${dtk.toString().padLeft(2, '0')}';
  return hari > 0 ? '${hari}h $hms' : hms;
}
