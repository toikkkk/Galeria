import '../models/karya_rekomendasi.dart';
import 'api_client.dart';

/// Wrapper tipis ke `GET /api/rekomendasi/...` (lihat
/// backend/routers/katalog_dummy.py).
class RekomendasiService {
  RekomendasiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<KolektorDemo>> fetchDemoKolektor() async {
    final data = await _client.getJson('/api/rekomendasi/demo-kolektor');
    return (data as List).cast<Map<String, dynamic>>().map(KolektorDemo.fromJson).toList();
  }

  Future<RekomendasiResult> fetchRekomendasi(String kolektorId, {int topK = 10}) async {
    final data = await _client.getJson('/api/rekomendasi/$kolektorId?top_k=$topK');
    return RekomendasiResult.fromJson(data as Map<String, dynamic>);
  }
}
