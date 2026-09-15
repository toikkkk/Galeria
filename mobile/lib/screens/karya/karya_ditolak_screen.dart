import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_karya_tidak_dapat_didaftarkan/code.html
///
/// Skor & alasan penolakan di sini CONTOH -- nilai asli dari
/// `ml-digital-art-identity/` nanti (lihat CLAUDE.md).
class KaryaDitolakScreen extends StatelessWidget {
  const KaryaDitolakScreen({super.key, required this.onBack, required this.onAjukanBanding});

  final VoidCallback onBack;
  final VoidCallback onAjukanBanding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('GALERIA', style: AppTextStyles.headlineSm.copyWith(fontSize: 16)),
            Text('STATUS VERIFIKASI', style: AppTextStyles.overline.copyWith(fontSize: 8)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.person, size: 16, color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.policy, size: 13, color: AppColors.error),
                    const SizedBox(width: 6),
                    Text('PELANGGARAN HAK CIPTA & DUPLIKASI',
                        style: AppTextStyles.overline.copyWith(fontSize: 9, color: AppColors.error)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.errorContainer.withValues(alpha: 0.6)),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
                    child: const Icon(Icons.gpp_bad_outlined, color: Colors.white, size: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Karya Tidak Dapat Didaftarkan',
                textAlign: TextAlign.center, style: AppTextStyles.headlineLg),
            const SizedBox(height: 6),
            Text(
              'Karya Anda terindikasi memiliki kemiripan dengan karya lain dan juga kuat sebagai hasil buatan AI.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardInner),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.fingerprint, size: 18, color: AppColors.error),
                          const SizedBox(width: 6),
                          Text('Skor Kemiripan Visual', style: AppTextStyles.labelMd),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.errorContainer, borderRadius: BorderRadius.circular(AppRadius.full)),
                        child: Text('Terdeteksi Kemiripan',
                            style: AppTextStyles.labelSm.copyWith(color: AppColors.error, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('94',
                          style: AppTextStyles.displayLg.copyWith(color: AppColors.error, fontSize: 34)),
                      const SizedBox(width: 4),
                      Text('/ 100', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: const LinearProgressIndicator(
                      value: 0.94,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(AppColors.error),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber, size: 13, color: AppColors.error),
                          const SizedBox(width: 4),
                          Text('Batas Maksimal Orisinalitas Terlampaui',
                              style: AppTextStyles.labelSm.copyWith(color: AppColors.error, fontSize: 10)),
                        ],
                      ),
                      Text('Ambang >85%',
                          style: AppTextStyles.labelSm.copyWith(color: AppColors.muted, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardInner),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surfaceContainerHighest,
                    child: const Icon(Icons.gavel_outlined, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Merasa ini karya orisinal milikmu?', style: AppTextStyles.labelMd),
                        const SizedBox(height: 2),
                        Text(
                          'Anda dapat mengajukan banding kuratorial resmi dengan melampirkan dokumentasi proses pembuatan (WIP), sertifikat fisik, atau bukti hak cipta sah.',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onAjukanBanding,
              icon: const Icon(Icons.verified_user_outlined, size: 18),
              label: const Text('Ajukan Banding'),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: onBack, child: const Text('Kembali')),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text('ID Sengketa: #REJ-2025-9412X · Perlindungan Hak Kekayaan Intelektual GALERIA',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: AppColors.outline)),
            ),
          ],
        ),
      ),
    );
  }
}
