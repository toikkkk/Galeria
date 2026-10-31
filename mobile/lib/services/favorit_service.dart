import 'package:flutter/foundation.dart';

import '../models/karya.dart';
import 'api_client.dart';

/// Karya yang kamu miliki (`GET /api/koleksi`).
class KoleksiItem {
  const KoleksiItem({required this.karya, required this.diperoleh, required this.sumber, this.hargaIdr});

  final Karya karya;
  final DateTime diperoleh;
  final String sumber;
  final int? hargaIdr;

  factory KoleksiItem.fromJson(Map<String, dynamic> j) => KoleksiItem(
        karya: Karya.fromJson(j['karya'] as Map<String, dynamic>),
        diperoleh: DateTime.parse(j['diperoleh_at'] as String).toLocal(),
        sumber: j['sumber'] as String,
        hargaIdr: j['harga_idr'] as int?,
      );
}

/// Hasil pemeriksaan sertifikat digital keaslian (`GET /api/verifikasi/{artwork_id}`, publik).
/// Dua pemeriksaan terpisah, dihitung ulang tiap permintaan: data sertifikat belum berubah, dan tanda tangan digital valid.
class HasilSertifikat {
  const HasilSertifikat({required this.artworkId, required this.valid, required this.hashCocok, required this.signatureValid, required this.diverifikasi, required this.jumlahPemilik, required this.keyDicabut});

  final String artworkId;
  final bool valid, hashCocok, signatureValid, keyDicabut;
  final DateTime diverifikasi;
  final int jumlahPemilik;

  factory HasilSertifikat.fromJson(Map<String, dynamic> j) => HasilSertifikat(
        artworkId: j['artwork_id'] as String,
        valid: j['status_keseluruhan'] == 'VALID',
        hashCocok: j['hash_cocok'] as bool,
        signatureValid: j['signature_valid'] as bool,
        diverifikasi: DateTime.parse(j['verified_at'] as String).toLocal(),
        jumlahPemilik: (j['riwayat_kepemilikan'] as List).length,
        keyDicabut: j['peringatan_key_dicabut'] as bool? ?? false,
      );
}

/// Favorit (`/api/favorit`) dan koleksi yang dimiliki (`/api/koleksi`).
class FavoritService {
  FavoritService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Set<String>> ids() async => ((await _client.getJson('/api/favorit/ids', auth: true))['ids'] as List).cast<String>().toSet();

  Future<List<Karya>> daftar() async =>
      ((await _client.getJson('/api/favorit', auth: true)) as List).cast<Map<String, dynamic>>().map(Karya.fromJson).toList();

  Future<Set<String>> tambah(String karyaId) async =>
      ((await _client.postJson('/api/favorit/$karyaId', const {}, auth: true))['ids'] as List).cast<String>().toSet();

  Future<void> hapus(String karyaId) => _client.delete('/api/favorit/$karyaId');

  Future<HasilSertifikat> periksaSertifikat(String artworkId) async =>
      HasilSertifikat.fromJson(await _client.getJson('/api/verifikasi/$artworkId') as Map<String, dynamic>);

  Future<List<KoleksiItem>> koleksi() async =>
      ((await _client.getJson('/api/koleksi', auth: true)) as List).cast<Map<String, dynamic>>().map(KoleksiItem.fromJson).toList();
}

/// Daftar id favorit milik pengguna yang login, dibagikan ke semua ikon hati. Kosong saat belum login.
class FavoritStore extends ChangeNotifier {
  FavoritStore._();
  static FavoritStore instance = FavoritStore._();

  FavoritService service = FavoritService();
  final Set<String> _ids = {};

  bool punya(String karyaId) => _ids.contains(karyaId);

  Future<void> muat() async {
    try {
      final baru = await service.ids();
      _ids
        ..clear()
        ..addAll(baru);
      notifyListeners();
    } catch (_) {
      // gagal memuat: ikon hati tampil kosong, tidak mengganggu layar lain
    }
  }

  void kosongkan() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }

  /// Ketuk hati. Mengembalikan pesan error bila gagal (state dikembalikan), null bila sukses.
  Future<String?> ubah(String karyaId) async {
    final sudah = _ids.contains(karyaId);
    // optimistis: ikon langsung berubah, dikembalikan bila server menolak
    sudah ? _ids.remove(karyaId) : _ids.add(karyaId);
    notifyListeners();
    try {
      if (sudah) {
        await service.hapus(karyaId);
      } else {
        await service.tambah(karyaId);
      }
      return null;
    } catch (e) {
      sudah ? _ids.add(karyaId) : _ids.remove(karyaId);
      notifyListeners();
      return e.toString();
    }
  }
}
