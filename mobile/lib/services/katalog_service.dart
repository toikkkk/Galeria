
import 'package:http_parser/http_parser.dart';

import '../models/karya.dart';
import '../models/picked_image.dart';
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

  /// Versi berhalaman `GET /api/katalog` dgn total, pencarian [q], dan
  /// filter [senimanId] ("milik saya" -- diisi setelah Login tersedia).
  Future<KatalogDummyPage> fetchKatalogTerverifikasi({
    int page = 1,
    int pageSize = 20,
    String? q,
    String? senimanId,
  }) async {
    final qs = Uri(queryParameters: {
      'page': '$page',
      'page_size': '$pageSize',
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      'seniman_id': ?senimanId,
    }).query;
    final data = await _client.getJson('/api/katalog?$qs');
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return KatalogDummyPage(
      items: items.map(Karya.fromJson).toList(),
      page: data['page'] as int,
      total: data['total'] as int,
    );
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

  /// Buat baris `karya` baru (status awal "menunggu", BELUM tampil di
  /// katalog publik -- lihat docstring `POST /api/karya` di backend).
  /// Kembalikan `karya_id` baru, dipakai caller utk memanggil
  /// `DigitalArtIdentityService.verifyKarya()` selanjutnya.
  ///
  /// CATATAN JUJUR (lihat routers/karya_upload.py): `artistName`/
  /// `galleryName` sekarang input form bebas -- BUKAN identitas user
  /// terautentikasi (Auth belum dibangun, lihat CLAUDE.md). Begitu Auth
  /// ada, dua parameter ini harus dihapus dari sini, diambil dari token
  /// login di backend.
  Future<String> createKarya({
    required PickedImage image,
    required String title,
    required String artistName,
    required String galleryName,
    required String styleName,
    required int priceIdr,
    required double lebarCm,
    required double tinggiCm,
  }) async {
    final data = await _client.postMultipart(
      '/api/karya',
      bytes: image.bytes,
      filename: image.name,
      fields: {
        'title': title,
        'artist_name': artistName,
        'gallery_name': galleryName,
        'style_name': styleName,
        'price_idr': '$priceIdr',
        'lebar_cm': '$lebarCm',
        'tinggi_cm': '$tinggiCm',
      },
      contentType: MediaType('image', 'jpeg'),
    );
    return data['id'] as String;
  }
}
