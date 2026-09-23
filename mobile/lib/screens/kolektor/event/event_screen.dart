import 'package:flutter/material.dart';

import '../../../models/event_pameran.dart';
import '../../../theme/app_theme.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_event_pameran_seni/code.html
class EventScreen extends StatelessWidget {
  const EventScreen({super.key, required this.onBack, this.onDaftarTap});

  final VoidCallback onBack;
  final VoidCallback? onDaftarTap;

  @override
  Widget build(BuildContext context) {
    final featured = sampleEvents.firstWhere((e) => e.isFeatured);
    final others = sampleEvents.where((e) => !e.isFeatured).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Agenda Pameran & Event', style: AppTextStyles.headlineSm),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.sm,
        ),
        children: [
          Text(
            'Eksplorasi pameran fisik & kuratorial eksklusif dari galeri seni terakreditasi.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18, color: AppColors.outline),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Cari pameran, seniman, atau lokasi galeri...',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Sorotan Utama', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: onDaftarTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          featured.assetPath,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified,
                                size: 12,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'PRO EXCLUSIVE',
                                style: AppTextStyles.overline.copyWith(
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          featured.organizerName,
                          style: AppTextStyles.overline.copyWith(
                            fontSize: 9,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(featured.title, style: AppTextStyles.headlineMd),
                        const SizedBox(height: AppSpacing.xs),
                        _metaRow(Icons.calendar_month, featured.dateLabel),
                        const SizedBox(height: 4),
                        _metaRow(Icons.location_on_outlined, featured.location),
                        const SizedBox(height: 4),
                        _metaRow(
                          Icons.confirmation_number_outlined,
                          featured.priceLabel,
                          accent: true,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ElevatedButton.icon(
                          onPressed: onDaftarTap,
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('Daftar & Pesan Tiket'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Daftar Pameran Lainnya', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.sm),
          for (final e in others) ...[
            _EventCard(event: e, onTap: onDaftarTap),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text, {bool accent = false}) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.accent),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: AppTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w500,
            color: accent ? AppColors.accent : AppColors.onSurface,
          ),
        ),
      ),
    ],
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.onTap});

  final EventPameran event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.asset(event.assetPath, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      event.priceLabel,
                      style: AppTextStyles.labelSm.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              event.organizerName,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
            Text(
              event.title,
              style: AppTextStyles.headlineSm.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  event.dateLabel,
                  style: AppTextStyles.bodySm.copyWith(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.pin_drop_outlined,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location,
                    style: AppTextStyles.bodySm.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
