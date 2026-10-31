import 'package:flutter/material.dart';

import '../models/karya.dart';

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

/// Draft event yang sedang diisi di wizard (event terbit disimpan di server).
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

  /// Bila diisi, event terbit atas nama komunitas ini (pemilik komunitas).
  String? komunitasId;

  List<JenisTiket> tiket = [
    JenisTiket(nama: 'Tiket Reguler', hargaIdr: 50000, kuota: 100),
  ];

  bool get gratis => tiket.every((t) => t.hargaIdr == 0);
  int get totalKuota => tiket.fold(0, (a, t) => a + t.kuota);
  int get potensiPendapatanIdr => tiket.fold(0, (a, t) => a + t.hargaIdr * t.kuota);
}

/// State sementara studio seniman: hanya draft event yang sedang diisi di wizard.
///
/// IN-MEMORY (hilang saat aplikasi ditutup): tabel `lelang`, `events`,
/// `subscriptions` belum diterapkan di database Neon `neondb` (lihat
/// CLAUDE.md -- migrasi 0003-0007 belum di-apply), jadi belum ada
/// endpoint backend untuk menyimpannya. Begitu tabel & endpoint ada, ganti
/// isi store ini dengan pemanggilan service.
class StudioStore extends ChangeNotifier {
  StudioStore._();
  static final StudioStore instance = StudioStore._();


  /// Draft event yang sedang diisi di wizard 3 langkah.
  EventPameran draftEvent = EventPameran();

  void mulaiDraftEvent() {
    draftEvent = EventPameran();
  }

}
