import 'dart:io';
import 'dart:ui';

import 'package:http_parser/http_parser.dart';

import '../models/karya.dart';
import 'api_client.dart';

/// Satu kandidat kecocokan katalog (lihat backend/schemas/visual_search.py
/// -- CatalogMatch). `similarity` disimpan tapi SENGAJA tidak ditampilkan
/// mentah ke user di UI -- pakai `verdict`/`verdictMessage` saja, supaya
/// tidak overclaim (lihat komentar di visual_search_camera_screen.dart).
class VisualSearchMatch {
  const VisualSearchMatch({required this.karya, required this.similarity});

  final Karya karya;
  final double similarity;
}

/// Hasil lengkap `POST /api/visual-search`.
class VisualSearchResult {
  const VisualSearchResult({
    required this.verdict,
    required this.verdictMessage,
    required this.matches,
  });

  /// "confirmed" | "ambiguous" | "not_found" -- lihat
  /// ml-visual-search/src/embedding.py::confidence_verdict.
  final String verdict;
  final String verdictMessage;
  final List<VisualSearchMatch> matches;

  bool get isConfirmed => verdict == 'confirmed';
  bool get isAmbiguous => verdict == 'ambiguous';
  bool get isNotFound => verdict == 'not_found';
}

/// Wrapper tipis ke `POST /api/visual-search` (lihat
/// backend/routers/visual_search.py).
class VisualSearchService {
  VisualSearchService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// [hintRect] (opsional): kotak hijau live-detect terakhir yang tampil di
  /// layar sebelum shutter ditekan (fraksi 0..1 dari
  /// `CameraPreviewLayer.onLiveDetection`) -- dikirim ke backend sebagai
  /// kandidat crop prioritas (lihat `backend/routers/visual_search.py`),
  /// supaya framing yang sudah user konfirmasi visual benar-benar dipakai,
  /// bukan diabaikan.
  Future<VisualSearchResult> scanImage(
    File imageFile, {
    int topK = 5,
    Rect? hintRect,
  }) async {
    final fields = {'top_k': '$topK'};
    if (hintRect != null) {
      fields['hint_left'] = '${hintRect.left}';
      fields['hint_top'] = '${hintRect.top}';
      fields['hint_width'] = '${hintRect.width}';
      fields['hint_height'] = '${hintRect.height}';
    }
    final data = await _client.postMultipart(
      '/api/visual-search',
      file: imageFile,
      fields: fields,
      // CameraController.takePicture() selalu hasilkan JPEG -- lihat
      // catatan di api_client.dart soal kenapa ini wajib eksplisit.
      contentType: MediaType('image', 'jpeg'),
    );
    final matches = (data['catalog_matches'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (m) => VisualSearchMatch(
            karya: Karya.fromJson(m),
            similarity: (m['similarity'] as num).toDouble(),
          ),
        )
        .toList();
    return VisualSearchResult(
      verdict: data['verdict'] as String,
      verdictMessage: data['verdict_message'] as String,
      matches: matches,
    );
  }
}
