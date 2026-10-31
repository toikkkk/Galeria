/// Model event & tiket (cermin `schemas/event.py` di backend).
library;

import 'pesanan.dart';

DateTime _t(dynamic v) => DateTime.parse(v as String).toLocal();
DateTime? _tn(dynamic v) => v == null ? null : _t(v);

class TiketEvent {
  const TiketEvent({required this.id, required this.nama, required this.hargaIdr, required this.kuota, required this.sisa, this.keterangan});

  final String id, nama;
  final int hargaIdr, kuota, sisa;
  final String? keterangan;

  bool get habis => sisa <= 0;
  bool get gratis => hargaIdr == 0;

  factory TiketEvent.fromJson(Map<String, dynamic> j) => TiketEvent(
        id: j['id'] as String,
        nama: j['nama'] as String,
        hargaIdr: j['harga_idr'] as int,
        kuota: j['kuota'] as int,
        sisa: j['sisa'] as int,
        keterangan: j['keterangan'] as String?,
      );
}

class KaryaEvent {
  const KaryaEvent({required this.id, required this.title, required this.artistName, required this.styleName, required this.priceIdr, this.imageUrl, this.imageFilename});

  final String id, title, artistName, styleName;
  final int priceIdr;
  final String? imageUrl, imageFilename;

  factory KaryaEvent.fromJson(Map<String, dynamic> j) => KaryaEvent(
        id: j['id'] as String,
        title: j['title'] as String,
        artistName: j['artist_name'] as String,
        styleName: j['style_name'] as String,
        priceIdr: j['price_idr'] as int,
        imageUrl: j['image_url'] as String?,
        imageFilename: j['image_filename'] as String?,
      );
}

class EventInfo {
  const EventInfo({
    required this.id,
    required this.judul,
    required this.format,
    required this.mulai,
    required this.selesai,
    required this.status,
    required this.penyelenggara,
    required this.gratis,
    required this.hargaMulaiIdr,
    required this.totalKuota,
    required this.totalSisa,
    required this.tiket,
    required this.karya,
    required this.sayaPunyaTiket,
    required this.sayaPenyelenggara,
    required this.bisaDibatalkan,
    this.deskripsi,
    this.tema,
    this.namaLokasi,
    this.alamat,
    this.kota,
    this.linkOnline,
    this.tiketTerjual,
    this.pendapatanIdr,
    this.sudahCheckin,
  });

  final String id, judul, format, status, penyelenggara;
  final String? deskripsi, tema, namaLokasi, alamat, kota, linkOnline;
  final DateTime mulai, selesai;
  final bool gratis, sayaPunyaTiket, sayaPenyelenggara, bisaDibatalkan;
  final int hargaMulaiIdr, totalKuota, totalSisa;
  final List<TiketEvent> tiket;
  final List<KaryaEvent> karya;
  final int? tiketTerjual, pendapatanIdr, sudahCheckin;

  bool get online => format == 'online';
  bool get bisaBeli => status == 'akan_datang' || status == 'berlangsung';
  String get lokasi => online ? 'Online' : [namaLokasi, kota].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  factory EventInfo.fromJson(Map<String, dynamic> j) => EventInfo(
        id: j['id'] as String,
        judul: j['judul'] as String,
        deskripsi: j['deskripsi'] as String?,
        tema: j['tema'] as String?,
        format: j['format'] as String,
        namaLokasi: j['nama_lokasi'] as String?,
        alamat: j['alamat'] as String?,
        kota: j['kota'] as String?,
        linkOnline: j['link_online'] as String?,
        mulai: _t(j['mulai_at']),
        selesai: _t(j['selesai_at']),
        status: j['status'] as String,
        penyelenggara: j['penyelenggara_nama'] as String,
        gratis: j['gratis'] as bool,
        hargaMulaiIdr: j['harga_mulai_idr'] as int,
        totalKuota: j['total_kuota'] as int,
        totalSisa: j['total_sisa'] as int,
        tiket: (j['tiket'] as List).cast<Map<String, dynamic>>().map(TiketEvent.fromJson).toList(),
        karya: (j['karya'] as List).cast<Map<String, dynamic>>().map(KaryaEvent.fromJson).toList(),
        sayaPunyaTiket: j['saya_punya_tiket'] as bool? ?? false,
        sayaPenyelenggara: j['saya_penyelenggara'] as bool? ?? false,
        bisaDibatalkan: j['bisa_dibatalkan'] as bool? ?? false,
        tiketTerjual: j['tiket_terjual'] as int?,
        pendapatanIdr: j['pendapatan_idr'] as int?,
        sudahCheckin: j['sudah_checkin'] as int?,
      );
}

class ETiket {
  const ETiket({required this.id, required this.kode, required this.status, this.namaPemegang, this.checkinAt});

  final String id, kode, status;
  final String? namaPemegang;
  final DateTime? checkinAt;

  bool get terpakai => status == 'terpakai';

  factory ETiket.fromJson(Map<String, dynamic> j) => ETiket(
        id: j['id'] as String,
        kode: j['kode'] as String,
        status: j['status'] as String,
        namaPemegang: j['nama_pemegang'] as String?,
        checkinAt: _tn(j['checkin_at']),
      );
}

class EventRingkas {
  const EventRingkas({required this.id, required this.judul, required this.format, required this.mulai, required this.selesai, required this.status, this.kota, this.namaLokasi});

  final String id, judul, format, status;
  final String? kota, namaLokasi;
  final DateTime mulai, selesai;

  String get lokasi => format == 'online' ? 'Online' : [namaLokasi, kota].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  factory EventRingkas.fromJson(Map<String, dynamic> j) => EventRingkas(
        id: j['id'] as String,
        judul: j['judul'] as String,
        format: j['format'] as String,
        kota: j['kota'] as String?,
        namaLokasi: j['nama_lokasi'] as String?,
        mulai: _t(j['mulai_at']),
        selesai: _t(j['selesai_at']),
        status: j['status'] as String,
      );
}

class PesananTiket {
  const PesananTiket({
    required this.id,
    required this.event,
    required this.tiketNama,
    required this.jumlah,
    required this.hargaSatuanIdr,
    required this.totalIdr,
    required this.status,
    required this.statusLabel,
    required this.namaPemegang,
    required this.etiket,
    required this.aksi,
    this.instruksi,
    this.batasBayarAt,
  });

  final String id, tiketNama, status, statusLabel, namaPemegang;
  final EventRingkas event;
  final int jumlah, hargaSatuanIdr, totalIdr;
  final List<ETiket> etiket;
  final List<String> aksi;
  final InstruksiBayar? instruksi;
  final DateTime? batasBayarAt;

  bool bisa(String a) => aksi.contains(a);

  factory PesananTiket.fromJson(Map<String, dynamic> j) {
    final ins = j['instruksi_bayar'] as Map<String, dynamic>?;
    return PesananTiket(
      id: j['id'] as String,
      event: EventRingkas.fromJson(j['event'] as Map<String, dynamic>),
      tiketNama: j['tiket_nama'] as String,
      jumlah: j['jumlah'] as int,
      hargaSatuanIdr: j['harga_satuan_idr'] as int,
      totalIdr: j['total_idr'] as int,
      status: j['status'] as String,
      statusLabel: j['status_label'] as String,
      namaPemegang: j['nama_pemegang'] as String,
      etiket: (j['etiket'] as List).cast<Map<String, dynamic>>().map(ETiket.fromJson).toList(),
      aksi: (j['aksi'] as List? ?? const []).cast<String>(),
      instruksi: ins == null ? null : InstruksiBayar.fromJson(ins),
      batasBayarAt: _tn(j['batas_bayar_at']),
    );
  }
}

class TiketSaya {
  const TiketSaya({required this.etiket, required this.tiketNama, required this.event, this.linkOnline});

  final ETiket etiket;
  final String tiketNama;
  final EventRingkas event;
  final String? linkOnline;

  factory TiketSaya.fromJson(Map<String, dynamic> j) => TiketSaya(
        etiket: ETiket.fromJson(j['etiket'] as Map<String, dynamic>),
        tiketNama: j['tiket_nama'] as String,
        event: EventRingkas.fromJson(j['event'] as Map<String, dynamic>),
        linkOnline: j['link_online'] as String?,
      );
}

class HasilCheckin {
  const HasilCheckin({required this.berhasil, required this.pesan, this.namaPemegang, this.tiketNama, this.eventJudul});

  final bool berhasil;
  final String pesan;
  final String? namaPemegang, tiketNama, eventJudul;

  factory HasilCheckin.fromJson(Map<String, dynamic> j) => HasilCheckin(
        berhasil: j['berhasil'] as bool,
        pesan: j['pesan'] as String,
        namaPemegang: j['nama_pemegang'] as String?,
        tiketNama: j['tiket_nama'] as String?,
        eventJudul: j['event_judul'] as String?,
      );
}

class Peserta {
  const Peserta({required this.kode, required this.tiketNama, required this.status, required this.akunPembeli, this.namaPemegang, this.checkinAt});

  final String kode, tiketNama, status, akunPembeli;
  final String? namaPemegang;
  final DateTime? checkinAt;

  factory Peserta.fromJson(Map<String, dynamic> j) => Peserta(
        kode: j['kode'] as String,
        namaPemegang: j['nama_pemegang'] as String?,
        tiketNama: j['tiket_nama'] as String,
        status: j['status'] as String,
        akunPembeli: j['akun_pembeli'] as String,
        checkinAt: _tn(j['checkin_at']),
      );
}
