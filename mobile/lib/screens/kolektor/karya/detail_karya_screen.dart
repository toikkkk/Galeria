import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:share_plus/share_plus.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/karya_image.dart';
import '../../../widgets/kolektor/karya_grid_card.dart';
import '../../../utils/coming_soon.dart';
import '../../../widgets/favorit_hati.dart';
import '../../../widgets/ulasan_karya_card.dart';

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
    this.onLelangTap,
    this.onTokoTap,
  });

  final Karya karya;
  final VoidCallback onBack;
  final VoidCallback? onArTap;
  final VoidCallback? onBeliTap;

  /// Karya sedang dilelang: buka halaman lelangnya (dengan id lelang).
  final ValueChanged<String>? onLelangTap;
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
          IconButton(
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: '${karya.title} — ${karya.artistName} di GALERIA\n${karya.shareUrl}'),
            ),
            icon: const Icon(Icons.share_outlined),
          ),
          FavoritHati(karya: karya, bulat: false, ukuran: 24),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: KaryaImage(karya: karya),
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
                Text(
                  'Rp ${karya.priceFormatted.replaceFirst('Rp', '')}',
                  style: AppTextStyles.displayMd.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  'Belum termasuk ongkos kirim',
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
                    if (karya.lebarCm != null && karya.tinggiCm != null)
                      _tag(Icons.aspect_ratio, '${_cm(karya.lebarCm!)} × ${_cm(karya.tinggiCm!)} cm'),
                    _tag(Icons.palette_outlined, karya.styleName),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Sertifikat Keaslian Digital -- hanya bila karya benar-benar punya Artwork ID
                if (karya.artworkId != null)
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
                                karya.artworkId ?? '',
                                style: AppTextStyles.bodySm.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                await Clipboard.setData(ClipboardData(text: karya.artworkId ?? ''));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID sertifikat disalin.')));
                                }
                              },
                              child: const Icon(Icons.content_copy, size: 14, color: AppColors.muted),
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
                if (karya.id.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  UlasanKaryaCard(karyaId: karya.id),
                ],
                const SizedBox(height: AppSpacing.md),
                Text('Cerita Karya', style: AppTextStyles.headlineMd),
                const SizedBox(height: 4),
                Text(
                  'Karya beraliran ${karya.styleName} oleh ${karya.artistName}, ditawarkan oleh ${karya.galleryName}. '
                  'Karya ini sudah melewati pemeriksaan keaslian digital GALERIA (deteksi duplikat dan deteksi gambar AI).',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _bentoBox(
                        'Ukuran',
                        (karya.lebarCm != null && karya.tinggiCm != null)
                            ? '${_cm(karya.lebarCm!)} × ${_cm(karya.tinggiCm!)} cm'
                            : 'Belum dicantumkan',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: _bentoBox('Ketersediaan', karya.terjual ? 'Sudah terjual' : 'Tersedia')),
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
              onPressed: () => showComingSoon(context, 'Chat dengan penjual'),
              icon: const Icon(Icons.chat_bubble_outline),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: ElevatedButton(
                onPressed: karya.terjual
                    ? null
                    : (karya.lelangId != null ? () => onLelangTap?.call(karya.lelangId!) : onBeliTap),
                child: Text(
                  karya.terjual
                      ? 'Sudah terjual'
                      : (karya.lelangId != null ? 'Sedang dilelang · Ikuti Lelang' : 'Beli Sekarang · ${karya.priceFormatted}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 60.0 -> "60", 60.5 -> "60,5".
  static String _cm(double v) => (v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ','));

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
