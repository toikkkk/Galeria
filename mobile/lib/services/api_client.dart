import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Base URL backend GALERIA (lihat `backend/main.py`).
///
/// Default `127.0.0.1:8000` mengasumsikan HP terhubung via USB + sudah
/// jalankan `adb reverse tcp:8000 tcp:8000` di laptop (lihat mobile/README.md)
/// -- ini paling robust dibanding IP WiFi yang bisa berubah-ubah, dan cocok
/// dgn alur kerja tim yang sejauh ini selalu pakai HP fisik via USB (lihat
/// mobile/docs/SETUP_ANDROID.md).
const kApiBaseUrl = 'http://127.0.0.1:8000';

/// Dilempar kalau request ke backend gagal (network error ATAU response
/// bukan 2xx) -- caller (services/screens) tangkap ini utk fallback data
/// lokal / tampilkan pesan error, JANGAN biarkan app crash.
class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// HTTP client tipis ke backend GALERIA. Cuma dua bentuk request yang
/// dipakai backend saat ini: GET JSON biasa, dan POST multipart (upload
/// gambar utk Visual Search).
class ApiClient {
  Future<dynamic> getJson(String path) async {
    final Uri uri = Uri.parse('$kApiBaseUrl$path');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('Server error ${response.statusCode}: ${response.body}');
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
    required File file,
    Map<String, String>? fields,
    MediaType? contentType,
  }) async {
    final Uri uri = Uri.parse('$kApiBaseUrl$path').replace(
      queryParameters: fields,
    );
    try {
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            // Tanpa ini, http.MultipartFile.fromPath NEBAK content-type dari
            // ekstensi file -- file temp dari CameraController.takePicture()
            // kadang tidak punya ekstensi yang dikenali, jadi fallback ke
            // "application/octet-stream" dan DITOLAK backend (validasi
            // `file.content_type.startswith("image/")` di
            // backend/routers/visual_search.py). Paksa eksplisit dari caller.
            contentType: contentType,
          ),
        );
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('Server error ${response.statusCode}: ${response.body}');
      }
      return jsonDecode(response.body);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal terhubung ke backend ($path): $e');
    }
  }
}
