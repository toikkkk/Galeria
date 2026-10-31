import '../models/lelang.dart';
import 'api_client.dart';

/// Lelang (`/api/lelang`). Daftar & detail terbuka untuk tamu; bid, buat, dan batal butuh login.
class LelangService {
  LelangService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  List<Lelang> _daftar(dynamic data) =>
      (data['items'] as List).cast<Map<String, dynamic>>().map(Lelang.fromJson).toList();

  /// [status]: semua | berlangsung | akan_datang | selesai. [ikut]: hanya lelang yang pernah kamu tawar.
  Future<List<Lelang>> daftar({String status = 'semua', bool ikut = false}) async {
    final data = await _client.getJson('/api/lelang?status=$status&page_size=100${ikut ? '&ikut=true' : ''}', auth: true);
    return _daftar(data);
  }

  /// Lelang milik seniman yang login.
  Future<List<Lelang>> saya() async => _daftar(await _client.getJson('/api/lelang/saya', auth: true));

  Future<Lelang> detail(String id) async =>
      Lelang.fromJson(await _client.getJson('/api/lelang/$id', auth: true) as Map<String, dynamic>);

  Future<Lelang> bid(String id, int jumlahIdr) async => Lelang.fromJson(
        await _client.postJson('/api/lelang/$id/bid', {'jumlah_idr': jumlahIdr}, auth: true) as Map<String, dynamic>,
      );

  Future<Lelang> buat({
    required String karyaId,
    required int hargaAwalIdr,
    required int kelipatanIdr,
    required DateTime mulai,
    required DateTime selesai,
  }) async =>
      Lelang.fromJson(
        await _client.postJson('/api/lelang', {
          'karya_id': karyaId,
          'harga_awal_idr': hargaAwalIdr,
          'kelipatan_bid_idr': kelipatanIdr,
          'mulai_at': mulai.toUtc().toIso8601String(),
          'selesai_at': selesai.toUtc().toIso8601String(),
        }, auth: true) as Map<String, dynamic>,
      );

  Future<Lelang> batal(String id) async =>
      Lelang.fromJson(await _client.postJson('/api/lelang/$id/batal', const {}, auth: true) as Map<String, dynamic>);
}
