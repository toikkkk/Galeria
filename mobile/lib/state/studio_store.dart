import 'package:flutter/material.dart';

import '../models/karya.dart';

/// Lelang yang dibuat seniman.
class LelangSeniman {
  const LelangSeniman({
    required this.karya,
    required this.hargaAwalIdr,
    required this.kelipatanBidIdr,
    required this.mulai,
    required this.selesai,
    this.catatan = '',
  });

  final Karya karya;
  final int hargaAwalIdr;
  final int kelipatanBidIdr;
  final DateTime mulai;
  final DateTime selesai;
  final String catatan;
}

/// Label promosi pada sebuah karya (fitur PRO).
class PromosiKarya {
  const PromosiKarya({
    required this.karya,
    required this.durasiHari,
    required this.biayaIdr,
    required this.diLelang,
    required this.diBeranda,
    required this.mulai,
  });

  final Karya karya;
  final int durasiHari;
  final int biayaIdr;
  final bool diLelang;
  final bool diBeranda;
  final DateTime mulai;

  DateTime get berakhir => mulai.add(Duration(days: durasiHari));
}

class KomunitasSeniman {
  const KomunitasSeniman({
    required this.nama,
    required this.deskripsi,
    required this.aliran,
    required this.terbuka,
    this.aturan = '',
  });

  final String nama;
  final String deskripsi;
  final List<String> aliran;

  /// true = siapa pun boleh bergabung; false = anggota perlu disetujui.
  final bool terbuka;
  final String aturan;
}

class JenisTiket {
  JenisTiket({
    required this.nama,
    required this.hargaIdr,
    required this.kuota,
    this.keterangan = '',
  });

  String nama;
  int hargaIdr;
  int kuota;
  String keterangan;
}

/// Event pameran -- dipakai sebagai draft (saat wizard berjalan) dan sebagai
/// event terbit (di [StudioStore.events]).
class EventPameran {
  String nama = '';
  String deskripsi = '';
  String tema = 'Pameran Tunggal';
  List<Karya> karya = [];

  DateTime? tanggalMulai;
  DateTime? tanggalSelesai;
  TimeOfDay? jamBuka;
  TimeOfDay? jamTutup;

  /// 'offline' | 'online'
  String format = 'offline';
  String namaLokasi = '';
  String alamat = '';
  String kota = '';
  String linkOnline = '';

  List<JenisTiket> tiket = [
    JenisTiket(nama: 'Tiket Reguler', hargaIdr: 50000, kuota: 100),
  ];

  bool get gratis => tiket.every((t) => t.hargaIdr == 0);
  int get totalKuota => tiket.fold(0, (a, t) => a + t.kuota);
  int get potensiPendapatanIdr => tiket.fold(0, (a, t) => a + t.hargaIdr * t.kuota);
}

/// State studio seniman: PRO, lelang, promosi, komunitas, event.
///
/// IN-MEMORY (hilang saat aplikasi ditutup): tabel `lelang`, `events`,
/// `subscriptions` belum diterapkan di database Neon `neondb` (lihat
/// CLAUDE.md -- migrasi 0003-0007 belum di-apply), jadi belum ada
/// endpoint backend untuk menyimpannya. Begitu tabel & endpoint ada, ganti
/// isi store ini dengan pemanggilan service.
class StudioStore extends ChangeNotifier {
  StudioStore._();
  static final StudioStore instance = StudioStore._();

  bool _isPro = false;
  bool get isPro => _isPro;

  final List<LelangSeniman> lelang = [];
  final List<PromosiKarya> promosi = [];
  final List<EventPameran> events = [];
  KomunitasSeniman? komunitas;

  /// Draft event yang sedang diisi di wizard 3 langkah.
  EventPameran draftEvent = EventPameran();
  EventPameran? lastPublished;

  void upgradeKePro() {
    _isPro = true;
    notifyListeners();
  }

  void tambahLelang(LelangSeniman l) {
    lelang.insert(0, l);
    notifyListeners();
  }

  void tambahPromosi(PromosiKarya p) {
    promosi.removeWhere((x) => _sama(x.karya, p.karya));
    promosi.insert(0, p);
    notifyListeners();
  }

  /// Karya sedang dipromosikan? (cocokkan lewat id, fallback judul).
  bool sedangDipromosikan(Karya k) =>
      promosi.any((p) => _sama(p.karya, k) && p.berakhir.isAfter(DateTime.now()));

  static bool _sama(Karya a, Karya b) =>
      a.id.isNotEmpty && b.id.isNotEmpty ? a.id == b.id : a.title == b.title;

  void buatKomunitas(KomunitasSeniman k) {
    komunitas = k;
    notifyListeners();
  }

  void mulaiDraftEvent() {
    draftEvent = EventPameran();
  }

  /// Terbitkan draft -> masuk daftar event.
  EventPameran terbitkanDraft() {
    final e = draftEvent;
    events.insert(0, e);
    draftEvent = EventPameran();
    lastPublished = e;
    notifyListeners();
    return e;
  }
}
