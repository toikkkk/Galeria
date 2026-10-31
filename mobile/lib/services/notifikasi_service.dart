import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notifikasi.dart';
import 'api_client.dart';

/// Notifikasi in-app milik pengguna yang login (`/api/notifikasi`).
class NotifikasiService {
  NotifikasiService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<HalamanNotifikasi> daftar({bool belum = false, DateTime? sebelum}) async {
    final qs = Uri(queryParameters: {if (belum) 'belum': 'true', if (sebelum != null) 'sebelum': sebelum.toUtc().toIso8601String()}).query;
    final d = await _client.getJson('/api/notifikasi${qs.isEmpty ? '' : '?$qs'}', auth: true);
    return HalamanNotifikasi(
      items: (d['items'] as List).cast<Map<String, dynamic>>().map(Notifikasi.fromJson).toList(),
      belumDibaca: d['belum_dibaca'] as int,
      adaLagi: d['ada_lagi'] as bool,
    );
  }

  Future<int> jumlahBelum() async => (await _client.getJson('/api/notifikasi/jumlah', auth: true))['belum_dibaca'] as int;

  Future<int> baca(String id) async => (await _client.postJson('/api/notifikasi/$id/baca', const {}, auth: true))['belum_dibaca'] as int;

  Future<int> bacaSemua() async => (await _client.postJson('/api/notifikasi/baca-semua', const {}, auth: true))['belum_dibaca'] as int;
}

/// Jumlah notifikasi belum dibaca untuk titik merah di ikon lonceng. Diperbarui berkala selama pengguna masuk.
class NotifikasiStore extends ChangeNotifier {
  NotifikasiStore._();
  static NotifikasiStore instance = NotifikasiStore._();

  NotifikasiService service = NotifikasiService();
  int _belum = 0;
  Timer? _timer;

  int get belumDibaca => _belum;

  void atur(int n) {
    if (n == _belum) return;
    _belum = n;
    notifyListeners();
  }

  Future<void> muat() async {
    try {
      atur(await service.jumlahBelum());
    } catch (_) {
      // gagal memuat: titik merah tidak diubah
    }
  }

  /// Mulai memperbarui tiap 30 detik (dipanggil saat login/pulih sesi).
  void mulai() {
    _timer?.cancel();
    muat();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => muat());
  }

  void berhenti() {
    _timer?.cancel();
    _timer = null;
    atur(0);
  }
}
