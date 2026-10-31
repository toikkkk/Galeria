import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';

import '../models/event.dart';
import '../models/karya.dart';
import '../models/komunitas.dart';
import 'api_client.dart';

/// Komunitas seniman (`/api/komunitas`). Komunitas terbuka bisa dibaca tamu; menulis, menyukai, dan bergabung
/// butuh login.
class KomunitasService {
  KomunitasService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  List<Komunitas> _daftar(dynamic d) => (d['items'] as List).cast<Map<String, dynamic>>().map(Komunitas.fromJson).toList();

  /// [saya] = hanya yang kamu ikuti/miliki.
  Future<List<Komunitas>> daftar({bool saya = false, String? q}) async {
    final qs = Uri(queryParameters: {'page_size': '100', if (saya) 'saya': 'true', if (q != null && q.trim().isNotEmpty) 'q': q.trim()}).query;
    return _daftar(await _client.getJson('/api/komunitas?$qs', auth: true));
  }

  Future<Komunitas> detail(String id) async => Komunitas.fromJson(await _client.getJson('/api/komunitas/$id', auth: true) as Map<String, dynamic>);

  Future<Komunitas> buat({
    required String nama,
    required List<String> aliran,
    required bool terbuka,
    String? deskripsi,
    String? aturan,
  }) async =>
      Komunitas.fromJson(await _client.postJson('/api/komunitas', {
        'nama': nama,
        'aliran': aliran,
        'terbuka': terbuka,
        if (deskripsi != null && deskripsi.isNotEmpty) 'deskripsi': deskripsi,
        if (aturan != null && aturan.isNotEmpty) 'aturan': aturan,
      }, auth: true) as Map<String, dynamic>);

  Future<Komunitas> gabung(String id) async =>
      Komunitas.fromJson(await _client.postJson('/api/komunitas/$id/gabung', const {}, auth: true) as Map<String, dynamic>);

  Future<Komunitas> keluar(String id) async =>
      Komunitas.fromJson(await _client.postJson('/api/komunitas/$id/keluar', const {}, auth: true) as Map<String, dynamic>);

  Future<DaftarAnggota> anggota(String id) async =>
      DaftarAnggota.fromJson(await _client.getJson('/api/komunitas/$id/anggota', auth: true) as Map<String, dynamic>);

  Future<void> setujui(String id, String userId) => _client.postJson('/api/komunitas/$id/anggota/$userId/setuju', const {}, auth: true);
  Future<void> tolak(String id, String userId) => _client.postJson('/api/komunitas/$id/anggota/$userId/tolak', const {}, auth: true);
  Future<void> keluarkan(String id, String userId) => _client.delete('/api/komunitas/$id/anggota/$userId');

  Future<List<Karya>> karya(String id) async {
    final d = await _client.getJson('/api/komunitas/$id/karya', auth: true);
    return (d as List).cast<Map<String, dynamic>>().map(Karya.fromJson).toList();
  }

  Future<List<EventInfo>> event(String id) async {
    final d = await _client.getJson('/api/event?komunitas_id=$id&waktu=semua&page_size=50', auth: true);
    return (d['items'] as List).cast<Map<String, dynamic>>().map(EventInfo.fromJson).toList();
  }

  /// [sebelum] = waktu postingan terakhir yang sudah dimuat (untuk halaman berikutnya).
  Future<HalamanPost> post(String id, {DateTime? sebelum}) async {
    final qs = sebelum == null ? '' : '?${Uri(queryParameters: {'sebelum': sebelum.toUtc().toIso8601String()}).query}';
    final d = await _client.getJson('/api/komunitas/$id/post$qs', auth: true);
    return HalamanPost(
      items: (d['items'] as List).cast<Map<String, dynamic>>().map(PostKomunitas.fromJson).toList(),
      adaLagi: d['ada_lagi'] as bool,
    );
  }

  Future<PostKomunitas> tulisPost(String id, String teks) async =>
      PostKomunitas.fromJson(await _client.postJson('/api/komunitas/$id/post', {'teks': teks}, auth: true) as Map<String, dynamic>);

  Future<PostKomunitas> tulisPostFoto(String id, String teks, Uint8List bytes, String namaFile) async =>
      PostKomunitas.fromJson(await _client.postMultipart(
        '/api/komunitas/$id/post-foto',
        bytes: bytes,
        filename: namaFile,
        fields: {'teks': teks},
        contentType: MediaType('image', 'jpeg'),
        auth: true,
      ) as Map<String, dynamic>);

  Future<void> hapusPost(String postId) => _client.delete('/api/komunitas/post/$postId');

  Future<PostKomunitas> sematkan(String postId) async =>
      PostKomunitas.fromJson(await _client.postJson('/api/komunitas/post/$postId/sematkan', const {}, auth: true) as Map<String, dynamic>);

  /// Mengembalikan (sayaLike, jumlahLike) terbaru.
  Future<(bool, int)> like(String postId) async {
    final d = await _client.postJson('/api/komunitas/post/$postId/like', const {}, auth: true) as Map<String, dynamic>;
    return (d['saya_like'] as bool, d['jumlah_like'] as int);
  }

  Future<List<KomentarKomunitas>> komentar(String postId) async {
    final d = await _client.getJson('/api/komunitas/post/$postId/komentar', auth: true);
    return (d['items'] as List).cast<Map<String, dynamic>>().map(KomentarKomunitas.fromJson).toList();
  }

  Future<KomentarKomunitas> tulisKomentar(String postId, String teks) async => KomentarKomunitas.fromJson(
      await _client.postJson('/api/komunitas/post/$postId/komentar', {'teks': teks}, auth: true) as Map<String, dynamic>);

  Future<void> hapusKomentar(String id) => _client.delete('/api/komunitas/komentar/$id');
}
