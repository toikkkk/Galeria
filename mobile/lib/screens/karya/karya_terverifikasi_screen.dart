import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/karya.dart';
import '../../services/digital_art_identity_service.dart';
import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_karya_terverifikasi_asli/code.html
///
/// [result] (opsional) = hasil ASLI `POST /api/verification/check` (lihat
/// MemverifikasiKeaslianScreen). Kalau null (mis. layar dibuka langsung
/// tanpa lewat alur upload), tampilkan versi pratinjau/placeholder yang
/// jelas BUKAN data sungguhan -- JANGAN mengarang angka.
///
/// "Digital Art Identity Key" kriptografis BELUM DIBANGUN (lihat
/// ml-digital-art-identity/kriptografi.md) -- ditampilkan apa adanya sbg
/// pHash (fingerprint digital yang REAL), bukan ID sertifikat palsu.
/// Istilah sengaja "sertifikat digital keaslian" / "Provenance", BUKAN
/// "Hak Paten" (aturan wajib proyek).
class KaryaTerverifikasiScreen extends StatelessWidget {
  const KaryaTerverifikasiScreen({
    super.key,
    required this.onClose,
    required this.onLihatGaleri,
    required this.onUnggahLagi,
    this.result,
  });

  final VoidCallback onClose;
  final VoidCallback onLihatGaleri;
  final VoidCallback onUnggahLagi;
  final VerificationResult? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter, vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(radius: 3, backgroundColor: AppColors.success),
                      const SizedBox(width: 6),
                      Text('LAYANAN KURATORIAL TERPADU',
                          style: AppTextStyles.overline.copyWith(fontSize: 9)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                      ),
                      child: Icon(Icons.verified_user, size: 30, color: AppColors.success),
                    ),
                    Positioned(
                      bottom: -4,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        // "LOLOS" (bukan "100%") -- jujur mencerminkan nilai literal
                        // art_to_art_result/ai_detection_result backend, tidak
                        // menyiratkan skor kuantitatif yang tidak benar-benar ada.
                        child: const Text('LOLOS',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Karya Terverifikasi Asli',
                  textAlign: TextAlign.center, style: AppTextStyles.displayMd.copyWith(fontSize: 26)),
              const SizedBox(height: 4),
              Text(
                'Sertifikat digital untuk karya berharga Anda telah sah diterbitkan oleh dewan kurator.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.cardInner),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.assured_workload, size: 15, color: AppColors.accent),
                              const SizedBox(width: 6),
                              Text('SERTIFIKAT RESMI BALAI LELANG',
                                  style: AppTextStyles.overline.copyWith(fontSize: 9, color: AppColors.accent)),
                            ],
                          ),
                          Text('SERI-A',
                              style: AppTextStyles.overline.copyWith(fontSize: 9, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Image.asset(sampleKarya[3].assetPath, width: 72, height: 88, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('KLASIK REALISME',
                                  style: AppTextStyles.overline.copyWith(fontSize: 9, color: AppColors.accent)),
                              Text('Sang Putri Mahkota Renaisans',
                                  style: AppTextStyles.headlineSm.copyWith(fontSize: 16),
                                  overflow: TextOverflow.ellipsis),
                              Text('Sanggar Rupa Nusantara · 2024',
                                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const CircleAvatar(radius: 3, backgroundColor: AppColors.success),
                                  const SizedBox(width: 4),
                                  Text('Arsip Terotentikasi',
                                      style: AppTextStyles.labelSm.copyWith(color: AppColors.success, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Fingerprint Digital (pHash)', style: AppTextStyles.labelSm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.xs)),
                                // Jujur: sertifikat kriptografis (digital signature) belum
                                // dibangun -- lihat ml-digital-art-identity/kriptografi.md.
                                // JANGAN klaim "Tersimpan di Ledger" sebelum itu ada.
                                child: Text(
                                    result?.persisted == true ? 'Tersimpan di Database' : 'Mode Pratinjau',
                                    style: AppTextStyles.overline.copyWith(fontSize: 8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                                color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(result?.phash ?? '-- (pratinjau, belum ada data)',
                                    style: const TextStyle(
                                        fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 12)),
                                InkWell(
                                  onTap: result?.phash == null
                                      ? null
                                      : () async {
                                          await Clipboard.setData(ClipboardData(text: result!.phash));
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Fingerprint disalin ke clipboard')),
                                            );
                                          }
                                        },
                                  child: Row(
                                    children: [
                                      const Icon(Icons.copy, size: 14, color: AppColors.accent),
                                      const SizedBox(width: 4),
                                      Text('Salin',
                                          style: AppTextStyles.labelSm.copyWith(color: AppColors.accent, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Column (bukan Row) -- versi model (mis.
                    // "siamese_convnext_v1 / convnext_ai_detector_v1") terlalu
                    // panjang utk sejajar dgn label di layar sempit, dulu
                    // overflow (lihat laporan user, screenshot "RIGHT
                    // OVERFLOWED BY 23 PIXELS").
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Model Art-to-Art / Art-to-AI',
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                        const SizedBox(height: 2),
                        Text(
                          result == null
                              ? '-'
                              : '${result!.modelVersionArtToArt} / ${result!.modelVersionArtToAi}',
                          style: AppTextStyles.labelMd.copyWith(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Jarak embedding Art-to-Art (Euclidean, BUKAN persentase --
                    // lihat catatan DuplicateMatch) -- ditampilkan apa adanya,
                    // bukan dikonversi jadi "XX% mirip" tanpa formula resmi.
                    _buildKemiripanRow(),
                    const SizedBox(height: AppSpacing.xs),
                    _scoreBar(
                      'Indikasi Dibuat oleh AI',
                      result?.aiGeneratedProbability ?? 0,
                      result == null
                          ? '-- (pratinjau)'
                          : '${(result!.aiGeneratedProbability * 100).toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: onLihatGaleri,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Tayangkan di Galeri Saya'),
                    SizedBox(width: AppSpacing.xs),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.accent),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(onPressed: onUnggahLagi, child: const Text('Unggah Karya Lain')),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 13, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Text('Terverifikasi Sistem Art-to-Art & Art-to-AI GALERIA',
                      style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Beda dari [_scoreBar] (0..1 langsung = persentase) -- jarak Art-to-Art
  /// adalah Euclidean distance, SEMAKIN KECIL semakin mirip, tanpa formula
  /// resmi utk dikonversi jadi persentase (lihat catatan DuplicateMatch di
  /// digital_art_identity_service.dart). Ditampilkan sbg angka jarak +
  /// ambang batasnya, bukan "XX% mirip" yang mengarang makna.
  Widget _buildKemiripanRow() {
    final matches = result?.duplicateMatches ?? const [];
    final label = result == null
        ? '-- (pratinjau)'
        : matches.isEmpty
            ? 'Tidak ada kecocokan di katalog'
            : 'Jarak terdekat ${matches.first.distance.toStringAsFixed(3)} (ambang 0,10)';
    // Column (bukan Row) -- sama spt perbaikan "Model Art-to-Art / Art-to-AI"
    // di atas, teks label bisa cukup panjang utk overflow di layar sempit.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kemiripan dengan Karya Lain', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(label,
            style: AppTextStyles.labelMd.copyWith(color: AppColors.success, fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
      ],
    );
  }

  Widget _scoreBar(String label, double value, String valueLabel) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              Text(valueLabel, style: AppTextStyles.labelMd.copyWith(color: AppColors.success, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainer,
              valueColor: AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
        ],
      );
}
