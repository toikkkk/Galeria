/// Model alamat pengiriman & pesanan (cermin `schemas/pesanan.py` di backend).
library;

class Alamat {
  const Alamat({
    required this.id,
    required this.label,
    required this.namaPenerima,
    required this.telepon,
    required this.alamatLengkap,
    required this.kota,
    required this.kodePos,
    required this.isUtama,
  });

  final String id, label, namaPenerima, telepon, alamatLengkap, kota, kodePos;
  final bool isUtama;

  factory Alamat.fromJson(Map<String, dynamic> j) => Alamat(
        id: j['id'] as String,
        label: j['label'] as String,
        namaPenerima: j['nama_penerima'] as String,
        telepon: j['telepon'] as String,
        alamatLengkap: j['alamat_lengkap'] as String,
        kota: j['kota'] as String,
        kodePos: j['kode_pos'] as String,
        isUtama: j['is_utama'] as bool? ?? false,
      );

  String get ringkas => '$alamatLengkap, $kota $kodePos';
}

DateTime? _tgl(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

class InstruksiBayar {
  const InstruksiBayar({
    required this.metode,
    required this.namaMetode,
    required this.nomor,
    required this.jumlahIdr,
    required this.mode,
    this.batasBayarAt,
  });

  final String metode, namaMetode, nomor, mode;
  final int jumlahIdr;
  final DateTime? batasBayarAt;

  bool get sandbox => mode == 'sandbox';

  factory InstruksiBayar.fromJson(Map<String, dynamic> j) => InstruksiBayar(
        metode: j['metode'] as String,
        namaMetode: j['nama_metode'] as String,
        nomor: j['nomor'] as String,
        jumlahIdr: j['jumlah_idr'] as int,
        mode: j['mode'] as String,
        batasBayarAt: _tgl(j['batas_bayar_at']),
      );
}

class Pesanan {
  const Pesanan({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.karyaId,
    required this.judul,
    required this.artistName,
    required this.styleName,
    required this.pembeliNama,
    required this.penjualNama,
    required this.hargaIdr,
    required this.komisiIdr,
    required this.pendapatanSenimanIdr,
    required this.sudahDikirim,
    required this.createdAt,
    required this.aksi,
    this.imageUrl,
    this.imageFilename,
    this.alamat,
    this.instruksi,
    this.kurir,
    this.noResi,
    this.batasBayarAt,
    this.dibayarAt,
    this.dikonfirmasiAt,
    this.dikirimAt,
    this.selesaiAt,
    this.dibatalkanAt,
  });

  final String id, status, statusLabel, karyaId, judul, artistName, styleName, pembeliNama, penjualNama;
  final int hargaIdr, komisiIdr, pendapatanSenimanIdr;
  final bool sudahDikirim;
  final DateTime createdAt;
  final List<String> aksi;
  final String? imageUrl, imageFilename, kurir, noResi;
  final Map<String, dynamic>? alamat;
  final InstruksiBayar? instruksi;
  final DateTime? batasBayarAt, dibayarAt, dikonfirmasiAt, dikirimAt, selesaiAt, dibatalkanAt;

  bool bisa(String a) => aksi.contains(a);

  /// Kode pendek untuk ditampilkan, mis. "#GAL-3F9A21C4".
  String get kode => '#GAL-${id.replaceAll('-', '').substring(0, 8).toUpperCase()}';

  String get alamatRingkas {
    final a = alamat;
    if (a == null) return '-';
    return '${a['nama_penerima']} · ${a['telepon']}\n${a['alamat_lengkap']}, ${a['kota']} ${a['kode_pos']}';
  }

  factory Pesanan.fromJson(Map<String, dynamic> j) {
    final k = j['karya'] as Map<String, dynamic>;
    final ins = j['instruksi_bayar'] as Map<String, dynamic>?;
    return Pesanan(
      id: j['id'] as String,
      status: j['status'] as String,
      statusLabel: j['status_label'] as String,
      karyaId: k['id'] as String,
      judul: k['title'] as String,
      artistName: k['artist_name'] as String,
      styleName: k['style_name'] as String,
      imageUrl: k['image_url'] as String?,
      imageFilename: k['image_filename'] as String?,
      pembeliNama: j['pembeli_nama'] as String,
      penjualNama: j['penjual_nama'] as String,
      hargaIdr: j['harga_final_idr'] as int,
      komisiIdr: j['komisi_platform_idr'] as int,
      pendapatanSenimanIdr: j['pendapatan_seniman_idr'] as int,
      sudahDikirim: j['sudah_dikirim'] as bool? ?? false,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      aksi: (j['aksi'] as List? ?? const []).cast<String>(),
      alamat: j['alamat'] as Map<String, dynamic>?,
      instruksi: ins == null ? null : InstruksiBayar.fromJson(ins),
      kurir: j['kurir'] as String?,
      noResi: j['no_resi'] as String?,
      batasBayarAt: _tgl(j['batas_bayar_at']),
      dibayarAt: _tgl(j['dibayar_at']),
      dikonfirmasiAt: _tgl(j['dikonfirmasi_at']),
      dikirimAt: _tgl(j['dikirim_at']),
      selesaiAt: _tgl(j['selesai_at']),
      dibatalkanAt: _tgl(j['dibatalkan_at']),
    );
  }
}
