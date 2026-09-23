import '../models/karya.dart';
import 'api_client.dart';

/// Wrapper tipis ke `GET /api/katalog` (lihat backend/routers/katalog.py).
class KatalogService {
  KatalogService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Karya>> fetchKatalog({int page = 1, int pageSize = 20}) async {
    final data = await _client.getJson('/api/katalog?page=$page&page_size=$pageSize');
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Karya.fromJson).toList();
  }
}
