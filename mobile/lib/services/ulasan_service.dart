import 'api_client.dart';

/// Kolektor contoh sebagai penulis ulasan (pengganti login sampai Auth selesai).
const _kDemoKolektorId = String.fromEnvironment('DEMO_KOLEKTOR_ID');

String? _cacheKolektorId;

/// Wrapper tipis ke `POST /api/ulasan` (lihat backend/routers/ulasan.py).
class UlasanService {
  UlasanService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<String> _kolektorId() async {
    if (_kDemoKolektorId.isNotEmpty) return _kDemoKolektorId;
    final cached = _cacheKolektorId;
    if (cached != null) return cached;
    final data = await _client.getJson('/api/ulasan/kolektor-demo');
    return _cacheKolektorId = (data as Map<String, dynamic>)['id'] as String;
  }

  /// Kirim ulasan. Melempar [ApiException]; pesan 409 = sudah pernah mengulas karya ini.
  Future<void> kirim({required String karyaId, required int rating, required String teks}) async {
    final kolektorId = await _kolektorId();
    await _client.postJson('/api/ulasan', {
      'karya_id': karyaId,
      'kolektor_id': kolektorId,
      'rating': rating,
      'teks': teks,
    });
  }
}

/// Pesan ramah untuk ditampilkan ke pengguna dari [ApiException] saat kirim ulasan.
String pesanGagalUlasan(Object error) {
  final s = error.toString();
  if (s.contains('409')) return 'Kamu sudah pernah menulis ulasan untuk karya ini.';
  if (s.contains('422')) return 'Ulasan belum memenuhi syarat (10–500 karakter).';
  if (s.contains('404')) return 'Karya atau akun tidak ditemukan.';
  return 'Ulasan belum terkirim. Periksa koneksi lalu coba lagi.';
}
