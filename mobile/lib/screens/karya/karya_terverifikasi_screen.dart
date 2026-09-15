import 'package:flutter/material.dart';

import '../../models/karya.dart';
import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_karya_terverifikasi_asli/code.html
///
/// "Digital Art Identity Key" & skor kemiripan di sini CONTOH -- nilai
/// asli akan datang dari `ml-digital-art-identity/` (lihat CLAUDE.md).
/// Istilah sengaja "sertifikat digital keaslian" / "Provenance", BUKAN
/// "Hak Paten" (aturan wajib proyek).
class KaryaTerverifikasiScreen extends StatelessWidget {
  const KaryaTerverifikasiScreen({
    super.key,
    required this.onClose,
    required this.onLihatGaleri,
    required this.onUnggahLagi,
  });

  final VoidCallback onClose;
  final VoidCallback onLihatGaleri;
  final VoidCallback onUnggahLagi;

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
                        child: const Text('100%',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                              Text('Digital Art Identity Key', style: AppTextStyles.labelSm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.xs)),
                                child: Text('Tersimpan di Ledger',
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
                                const Text('GAL-2026-8F3A-21C7',
                                    style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 12)),
                                Row(
                                  children: [
                                    const Icon(Icons.copy, size: 14, color: AppColors.accent),
                                    const SizedBox(width: 4),
                                    Text('Salin',
                                        style: AppTextStyles.labelSm.copyWith(color: AppColors.accent, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Waktu Penerbitan', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                        Text('14 Feb 2025, 14:32 WIB', style: AppTextStyles.labelMd.copyWith(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _scoreBar('Kemiripan dengan Karya Lain', 0.12, '12% (Sangat Rendah)'),
                    const SizedBox(height: AppSpacing.xs),
                    _scoreBar('Indikasi Dibuat oleh AI', 0.03, '3% (Sangat Rendah)'),
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
                  Text('Enkripsi Kriptografis SHA-256 · Hak Cipta Dilindungi Undang-Undang',
                      style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
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
