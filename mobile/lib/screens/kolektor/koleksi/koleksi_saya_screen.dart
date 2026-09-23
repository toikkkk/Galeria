import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/kolektor_bottom_nav.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_koleksi_saya/code.html
///
/// "ID Kriptografis" di sini adalah teks demo UI-only (bukan hash asli) --
/// modeling `ml-digital-art-identity/` belum selesai, lihat TODO di
/// models/karya.dart & CLAUDE.md (istilah wajib: "sertifikat digital
/// keaslian", BUKAN "Hak Paten").
class KoleksiSayaScreen extends StatelessWidget {
  const KoleksiSayaScreen({super.key, this.onNavTap, this.onPindai});

  final ValueChanged<int>? onNavTap;
  final VoidCallback? onPindai;

  @override
  Widget build(BuildContext context) {
    final koleksi = sampleKarya.take(3).toList();
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Koleksi Saya', style: AppTextStyles.headlineMd),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.sm,
        ),
        children: [
          Text(
            'ARSIP & PROVENANSI',
            style: AppTextStyles.overline.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL MAHAKARYA',
                            style: AppTextStyles.overline.copyWith(fontSize: 9),
                          ),
                          Text(
                            '${koleksi.length} Karya',
                            style: AppTextStyles.headlineLg.copyWith(
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTIMASI PORTOFOLIO',
                            style: AppTextStyles.overline.copyWith(fontSize: 9),
                          ),
                          Text(
                            'Rp 12.400.000',
                            style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.accent,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tersinkronisasi dengan Ledger Kriptografis GALERIA',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('Semua Koleksi (${koleksi.length})', active: true),
                const SizedBox(width: AppSpacing.xs),
                _filterChip('Klasik'),
                const SizedBox(width: AppSpacing.xs),
                _filterChip('Kontemporer'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final k in koleksi) ...[
            _CertificateCard(karya: k),
            const SizedBox(height: AppSpacing.sm),
          ],
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accentSoft,
                  child: const Icon(
                    Icons.support_agent,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konsultasi Kurator Khusus',
                        style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                      ),
                      Text(
                        'Layanan penaksiran & restorasi fisik koleksi',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Hubungi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
      bottomNavigationBar: KolektorBottomNav(
        currentIndex: 0,
        onTap: (i) => onNavTap?.call(i),
        onPindai: onPindai ?? () {},
      ),
    );
  }

  Widget _filterChip(String label, {bool active = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
    decoration: BoxDecoration(
      color: active ? AppColors.primary : AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Text(
      label,
      style: AppTextStyles.labelMd.copyWith(
        color: active ? Colors.white : AppColors.onSurface,
        fontSize: 12,
      ),
    ),
  );
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.karya});

  final Karya karya;

  String get _certificateId =>
      'GAL-${2024 + karya.title.length % 3}-${karya.artistName.hashCode.toRadixString(16).substring(0, 4).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.asset(
                    karya.assetPath,
                    width: 72,
                    height: 92,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              'Terverifikasi',
                              style: AppTextStyles.overline.copyWith(
                                fontSize: 8,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        karya.title,
                        style: AppTextStyles.headlineSm.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${karya.artistName} · ${karya.styleName}',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                _certificateId,
                                style: AppTextStyles.bodySm.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.content_copy,
                              size: 12,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.workspace_premium_outlined,
                      size: 15,
                      color: AppColors.accent,
                    ),
                    label: const Text('Lihat Sertifikat'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onSurface,
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: AppColors.border),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.swap_horiz,
                      size: 15,
                      color: AppColors.muted,
                    ),
                    label: const Text('Alihkan Hak'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
