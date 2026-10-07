import 'dart:io';

import 'package:http_parser/http_parser.dart';

import 'api_client.dart';

/// Satu kandidat duplikat dari katalog (lihat backend/schemas/verification.py
/// -- DuplicateMatch). `distance` = jarak Euclidean embedding Art-to-Art
/// (SiameseConvNeXt, 512-d) -- SEMAKIN KECIL = semakin mirip. BUKAN
/// persentase kecocokan -- jangan dikonversi jadi "XX% mirip" di UI tanpa
/// formula resmi yang disepakati tim (lihat catatan di
/// karya_perlu_ditinjau_screen.dart).
class DuplicateMatch {
  const DuplicateMatch({
    required this.karyaId,
    required this.distance,
    required this.title,
    required this.artistName,
    required this.imageFilename,
  });

  final String karyaId;
  final double distance;
  final String title;
  final String artistName;
  final String imageFilename;
}

/// Hasil lengkap `POST /api/verification/check` atau
/// `POST /api/karya/{id}/verify` (lihat backend/schemas/verification.py --
/// VerificationResult). Dua tipe cek INDEPENDEN (Art-to-Art dan Art-to-AI,
/// lihat CLAUDE.md "Arsitektur AI -- Prinsip Penting") digabung di sini
/// krn satu kali upload selalu menjalankan keduanya sekaligus.
class VerificationResult {
  const VerificationResult({
    required this.artToArtResult,
    required this.aiDetectionResult,
    required this.rekomendasiStatus,
    required this.aiGeneratedProbability,
    required this.phash,
    required this.duplicateMatches,
    required this.modelVersionArtToArt,
    required this.modelVersionArtToAi,
    required this.persisted,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      artToArtResult: json['art_to_art_result'] as String,
      aiDetectionResult: json['ai_detection_result'] as String,
      rekomendasiStatus: json['rekomendasi_status'] as String,
      aiGeneratedProbability: (json['ai_generated_probability'] as num)
          .toDouble(),
      phash: json['phash'] as String,
      duplicateMatches: (json['duplicate_matches'] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (m) => DuplicateMatch(
              karyaId: m['karya_id'] as String,
              distance: (m['distance'] as num).toDouble(),
              title: m['title'] as String,
              artistName: m['artist_name'] as String,
              imageFilename: m['image_filename'] as String,
            ),
          )
          .toList(),
      modelVersionArtToArt: json['model_version_arttoart'] as String,
      modelVersionArtToAi: json['model_version_arttoai'] as String,
      persisted: json['persisted'] as bool,
    );
  }

  /// "lolos" | "duplikat_terdeteksi"
  final String artToArtResult;

  /// "lolos" | "ai_generated_terdeteksi"
  final String aiDetectionResult;

  /// "terverifikasi" | "ditolak" | "perlu_ditinjau" -- REKOMENDASI dari
  /// backend (lihat DigitalArtIdentityService._decide_status), bukan
  /// keputusan hukum final. Dipakai utk menentukan layar hasil mana yang
  /// ditampilkan.
  final String rekomendasiStatus;

  /// 0.0-1.0, probabilitas mentah dari model Art-to-AI -- aman ditampilkan
  /// sebagai persentase langsung (beda dari `distance` di [DuplicateMatch]).
  final double aiGeneratedProbability;

  /// Perceptual hash (pHash) gambar yang diperiksa -- fingerprint digital
  /// REAL, bukan "Digital Art Identity Key" kriptografis (itu belum
  /// dibangun, lihat ml-digital-art-identity/kriptografi.md).
  final String phash;

  final List<DuplicateMatch> duplicateMatches;
  final String modelVersionArtToArt;
  final String modelVersionArtToAi;

  /// true kalau hasil ditulis ke DB (karya_fingerprints/karya_verifikasi_log)
  /// -- selalu false lewat endpoint pratinjau (lihat [checkImage]).
  final bool persisted;

  bool get isTerverifikasi => rekomendasiStatus == 'terverifikasi';
  bool get isDitolak => rekomendasiStatus == 'ditolak';
  bool get isPerluDitinjau => rekomendasiStatus == 'perlu_ditinjau';
}

/// Wrapper tipis ke endpoint verification engine (Art-to-Art + Art-to-AI,
/// lihat backend/routers/verification.py). Pola SAMA PERSIS dgn
/// [ApiClient]/VisualSearchService -- lihat visual_search_service.dart.
class DigitalArtIdentityService {
  DigitalArtIdentityService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Pratinjau TANPA simpan ke database (`POST /api/verification/check`) --
  /// dipakai saat seniman masih mengisi form upload, SEBELUM karya benar-benar
  /// terdaftar (belum ada `karya_id` krn endpoint pembuatan karya + Auth
  /// belum dibangun, lihat CLAUDE.md "Belum dikerjakan"). Jalur resmi
  /// (`POST /api/karya/{id}/verify`, hasil ter-simpan) baru bisa dipakai
  /// begitu Auth + endpoint upload karya ada.
  Future<VerificationResult> checkImage(File imageFile) async {
    final data = await _client.postMultipart(
      '/api/verification/check',
      file: imageFile,
      contentType: MediaType('image', 'jpeg'),
    );
    return VerificationResult.fromJson(data as Map<String, dynamic>);
  }

  /// Verifikasi RESMI (`POST /api/karya/{id}/verify`) -- BEDA dari
  /// [checkImage]: hasilnya DISIMPAN (`persisted: true`) dan
  /// `karya.status_verifikasi` diperbarui (lihat routers/verification.py).
  /// Dipakai SETELAH [KatalogService.createKarya] berhasil (karya_id sudah
  /// ada di database).
  Future<VerificationResult> verifyKarya(String karyaId, File imageFile) async {
    final data = await _client.postMultipart(
      '/api/karya/$karyaId/verify',
      file: imageFile,
      contentType: MediaType('image', 'jpeg'),
    );
    return VerificationResult.fromJson(data as Map<String, dynamic>);
  }
}
