import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Base URL backend GALERIA (lihat `backend/main.py`).
///
/// Default `127.0.0.1:8000` mengasumsikan HP terhubung via USB + sudah
/// jalankan `adb reverse tcp:8000 tcp:8000` di laptop (lihat mobile/README.md)
/// -- ini paling robust dibanding IP WiFi yang bisa berubah-ubah, dan cocok
/// dgn alur kerja tim yang sejauh ini selalu pakai HP fisik via USB (lihat
/// mobile/docs/SETUP_ANDROID.md).
///
/// Tanpa USB/`adb reverse`: jalankan dgn
/// `flutter run --dart-define=API_BASE_URL=http://<IP-laptop>:8000` (HP & laptop satu WiFi,
/// backend dijalankan dgn `--host 0.0.0.0`).
const kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

/// `true` = katalog & rekomendasi dari data dummy (`GET /api/katalog-dummy`,
/// 2.000 karya, gambar R2). `false` = katalog lama (`GET /api/katalog`, 8
/// karya Visual Search). Ganti: `--dart-define=DATA_DUMMY=false`.
const kPakaiDataDummy = bool.fromEnvironment('DATA_DUMMY', defaultValue: true);

/// Dilempar kalau request ke backend gagal (network error ATAU response
/// bukan 2xx) -- caller (services/screens) tangkap ini utk fallback data
/// lokal / tampilkan pesan error, JANGAN biarkan app crash.
class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Pesan error dari server: `detail` (sudah Bahasa Indonesia, aman ditampilkan) bila ada, selain itu status + isi.
String _pesanServer(http.Response r) {
  try {
    final j = jsonDecode(r.body);
    final d = j is Map ? j['detail'] : null;
    if (d is String && d.isNotEmpty) return d;
    if (d is List && d.isNotEmpty && d.first is Map && (d.first as Map)['msg'] is String) {
      final loc = ((d.first as Map)['loc'] as List?)?.last;
      return 'Data tidak valid${loc != null ? ' ($loc)' : ''}: ${(d.first as Map)['msg']}';
    }
  } catch (_) {}
  return 'Server error ${r.statusCode}: ${r.body}';
}

/// HTTP client tipis ke backend GALERIA. Cuma dua bentuk request yang
/// dipakai backend saat ini: GET JSON biasa, dan POST multipart (upload
/// gambar utk Visual Search).
class ApiClient {
  /// Diisi di `main()` dengan `AuthService.instance.accessToken` (supaya file ini tidak bergantung pada AuthService).
  /// `paksaPerbarui: true` = abaikan token lama dan minta yang baru. Mengembalikan null bila belum masuk.
  static Future<String?> Function({bool paksaPerbarui})? tokenProvider;

  /// Header untuk request ber-auth (`Authorization: Bearer ...`). Tanpa token, hanya header dasar.
  static Future<Map<String, String>> _header({required bool auth, bool paksa = false, bool json = false}) async {
    final h = <String, String>{if (json) 'Content-Type': 'application/json'};
    if (auth) {
      final token = await tokenProvider?.call(paksaPerbarui: paksa);
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  /// [auth] = true menyertakan token login; bila server membalas 401, token diperbarui dan request diulang SEKALI.
  Future<dynamic> getJson(String path, {bool auth = false}) async {
    final Uri uri = Uri.parse('$kApiBaseUrl$path');
    try {
      var response = await http.get(uri, headers: await _header(auth: auth)).timeout(const Duration(seconds: 15));
      if (auth && response.statusCode == 401) {
        response = await http
            .get(uri, headers: await _header(auth: true, paksa: true))
            .timeout(const Duration(seconds: 15));
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_pesanServer(response));
      }
      return jsonDecode(response.body);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal terhubung ke backend ($path): $e');
    }
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body, {bool auth = false}) async {
    final Uri uri = Uri.parse('$kApiBaseUrl$path');
    try {
      var response = await http
          .post(uri, headers: await _header(auth: auth, json: true), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      if (auth && response.statusCode == 401) {
        response = await http
            .post(uri, headers: await _header(auth: true, paksa: true, json: true), body: jsonEncode(body))
            .timeout(const Duration(seconds: 15));
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_pesanServer(response));
      }
      return jsonDecode(response.body);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal terhubung ke backend ($path): $e');
    }
  }

  Future<dynamic> postMultipart(
    String path, {
    File? file,
    Uint8List? bytes,
    String filename = 'upload.jpg',
    Map<String, String>? fields,
    MediaType? contentType,
    bool auth = false,
  }) async {
    assert(file != null || bytes != null, 'butuh file atau bytes');
    final Uri uri = Uri.parse('$kApiBaseUrl$path').replace(
      queryParameters: fields,
    );
    try {
      // Request multipart hanya bisa dikirim sekali, jadi dibangun ulang tiap percobaan.
      Future<http.Response> kirim({bool paksa = false}) async {
        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(await _header(auth: auth, paksa: paksa))
          ..files.add(
            bytes != null
                ? http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: contentType)
                // Tanpa contentType eksplisit, fromPath menebak dari ekstensi -- file temp kamera kadang
                // tak punya ekstensi dikenali -> "application/octet-stream" -> ditolak backend.
                : await http.MultipartFile.fromPath('file', file!.path, contentType: contentType),
          );
        final streamed = await request.send().timeout(const Duration(seconds: 60));
        return http.Response.fromStream(streamed);
      }

      var response = await kirim();
      if (auth && response.statusCode == 401) response = await kirim(paksa: true);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_pesanServer(response));
      }
      return jsonDecode(response.body);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal terhubung ke backend ($path): $e');
    }
  }

  /// `DELETE` ber-auth; sukses (2xx) tidak mengembalikan isi.
  Future<void> delete(String path) async {
    final Uri uri = Uri.parse('$kApiBaseUrl$path');
    try {
      var response = await http.delete(uri, headers: await _header(auth: true)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        response = await http.delete(uri, headers: await _header(auth: true, paksa: true)).timeout(const Duration(seconds: 15));
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_pesanServer(response));
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal terhubung ke backend ($path): $e');
    }
  }
}
