import '../models/karya.dart';
import 'api_client.dart';

/// Wrapper tipis ke `GET /api/katalog` (lihat backend/routers/katalog.py).
/// Satu halaman hasil `GET /api/katalog-dummy`.
class KatalogDummyPage {
  const KatalogDummyPage({required this.items, required this.page, required this.total});

  final List<Karya> items;
  final int page;
  final int total;
}

class KatalogService {
  KatalogService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Karya>> fetchKatalog({int page = 1, int pageSize = 20}) async {
    final data = await _client.getJson('/api/katalog?page=$page&page_size=$pageSize');
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Karya.fromJson).toList();
  }

  /// `GET /api/katalog-dummy` (katalog 2.000 karya dummy, filter di server).
  Future<KatalogDummyPage> fetchKatalogDummy({
    int page = 1,
    int pageSize = 20,
    String? gaya,
    int? hargaMin,
    int? hargaMaks,
    String? q,
    String urut = 'terbaru',
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      'urut': urut,
      if (gaya != null && gaya.isNotEmpty) 'gaya': gaya,
      if (hargaMin != null) 'harga_min': '$hargaMin',
      if (hargaMaks != null) 'harga_maks': '$hargaMaks',
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };
    final qs = Uri(queryParameters: query).query;
    final data = await _client.getJson('/api/katalog-dummy?$qs');
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return KatalogDummyPage(
      items: items.map(Karya.fromJson).toList(),
      page: data['page'] as int,
      total: data['total'] as int,
    );
  }
}
