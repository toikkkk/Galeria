import 'dart:io';

import 'package:http_parser/http_parser.dart';

import '../models/karya.dart';
import 'api_client.dart';

/// Wrapper tipis ke `GET /api/katalog` + `POST /api/karya` (lihat
/// backend/routers/katalog.py & routers/karya_upload.py).
class KatalogService {
  KatalogService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Karya>> fetchKatalog({int page = 1, int pageSize = 20}) async {
    final data = await _client.getJson('/api/katalog?page=$page&page_size=$pageSize');
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Karya.fromJson).toList();
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
    required File image,
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
      file: image,
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
