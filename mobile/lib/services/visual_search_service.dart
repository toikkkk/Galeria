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
    required this.stylePredictions,
  });

  /// "confirmed" | "ambiguous" | "not_found" -- lihat
  /// ml-visual-search/src/embedding.py::confidence_verdict.
  final String verdict;
  final String verdictMessage;
  final List<VisualSearchMatch> matches;

  /// Prediksi aliran ASLI dari model (top-3, urut confidence tertinggi) --
  /// BUKAN style dari karya katalog terdekat. `[]` kalau backend belum bisa
  /// isi (mis. label map tidak ketemu saat startup). Confidence disimpan
  /// tapi SENGAJA tidak ditampilkan mentah ke user (sama spt `similarity`
  /// di [VisualSearchMatch]) -- cukup nama style-nya, jangan overclaim.
  final List<StylePrediction> stylePredictions;

  bool get isConfirmed => verdict == 'confirmed';
  bool get isAmbiguous => verdict == 'ambiguous';
  bool get isNotFound => verdict == 'not_found';
}

/// Satu prediksi aliran dari model (lihat backend/schemas/visual_search.py
/// -- StylePrediction).
class StylePrediction {
  const StylePrediction({required this.style, required this.confidence});

  final String style;
  final double confidence;
}

/// Wrapper tipis ke `POST /api/visual-search` (lihat
/// backend/routers/visual_search.py).
class VisualSearchService {
  VisualSearchService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// [hintRect] (opsional): area bingkai panduan di layar kamera yang
  /// dipetakan ke fraksi 0..1 gambar (lihat
  /// `CameraPreviewLayerState.screenRectToPreviewFraction`) -- kalau ada,
  /// backend HANYA memproses isi area itu (lihat
  /// `backend/routers/visual_search.py`). Null utk gambar dari galeri.
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
    final stylePredictions = (data['style_predictions'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (s) => StylePrediction(
            style: s['style'] as String,
            confidence: (s['confidence'] as num).toDouble(),
          ),
        )
        .toList();
    return VisualSearchResult(
      verdict: data['verdict'] as String,
      verdictMessage: data['verdict_message'] as String,
      matches: matches,
      stylePredictions: stylePredictions,
    );
  }
}
