import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/karya_grid_card.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR PEMBELIAN PEMBAYARAN/.../galeria_detail_karya_seni/code.html
///
/// "Sertifikat Keaslian Digital" di sini murni UI -- backend
/// `ml-digital-art-identity/` belum ada (lihat CLAUDE.md: fitur ini
/// mendeteksi duplikasi UPLOAD DIGITAL, BUKAN pemalsuan fisik).
///
/// Tombol "AR" di sticky bar membuka simulasi AR placeholder (belum
/// ARCore/ARKit nyata) -- lihat scan/ar_ruangan_screen.dart.
class DetailKaryaScreen extends StatelessWidget {
  const DetailKaryaScreen({
    super.key,
    required this.karya,
    required this.onBack,
    this.onArTap,
    this.onBeliTap,
    this.onTokoTap,
  });

  final Karya karya;
  final VoidCallback onBack;
  final VoidCallback? onArTap;
  final VoidCallback? onBeliTap;
  final VoidCallback? onTokoTap;

  @override
  Widget build(BuildContext context) {
    final related = sampleKarya
        .where((k) => k.title != karya.title)
        .take(3)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Detail Karya', style: AppTextStyles.headlineSm),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Image.asset(karya.assetPath, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'KOLEKSI MAHAKARYA PRIMER',
                      style: AppTextStyles.overline.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        karya.styleName,
                        style: AppTextStyles.labelSm.copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                ),
                Text(karya.title, style: AppTextStyles.headlineLg),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Rp',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      karya.priceFormatted.replaceFirst('Rp', ''),
                      style: AppTextStyles.displayMd.copyWith(fontSize: 24),
                    ),
                  ],
                ),
                Text(
                  'Termasuk pajak kurasi, asuransi transit & sertifikasi resmi',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _tag(Icons.aspect_ratio, '120 × 90 cm'),
                    _tag(Icons.palette_outlined, 'Cat Minyak'),
                    _tag(Icons.calendar_today, '2024'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Sertifikat Keaslian Digital
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.accentSoft,
                            child: const Icon(
                              Icons.verified_user,
                              size: 16,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TERAUTENTIKASI GALERIA',
                                  style: AppTextStyles.overline.copyWith(
                                    fontSize: 9,
                                    color: AppColors.accent,
                                  ),
                                ),
                                Text(
                                  'Sertifikat Keaslian Digital',
                                  style: AppTextStyles.headlineSm.copyWith(
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'GAL-2026-${karya.artistName.hashCode.toRadixString(16).substring(0, 4).toUpperCase()}',
                                style: AppTextStyles.bodySm.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.content_copy,
                              size: 14,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bukti registrasi kepemilikan digital karya ini di platform GALERIA -- '
                        'bukan pemeriksaan keaslian fisik lukisan.',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: onTokoTap,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            karya.artistName.substring(0, 2).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                karya.artistName,
                                style: AppTextStyles.headlineSm.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '12,4rb Pengikut · Jakarta Selatan',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: onTokoTap,
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerHighest,
                          ),
                          child: const Text('Kunjungi Galeri'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Cerita Karya', style: AppTextStyles.headlineMd),
                const SizedBox(height: 4),
                Text(
                  'Mahakarya beraliran ${karya.styleName} ini merefleksikan penguasaan teknik dan '
                  'komposisi khas ${karya.artistName}. Karya diproduksi dengan pigmen berkualitas tinggi '
                  'di atas kanvas linen, dan telah melalui proses kurasi oleh dewan kurator GALERIA.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _bentoBox('Kondisi Fisik', 'Sempurna (A+)'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: _bentoBox('Kepemilikan', 'Koleksi Privat')),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Karya Serupa', style: AppTextStyles.headlineMd),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: related.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, i) => SizedBox(
                      width: 150,
                      child: KaryaGridCard(karya: related[i], overline: null),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.sm,
          AppSpacing.screenGutter,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            IconButton.outlined(
              onPressed: onArTap,
              icon: const Icon(
                Icons.view_in_ar_outlined,
                color: AppColors.accent,
              ),
              tooltip: 'Coba di Ruangan (AR)',
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.outlined(
              onPressed: () {},
              icon: const Icon(Icons.chat_bubble_outline),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: ElevatedButton(
                onPressed: onBeliTap,
                child: Text('Beli Sekarang · ${karya.priceFormatted}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.labelSm.copyWith(fontSize: 11)),
      ],
    ),
  );

  Widget _bentoBox(String label, String value) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.overline.copyWith(fontSize: 8),
        ),
        Text(value, style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
      ],
    ),
  );
}
