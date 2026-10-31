import '../models/ulasan_karya.dart';
import 'api_client.dart';

/// Ulasan pembeli: ditulis per PESANAN yang sudah selesai (`POST /api/pesanan/{id}/ulasan`) dan dibaca
/// publik per karya (`GET /api/karya/{id}/ulasan`).
class UlasanService {
  UlasanService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Kirim ulasan. Melempar [ApiException] berisi pesan server yang sudah Bahasa Indonesia
  /// (mis. "Kamu sudah mengulas pesanan ini.").
  Future<void> kirim({required String pesananId, required int rating, required String teks}) async {
    await _client.postJson('/api/pesanan/$pesananId/ulasan', {'rating': rating, 'teks': teks}, auth: true);
  }

  Future<UlasanKarya> ulasanKarya(String karyaId) async {
    final data = await _client.getJson('/api/karya/$karyaId/ulasan');
    return UlasanKarya.fromJson(data as Map<String, dynamic>);
  }
}

/// Pesan untuk ditampilkan ke pengguna saat kirim ulasan gagal.
String pesanGagalUlasan(Object error) {
  final s = error.toString();
  if (s.contains('Gagal terhubung')) return 'Ulasan belum terkirim. Periksa koneksi lalu coba lagi.';
  if (error is ApiException) return error.message;
  return 'Ulasan belum terkirim. Coba lagi sebentar.';
}
